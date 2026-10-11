import 'dart:async';
import 'dart:developer';

import 'package:stacked_services/stacked_services.dart';

import 'package:splg_lib/network/api_error_text.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';

/// Fin de la sesión: deja la app sin rastros del usuario anterior (datos,
/// carrito, claves de cancelación, socket y token de push) y lo lleva al login.
class SessionService {
  bool _expiring = false;

  /// Limpia todo lo del usuario y cierra la sesión de Firebase. Cada paso es
  /// independiente: que uno falle no deja los demás sin hacer.
  Future<void> endSession() async {
    Future<void> step(String name, FutureOr<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        log('SessionService.$name falló: $e');
      }
    }

    await step('tracking', () => locator<OrderTrackingService>().disconnect());
    await step('cart', () => locator<CartService>().clearOrder());
    await step('history', () => locator<HistoryService>().reset());
    await step('push', () => locator<NotificationService>().clearToken());
    await step('firebase', () => locator<CustomerService>().signOut());
    await step('customer', () => locator<CustomerService>().reset());
  }

  /// La sesión dejó de valer (401, baja de cuenta ya hecha...): se limpia, se
  /// avisa y se vuelve al login. Una sola vez aunque lleguen varios 401 juntos.
  Future<void> expire({String message = ApiErrorText.sessionExpired}) async {
    if (_expiring || !locator<CustomerService>().isUserLoggedIn) return;
    _expiring = true;
    try {
      await endSession();
      await locator<DialogService>().showDialog(
        title: 'Sesión cerrada',
        description: message,
        buttonTitle: 'Aceptar',
      );
      await locator<NavigationService>().clearStackAndShow(Routes.loginView);
    } finally {
      _expiring = false;
    }
  }

  /// Cierre de sesión pedido por el usuario.
  Future<void> logout() async {
    await endSession();
    await locator<NavigationService>().clearStackAndShow(Routes.loginView);
  }
}
