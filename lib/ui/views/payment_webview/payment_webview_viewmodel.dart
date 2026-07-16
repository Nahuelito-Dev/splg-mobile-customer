import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:jennigas_customer/app/app.locator.dart';
import 'package:jennigas_customer/core/config/app_config.dart';
import 'package:jennigas_customer/domain/payment_outcome.dart';

/// WebView embebido para el Checkout Pro de MercadoPago: el pago no sale de
/// la app. El form de tarjeta/dinero en cuenta lo hostea MP; esta pantalla
/// NO ve ni guarda datos de tarjeta ni tokens de pago, solo carga la
/// `paymentUrl` (init_point) que ya vino armada del backend y mira a dónde
/// navega para detectar el retorno.
///
/// La confirmación real del pago la hace el webhook del backend contra
/// MercadoPago (asincrónico); acá solo interpretamos a qué back_url
/// redirigió MP para cerrar el WebView y devolver un [PaymentOutcome]
/// informativo.
class PaymentWebViewModel extends BaseViewModel {
  PaymentWebViewModel({required this.paymentUrl});

  final String paymentUrl;

  final _navigationService = locator<NavigationService>();

  late final WebViewController controller;

  bool _closed = false;
  bool _pageLoading = true;
  bool get isPageLoading => _pageLoading;

  void initialize() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _pageLoading = true;
            rebuildUi();
          },
          onPageFinished: (_) {
            _pageLoading = false;
            rebuildUi();
          },
          onNavigationRequest: _interceptNavigation,
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
  }

  /// Se dispara en cada navegación dentro del WebView (incluidos los
  /// redirects que hace MP). Si la URL matchea alguna de las back_urls
  /// configuradas, frenamos esa navegación y cerramos la pantalla con el
  /// resultado correspondiente en vez de dejar que el WebView cargue una
  /// página que no es parte del checkout.
  NavigationDecision _interceptNavigation(NavigationRequest request) {
    final outcome = _outcomeFor(request.url);
    if (outcome != null) {
      _closeWith(outcome);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  PaymentOutcome? _outcomeFor(String url) {
    if (url.startsWith(AppConfig.mpSuccessUrl)) return PaymentOutcome.success;
    if (url.startsWith(AppConfig.mpFailureUrl)) return PaymentOutcome.failure;
    if (url.startsWith(AppConfig.mpPendingUrl)) return PaymentOutcome.pending;
    return null;
  }

  void _closeWith(PaymentOutcome outcome) {
    if (_closed) return;
    _closed = true;
    _navigationService.back(result: outcome);
  }

  /// El cliente cerró el WebView (botón de la app bar) sin llegar a una
  /// back_url. No sabemos si terminó pagando o no, así que devolvemos
  /// [PaymentOutcome.cancelled] en vez de asumir éxito o fallo.
  void cancel() {
    _closeWith(PaymentOutcome.cancelled);
  }
}
