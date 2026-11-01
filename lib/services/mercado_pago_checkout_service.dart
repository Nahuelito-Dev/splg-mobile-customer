import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as tabs;
import 'package:splg_customer/domain/payment_outcome.dart';

/// Navegador del sistema donde se paga: Custom Tabs en Android,
/// SFSafariViewController en iOS. Mercado Pago no admite Checkout Pro en un
/// WebView embebido.
abstract class PaymentBrowser {
  Future<void> open(Uri url);
  Future<void> close();
}

class CustomTabsPaymentBrowser implements PaymentBrowser {
  @override
  Future<void> open(Uri url) => tabs.launchUrl(url);

  @override
  Future<void> close() => tabs.closeCustomTabs();
}

/// Abre el Checkout Pro de MercadoPago en el navegador del sistema y recibe la
/// vuelta por deep link (`splg://pago/{exito|pendiente|error}`).
///
/// La app no ve datos de tarjeta ni decide si el pago salió: la confirmación
/// real es el webhook del back; esto sólo avisa que el cliente volvió, para
/// que quien esté mirando el pedido lo relea. Si el cliente cierra la pestaña
/// sin pagar no hay link: lo cubre el relevo del pedido al volver a primer
/// plano (seguimiento).
class MercadoPagoCheckoutService {
  /// [browser] y [links] sólo se inyectan en los tests.
  MercadoPagoCheckoutService({
    PaymentBrowser? browser,
    Stream<Uri>? links,
    Future<Uri?> Function()? initialLink,
  })  : _browser = browser ?? CustomTabsPaymentBrowser(),
        _links = links,
        _initialLink = initialLink ?? (() => AppLinks().getInitialLink());

  final PaymentBrowser _browser;
  final Future<Uri?> Function() _initialLink;
  Stream<Uri>? _links;
  PaymentReturn? _pending;
  Uri? _lastLink;
  DateTime? _lastLinkAt;
  StreamSubscription<Uri>? _subscription;
  final _returns = StreamController<PaymentReturn>.broadcast();

  /// Cada vuelta de MP a la app.
  Stream<PaymentReturn> get returns => _returns.stream;

  /// La vuelta que llegó cuando nadie la estaba mirando: el link que abrió la
  /// app cerrada (arranque en frío) o uno que llegó con el seguimiento cerrado.
  PaymentReturn? get pending => _pending;

  /// Entrega y borra la vuelta pendiente. Con [orderId] sólo si el link es de
  /// ese pedido o no dice de cuál.
  PaymentReturn? takePending({String? orderId}) {
    final p = _pending;
    if (p == null) return null;
    if (orderId != null && p.orderId != null && p.orderId != orderId) {
      return null;
    }
    _pending = null;
    return p;
  }

  /// Empieza a escuchar los links de pago desde el arranque de la app y lee el
  /// link inicial, el que abrió la app si estaba cerrada (Android la relanza si
  /// el sistema la mató mientras el cliente pagaba). Sin esto ese link se
  /// perdería: la escucha de [open] todavía no existe.
  Future<void> start() async {
    _listen();
    try {
      final initial = await _initialLink();
      if (initial != null) _onLink(initial);
    } catch (e) {
      log('e leyendo el link inicial: ${e.runtimeType}');
    }
  }

  /// Abre [paymentUrl] (el `init_point` del pedido) en el navegador del
  /// sistema. Devuelve false si no se pudo abrir (sin navegador, URL inválida).
  Future<bool> open(String paymentUrl) async {
    final url = Uri.tryParse(paymentUrl);
    if (url == null || !url.hasScheme || !url.hasAuthority) return false;
    _listen();
    try {
      await _browser.open(url);
      return true;
    } catch (e) {
      log('e abriendo el pago: ${e.runtimeType}');
      return false;
    }
  }

  void _listen() {
    if (_subscription != null) return;
    _links ??= AppLinks().uriLinkStream;
    _subscription = _links!.listen(_onLink);
  }

  void _onLink(Uri uri) {
    final back = PaymentReturn.fromUri(uri);
    if (back == null) return;
    // El link inicial puede llegar también por el stream: se cuenta una vez.
    final now = DateTime.now();
    if (_lastLink == uri &&
        _lastLinkAt != null &&
        now.difference(_lastLinkAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastLink = uri;
    _lastLinkAt = now;
    // En iOS el SFSafariViewController sigue encima de la app: se cierra.
    unawaited(_browser.close().catchError((_) {}));
    if (_returns.hasListener) {
      _returns.add(back);
    } else {
      _pending = back;
    }
  }
}
