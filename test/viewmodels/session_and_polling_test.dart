// ignore_for_file: depend_on_referenced_packages
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/core/network/api_client.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHistoryService history;
  late MockCustomerService customers;

  setUp(() {
    registerServices();
    history = locator<HistoryService>() as MockHistoryService;
    customers = locator<CustomerService>() as MockCustomerService;
    when(customers.customer).thenReturn(customerWith());
    when(customers.isUserLoggedIn).thenReturn(true);
    when(history.history).thenReturn(<Order>[]);
    when(history.tryRefreshHistory(limit: anyNamed('limit')))
        .thenAnswer((_) async => true);
    final gas = locator<GasCylinderService>() as MockGasCylinderService;
    when(gas.getGasCylinders()).thenAnswer((_) async => [cylinder()]);
  });
  tearDown(() => locator.reset());

  group('Polling del inicio', () {
    test('consulta cada intervalo y no se solapa con una consulta en curso',
        () {
      fakeAsync((fa) {
        var inFlight = 0, maxInFlight = 0, calls = 0;
        when(history.tryRefreshHistory(limit: anyNamed('limit')))
            .thenAnswer((_) async {
          calls++;
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          // La consulta tarda más que el intervalo.
          await Future<void>.delayed(const Duration(seconds: 25));
          inFlight--;
          return true;
        });
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.elapse(const Duration(seconds: 25)); // termina la consulta inicial
        fa.elapse(const Duration(seconds: 200));
        expect(maxInFlight, 1);
        expect(calls, greaterThan(2));
        m.dispose();
      });
    });

    test('si el viewmodel se cierra durante initialize no queda ningún timer',
        () {
      fakeAsync((fa) {
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        final started = m.initialize();
        m.dispose(); // se cierra antes de que termine
        fa.flushMicrotasks();
        started;
        expect(m.isPolling, isFalse);
        expect(fa.nonPeriodicTimerCount, 0);
      });
    });

    test('dispose cancela el timer pendiente', () {
      fakeAsync((fa) {
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.flushMicrotasks();
        expect(m.isPolling, isTrue);
        m.dispose();
        expect(m.isPolling, isFalse);
        expect(fa.nonPeriodicTimerCount, 0);
      });
    });

    test('en segundo plano se pausa y al volver se reanuda con una consulta',
        () {
      fakeAsync((fa) {
        var calls = 0;
        when(history.tryRefreshHistory(limit: anyNamed('limit')))
            .thenAnswer((_) async {
          calls++;
          return true;
        });
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.flushMicrotasks();
        final before = calls;
        m.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(m.isPolling, isFalse);
        fa.elapse(const Duration(minutes: 5));
        expect(calls, before); // no consultó en background

        m.didChangeAppLifecycleState(AppLifecycleState.resumed);
        fa.flushMicrotasks();
        expect(calls, before + 1); // se puso al día enseguida
        expect(m.isPolling, isTrue);
        m.dispose();
      });
    });

    test('stopPolling (cierre de sesión) corta el ciclo', () {
      fakeAsync((fa) {
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.flushMicrotasks();
        m.stopPolling();
        fa.elapse(const Duration(minutes: 1));
        expect(m.isPolling, isFalse);
        m.dispose();
      });
    });

    test('stopPolling con una consulta en curso no reprograma al terminar', () {
      fakeAsync((fa) {
        var calls = 0;
        when(history.tryRefreshHistory(limit: anyNamed('limit')))
            .thenAnswer((_) async {
          calls++;
          await Future<void>.delayed(const Duration(seconds: 5));
          return true;
        });
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.elapse(const Duration(seconds: 5)); // termina la inicial
        fa.elapse(const Duration(seconds: 11)); // arranca una del timer
        m.stopPolling();
        final before = calls;
        fa.elapse(const Duration(minutes: 2));
        expect(calls, before);
        expect(m.isPolling, isFalse);
        m.dispose();
      });
    });

    test('un refresco que falla no rompe el ciclo', () {
      fakeAsync((fa) {
        var calls = 0;
        when(history.tryRefreshHistory(limit: anyNamed('limit')))
            .thenAnswer((_) async {
          calls++;
          return false;
        });
        final m = HomeViewModel(pollInterval: const Duration(seconds: 10));
        m.initialize();
        fa.elapse(const Duration(seconds: 35));
        expect(calls, greaterThan(2));
        m.dispose();
      });
    });
  });

  group('SessionService', () {
    late SessionService session;
    setUp(() => session = SessionService());

    test(
        'endSession limpia carrito, historial, token de push, socket y '
        'usuario, y cierra Firebase', () async {
      await session.endSession();
      verify((locator<OrderTrackingService>() as MockOrderTrackingService)
              .disconnect())
          .called(1);
      verify((locator<CartService>() as MockCartService).clearOrder())
          .called(1);
      verify(history.reset()).called(1);
      verify((locator<NotificationService>() as MockNotificationService)
              .clearToken())
          .called(1);
      verify(customers.signOut()).called(1);
      verify(customers.reset()).called(1);
    });

    test('un paso que falla no deja los demás sin hacer', () async {
      when(history.reset()).thenThrow(Exception('x'));
      await session.endSession();
      verify(customers.signOut()).called(1);
      verify(customers.reset()).called(1);
    });

    test('logout limpia y va al login', () async {
      final nav = locator<NavigationService>() as MockNavigationService;
      await session.logout();
      verify(history.reset()).called(1);
      verify(nav.clearStackAndShow(Routes.loginView)).called(1);
    });

    test('expire: limpia, avisa y va al login una sola vez', () async {
      final nav = locator<NavigationService>() as MockNavigationService;
      final dialogs = locator<DialogService>() as MockDialogService;
      await Future.wait([session.expire(), session.expire()]);
      verify(history.reset()).called(1);
      verify(dialogs.showDialog(
              title: 'Sesión cerrada',
              description: anyNamed('description'),
              buttonTitle: 'Aceptar'))
          .called(1);
      verify(nav.clearStackAndShow(Routes.loginView)).called(1);
    });

    test('expire sin sesión (ya cerrada) no hace nada', () async {
      when(customers.isUserLoggedIn).thenReturn(false);
      await session.expire();
      verifyNever(history.reset());
    });
  });

  group('UnauthorizedInterceptor', () {
    DioException err(int? status,
            {bool auth = true, String method = 'GET', String path = '/x'}) =>
        DioException(
          requestOptions: RequestOptions(
              path: path,
              method: method,
              headers: {if (auth) 'Authorization': 'Bearer t'}),
          response: status == null
              ? null
              : Response(
                  requestOptions: RequestOptions(path: '/x'),
                  statusCode: status),
        );

    test('un 401 con token avisa; el resto no', () {
      var n = 0;
      final i = UnauthorizedInterceptor(() => n++);
      for (final e in [
        err(401),
        err(401, auth: false),
        err(403),
        err(500),
        err(null),
      ]) {
        final h = ErrorInterceptorHandler();
        // ignore: invalid_use_of_protected_member
        h.future.ignore();
        i.onError(e, h);
      }
      expect(n, 1);
    });

    test('la baja de cuenta no dispara el cierre genérico', () {
      var n = 0;
      final i = UnauthorizedInterceptor(() => n++);
      final h = ErrorInterceptorHandler();
      // ignore: invalid_use_of_protected_member
      h.future.ignore();
      i.onError(err(401, method: 'DELETE', path: 'users/me'), h);
      expect(n, 0);
    });
  });
}
