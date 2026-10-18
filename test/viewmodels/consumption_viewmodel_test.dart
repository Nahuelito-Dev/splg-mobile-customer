import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/consumption_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/views/consumption/consumption_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late MockConsumptionService service;
  late MockDialogService dialogs;

  Consumption declared() => Consumption(
        cylinderTypeId: 'g1',
        cylinderType: '10kg',
        avgMonthlyConsumptionKg: 20,
        nextRepurchaseEstimateAt: DateTime(2026, 11, 5),
      );

  setUpAll(() => initializeDateFormatting('es_AR', null));

  setUp(() {
    registerServices();
    service = locator<ConsumptionService>() as MockConsumptionService;
    dialogs = locator<DialogService>() as MockDialogService;
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders())
        .thenAnswer((_) async => [cylinder(), cylinder(id: 'g2')]);
    when(service.fetch()).thenAnswer((_) async => ApiResult.ok(declared()));
  });
  tearDown(() => locator.reset());

  Future<ConsumptionViewModel> opened() async {
    final m = ConsumptionViewModel();
    await m.load();
    return m;
  }

  group('ConsumptionViewModel Tests -', () {
    test('muestra lo declarado, la garrafa habitual y la próxima recompra',
        () async {
      final m = await opened();
      expect(m.loadError, isNull);
      expect(m.consumption.declared, isTrue);
      expect(m.selectedCylinderId, 'g1');
      expect(m.nextRepurchaseLabel, '05/11/2026');
      expect(m.cylinders, hasLength(2));
    });

    test('si no cargó, ofrece reintentar con el texto del back', () async {
      when(service.fetch())
          .thenAnswer((_) async => const ApiResult.fail('Sin conexión.'));
      final m = await opened();
      expect(m.loadError, 'Sin conexión.');
    });

    test('valida la cantidad antes de llamar al back', () async {
      final m = await opened();
      m.quantity.text = '0';
      await m.save();
      expect(m.quantityError, isNotNull);
      verifyNever(service.save(any));
    });

    test('guarda y muestra la estimación recalculada', () async {
      when(service.save(any)).thenAnswer((_) async => ConsumptionSaveOutcome(
            ConsumptionSaveStatus.saved,
            consumption: Consumption(
              cylinderTypeId: 'g1',
              cylinderType: '10kg',
              avgMonthlyConsumptionKg: 30,
              nextRepurchaseEstimateAt: DateTime(2026, 12, 1),
            ),
          ));
      final m = await opened();
      m.quantity.text = '3';
      await m.save();
      final sent = verify(service.save(captureAny)).captured.single
          as ConsumptionDeclaration;
      expect(sent.cylinderTypeId, 'g1');
      expect(sent.quantityPerMonth, 3);
      expect(sent.confirmOutOfRange, isFalse);
      expect(m.saved, isTrue);
      expect(m.consumption.avgMonthlyConsumptionKg, 30);
      expect(m.nextRepurchaseLabel, '01/12/2026');
      expect(m.isBusy, isFalse);
    });

    test('fuera de rango: pide confirmar y reenvía con confirmOutOfRange',
        () async {
      when(dialogs.showConfirmationDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        confirmationTitle: anyNamed('confirmationTitle'),
        cancelTitle: anyNamed('cancelTitle'),
      )).thenAnswer((_) async => DialogResponse(confirmed: true));
      when(service.save(any)).thenAnswer((i) async {
        final d = i.positionalArguments.single as ConsumptionDeclaration;
        return d.confirmOutOfRange
            ? ConsumptionSaveOutcome(ConsumptionSaveStatus.saved,
                consumption: declared())
            : const ConsumptionSaveOutcome(
                ConsumptionSaveStatus.needsConfirmation);
      });
      final m = await opened();
      m.quantity.text = '900';
      await m.save();
      final sent = verify(service.save(captureAny))
          .captured
          .cast<ConsumptionDeclaration>();
      expect(sent.map((d) => d.confirmOutOfRange), [false, true]);
      expect(m.saved, isTrue);
    });

    test('fuera de rango y el cliente corrige: no guarda', () async {
      when(dialogs.showConfirmationDialog(
        title: anyNamed('title'),
        description: anyNamed('description'),
        confirmationTitle: anyNamed('confirmationTitle'),
        cancelTitle: anyNamed('cancelTitle'),
      )).thenAnswer((_) async => DialogResponse(confirmed: false));
      when(service.save(any)).thenAnswer((_) async =>
          const ConsumptionSaveOutcome(
              ConsumptionSaveStatus.needsConfirmation));
      final m = await opened();
      m.quantity.text = '900';
      await m.save();
      verify(service.save(any)).called(1);
      expect(m.saved, isFalse);
      expect(m.isBusy, isFalse);
    });

    test('un rechazo del back se muestra', () async {
      when(service.save(any)).thenAnswer((_) async =>
          const ConsumptionSaveOutcome(ConsumptionSaveStatus.failed,
              message: 'El tipo de garrafa no existe o está dado de baja'));
      final m = await opened();
      m.quantity.text = '2';
      await m.save();
      expect(m.saveError, contains('dado de baja'));
      expect(m.saved, isFalse);
    });
  });
}
