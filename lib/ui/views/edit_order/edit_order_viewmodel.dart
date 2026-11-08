import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/gas_cylinder.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_lib/domain/order_item.dart';
import 'package:splg_customer/app/app.bottomsheets.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/time_slot_availability.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/ui/bottom_sheets/address_list/address_list_sheet_model.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/common/load_view_model.dart';

/// Medios de pago que el cliente puede elegir al modificar un pedido: el back
/// no deja pasarlo a Mercado Pago (hay que cancelar y pedir de nuevo).
const List<PaymentMethod> kEditablePaymentMethods = [
  PaymentMethod.cash,
  PaymentMethod.online,
];

/// Modificar un pedido pendiente: garrafas, dirección, fecha y franja, medio
/// de pago y notas. El precio lo cotiza el back (`POST /orders/quote`) cada vez
/// que cambia algo que lo mueve, y se guarda con `PATCH /orders/:id`.
class EditOrderViewModel extends BaseViewModel {
  EditOrderViewModel({required this.original, this.breakdown}) {
    // "Guardar" depende de si las notas cambiaron.
    notesController.addListener(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// El pedido tal como está hoy.
  final Order original;
  final OrderBreakdown? breakdown;

  final _history = locator<HistoryService>();
  final _customers = locator<CustomerService>();
  final _gasCylinders = locator<GasCylinderService>();
  final _timeSlotService = locator<TimeSlotService>();
  final _nav = locator<NavigationService>();
  final _sheets = locator<BottomSheetService>();
  final _dialogs = locator<DialogService>();

  /// Reloj de la pantalla; los tests lo fijan.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Espera entre el último cambio y el pedido de cotización.
  @visibleForTesting
  static Duration quoteDebounce = const Duration(milliseconds: 400);

  final TextEditingController notesController = TextEditingController();
  bool _disposed = false;

  // ─── Garrafas ───
  List<GasCylinder> _cylinders = [];

  /// Catálogo vigente, más las garrafas del pedido que ya no figuran en él.
  List<GasCylinder> get cylinders => _cylinders;

  final Map<String, int> _quantities = {};

  int quantityOf(String cylinderId) => _quantities[cylinderId] ?? 0;

  int get itemCount => _quantities.values.fold(0, (n, q) => n + q);

  String? cylinderPhoto(String id) => _gasCylinders.photoUrl(id);

  bool loading = true;
  String? loadError;

  void changeQuantity(GasCylinder cylinder, int delta) {
    if (saving) return;
    final next = quantityOf(cylinder.id) + delta;
    if (next < 0) return;
    _quantities[cylinder.id] = next;
    rebuildUi();
    scheduleQuote();
  }

  // ─── Dirección ───
  Address? _address;
  Address? get address => _address;

  Future<void> showAddressList() async {
    if (saving) return;
    final response = await _sheets.showCustomSheet(
      variant: BottomSheetType.addressList,
      title: 'Selecciona una dirección',
      data: {'selectedId': _address?.addressId},
    );
    if (_disposed) return;
    if (response?.data == AddressListSheetModel.addNew) {
      final created = await _nav.navigateToAddressFormView();
      if (_disposed || created is! Address) return;
      _chooseAddress(_current(created) ?? created);
    } else if (response?.confirmed == true && response?.data is Address) {
      _chooseAddress(response!.data as Address);
    }
  }

  Address? _current(Address a) {
    for (final s in _customers.customer.addresses) {
      if (s.addressId == a.addressId) return s;
    }
    return null;
  }

  void _chooseAddress(Address a) {
    _address = a;
    rebuildUi();
    scheduleQuote();
  }

  // ─── Medio de pago ───
  PaymentMethod _payment = PaymentMethod.cash;
  PaymentMethod get paymentMethod => _payment;
  bool paymentOpen = false;

  void togglePayment() {
    paymentOpen = !paymentOpen;
    rebuildUi();
  }

  void setPaymentMethod(PaymentMethod method) {
    if (saving || !kEditablePaymentMethods.contains(method)) return;
    _payment = method;
    paymentOpen = false;
    rebuildUi();
    scheduleQuote();
  }

  // ─── Fecha y franja ───
  DateTime _date = _dayOnly(now());
  DateTime get selectedDate => _date;
  String get formattedDate => _sendsDate
      ? DateFormat('dd/MM/yyyy', 'es_AR').format(_date)
      : 'Sin fecha agendada';

  /// El pedido ya tenía fecha agendada. Si no, no se manda fecha ni franja
  /// salvo que el cliente elija una.
  bool _hadDate = false;
  bool _dateTouched = false;
  bool get _sendsDate => _hadDate || _dateTouched;
  int _slotsVersion = 0;

  List<TimeSlotAvailability> _timeSlots = [];
  List<TimeSlotAvailability> get timeSlots => _timeSlots;
  bool loadingTimeSlots = false;
  bool slotsOpen = true;

  String? _slotId;
  String? get selectedTimeSlotId => _slotId;
  String? _originalSlotId;
  DateTime _originalDate = _dayOnly(now());

  TimeSlotAvailability? get _selectedSlot {
    for (final s in _timeSlots) {
      if (s.timeSlotId == _slotId) return s;
    }
    return null;
  }

  String? get selectedSlotLabel => _selectedSlot?.label;

  /// La franja que ya tenía el pedido se puede mantener aunque figure llena:
  /// el cupo que ocupa es el suyo.
  /// Sólo vale para la fecha original: en otro día el cupo ya no es suyo.
  bool canPickSlot(TimeSlotAvailability s) =>
      !s.isFull ||
      (_hadDate &&
          s.timeSlotId == _originalSlotId &&
          _sameDay(_date, _originalDate));

  void toggleSlots() {
    slotsOpen = !slotsOpen;
    rebuildUi();
  }

  Future<void> loadTimeSlots() async {
    final version = ++_slotsVersion;
    loadingTimeSlots = true;
    rebuildUi();
    List<TimeSlotAvailability> loaded;
    try {
      loaded = await _timeSlotService.availabilityFor(_date);
    } catch (_) {
      loaded = [];
    }
    // Una respuesta que llega vieja (cambió la fecha mientras tanto) no pisa
    // a la última.
    if (_disposed || version != _slotsVersion) return;
    _timeSlots = loaded;
    if (_hadDate && _slotId == null && _sameDay(_date, _originalDate)) {
      _slotId = _matchOriginalSlot();
      _originalSlotId = _slotId;
    }
    final valid = _timeSlots.any(
      (s) => s.timeSlotId == _slotId && canPickSlot(s),
    );
    if (!valid && _slotId != null) {
      _slotId = null;
      scheduleQuote();
    }
    loadingTimeSlots = false;
    rebuildUi();
  }

  String? _matchOriginalSlot() {
    final start = original.deliveryWindowStart;
    final end = original.deliveryWindowEnd;
    if (start == null) return null;
    for (final s in _timeSlots) {
      if (hhmm(s.startTime) == hhmm(start) &&
          hhmm(s.endTime) == hhmm(end ?? '')) {
        return s.timeSlotId;
      }
    }
    return null;
  }

  void selectTimeSlot(String id) {
    if (saving) return;
    _slotId = id;
    _dateTouched = true;
    rebuildUi();
    scheduleQuote();
  }

  Future<void> selectDate(BuildContext context) async {
    if (saving) return;
    final today = _dayOnly(now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      locale: const Locale('es', 'AR'),
    );
    if (_disposed || picked == null) return;
    await changeDate(picked);
  }

  /// El cliente eligió [picked] como día de entrega.
  Future<void> changeDate(DateTime picked) async {
    _dateTouched = true;
    if (_sameDay(picked, _date)) {
      rebuildUi();
      scheduleQuote();
      return;
    }
    _date = picked;
    rebuildUi();
    await loadTimeSlots();
    scheduleQuote();
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Cotización (el precio lo calcula el back) ───
  OrderQuote? _quote;
  OrderQuote? get quote => _quote;

  bool _quoting = false;
  bool get quoting => _quoting;

  String? _quoteError;
  String? get quoteError => _quoteError;
  bool _quoteRetryable = false;
  bool get canRetryQuote => _quoteError != null && _quoteRetryable;

  Timer? _quoteTimer;
  int _quoteVersion = 0;

  QuoteLine? quoteLineFor(String cylinderId) => _quote?.lineFor(cylinderId);

  void scheduleQuote({bool immediate = false}) {
    _quoteTimer?.cancel();
    final version = ++_quoteVersion;
    _quote = null;
    _quoteError = null;
    if (itemCount == 0 || _address == null) {
      _quoting = false;
      if (!_disposed) notifyListeners();
      return;
    }
    _quoting = true;
    if (!_disposed) notifyListeners();
    _quoteTimer = Timer(
      immediate ? Duration.zero : quoteDebounce,
      () => _runQuote(version),
    );
  }

  void retryQuote() => scheduleQuote(immediate: true);

  Future<void> _runQuote(int version) async {
    final outcome = await _history.quoteOrder(
      _draft(),
      timeSlotId: _slotToSend,
      orderId: original.id,
    );
    if (_disposed || version != _quoteVersion) return;
    _quoting = false;
    _quote = outcome.quote;
    _quoteError = outcome.ok ? null : outcome.message;
    _quoteRetryable = outcome.retryable;
    notifyListeners();
  }

  /// El pedido tal como quedaría con lo elegido en pantalla.
  Order _draft() => original.copyWith(
        items: [
          for (final c in _cylinders)
            if (quantityOf(c.id) > 0)
              OrderItem(cylinder: c, quantity: quantityOf(c.id)),
        ],
        address: _address,
        paymentMethod: _payment,
        requestedDeliveryDate: _sendsDate ? _date : null,
        customerNotes: _notesChanged ? notesController.text : null,
      );

  /// La franja que viaja: sólo con fecha (la original o la que se eligió).
  String? get _slotToSend => _sendsDate ? _slotId : null;

  bool get _notesChanged =>
      notesController.text.trim() != (original.customerNotes ?? '').trim();

  late final Map<String, int> _originalQuantities = {
    for (final i in original.items)
      if (i.quantity > 0) i.cylinder.id: i.quantity,
  };

  /// Hay algo distinto del pedido tal como está: si no, no hay nada que guardar.
  bool get hasChanges {
    final current = {
      for (final e in _quantities.entries)
        if (e.value > 0) e.key: e.value,
    };
    final sameItems = current.length == _originalQuantities.length &&
        current.entries.every((e) => _originalQuantities[e.key] == e.value);
    final dateChanged =
        _sendsDate && (!_hadDate || !_sameDay(_date, _originalDate));
    final slotChanged = _sendsDate && _slotId != _originalSlotId;
    return !sameItems ||
        _address?.addressId != original.address?.addressId ||
        _payment != original.paymentMethod ||
        _notesChanged ||
        dateChanged ||
        slotChanged;
  }

  // ─── Carga ───
  Future<void> initialize() async {
    loading = true;
    loadError = null;
    rebuildUi();
    try {
      final catalog = await _gasCylinders.getGasCylinders();
      final known = {for (final c in catalog) c.id};
      _cylinders = [
        ...catalog,
        for (final i in original.items)
          if (!known.contains(i.cylinder.id)) i.cylinder,
      ];
    } catch (e) {
      loadError = LoadViewModel.errorText(e);
      loading = false;
      rebuildUi();
      return;
    }
    if (_disposed) return;
    for (final i in original.items) {
      _quantities[i.cylinder.id] = i.quantity;
    }
    final a = original.address;
    _address = a == null ? null : (_current(a) ?? a);
    _payment = kEditablePaymentMethods.contains(original.paymentMethod)
        ? original.paymentMethod
        : PaymentMethod.cash;
    final today = _dayOnly(now());
    final saved = DateTime.tryParse(breakdown?.scheduledDate ?? '') ??
        original.requestedDeliveryDate?.toLocal();
    _hadDate = saved != null;
    // La franja que ya tenía sólo vale para el día que ya tenía (sin fecha
    // guardada, hoy).
    _originalDate = saved == null ? today : _dayOnly(saved);
    _date = _originalDate.isBefore(today) ? today : _originalDate;
    notesController.text = original.customerNotes ?? '';
    loading = false;
    rebuildUi();
    await loadTimeSlots();
    scheduleQuote();
  }

  /// La cotización de la edición cobra envases (más garrafas que las vacías
  /// que el cliente tiene para canjear).
  bool get chargesContainers => _quote?.chargesContainers ?? false;

  /// Envases que cobra la cotización de la edición.
  int get containersCharged => _quote?.containersCharged ?? 0;

  // ─── Guardar ───
  bool saving = false;

  bool get canSave =>
      !loading &&
      !saving &&
      itemCount > 0 &&
      _address != null &&
      (_slotId != null ||
          !_sendsDate ||
          original.deliveryWindowStart == null) &&
      hasChanges &&
      _quote != null;

  Future<void> save() async {
    if (!canSave) return;
    saving = true;
    rebuildUi();

    final draft = _draft();
    final result = await _history.updateOrder(
      original.id,
      draft,
      timeSlotId: _slotToSend,
    );
    if (_disposed) return;

    if (result.success) {
      final charged = result.order?.total;
      await _dialogs.showDialog(
        title: 'Pedido modificado',
        description: charged == null
            ? 'Guardamos los cambios de tu pedido.'
            : 'El nuevo total de tu pedido es ${money.format(charged)}.',
        buttonTitle: 'Aceptar',
      );
      saving = false;
      _nav.back(result: true);
      return;
    }

    if (result.idempotencyConflict) {
      // El primer envío llegó con otros datos: no se manda otro.
      await _dialogs.showDialog(
        title: 'Revisá tu pedido',
        description: result.message ?? kOrderMaybeEditedText,
        buttonTitle: 'Aceptar',
      );
      await _stillEditable(); // lo relee; el detalle muestra cómo quedó
      saving = false;
      _nav.back(result: false);
      return;
    }

    await _dialogs.showDialog(
      title: 'No pudimos modificar tu pedido',
      description: result.message ??
          'No se pudo guardar el cambio. Intentá nuevamente en unos segundos.',
      buttonTitle: 'Aceptar',
    );
    if (_disposed) return;

    // Una regla de negocio (lo tomó un repartidor, la seña) pudo cambiar el
    // estado del pedido: se relee y, si ya no se puede editar, se vuelve.
    if (result.rejected && !await _stillEditable()) {
      saving = false;
      _nav.back(result: false);
      return;
    }
    saving = false;
    rebuildUi();
  }

  Future<bool> _stillEditable() async {
    try {
      final fresh = await _history.fetchOrderDetail(original.id);
      return canEditOrder(fresh.order, fresh.breakdown);
    } catch (e) {
      // Si ya no existe, no hay nada que editar; con otra falla se deja seguir.
      return !(e is LoadFailure && !e.retryable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _quoteTimer?.cancel();
    notesController.dispose();
    super.dispose();
  }
}
