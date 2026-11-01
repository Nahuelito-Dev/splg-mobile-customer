import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/domain/payment_outcome.dart';
import 'package:splg_customer/services/mercado_pago_checkout_service.dart';

class _FakeBrowser implements PaymentBrowser {
  final opened = <Uri>[];
  var closed = 0;
  Object? failWith;

  @override
  Future<void> open(Uri url) async {
    if (failWith != null) throw failWith!;
    opened.add(url);
  }

  @override
  Future<void> close() async => closed++;
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('PaymentReturn.fromUri -', () {
    test('reconoce los tres resultados del deep link', () {
      expect(PaymentReturn.fromUri(Uri.parse('splg://pago/exito'))?.outcome,
          PaymentOutcome.success);
      expect(PaymentReturn.fromUri(Uri.parse('splg://pago/pendiente'))?.outcome,
          PaymentOutcome.pending);
      expect(PaymentReturn.fromUri(Uri.parse('splg://pago/error'))?.outcome,
          PaymentOutcome.failure);
    });

    test('toma el pedido y el pago del query que agrega MP', () {
      final r = PaymentReturn.fromUri(
          Uri.parse('splg://pago/exito?collection_id=99&status=approved'
              '&external_reference=o-1&payment_id=123'))!;
      expect(r.orderId, 'o-1');
      expect(r.paymentId, '123');
    });

    test('un «null» o vacío del query no cuenta como dato', () {
      final r = PaymentReturn.fromUri(
          Uri.parse('splg://pago/error?external_reference=null&payment_id='))!;
      expect(r.orderId, isNull);
      expect(r.paymentId, isNull);
    });

    test('ignora otros esquemas, hosts y rutas', () {
      expect(PaymentReturn.fromUri(Uri.parse('https://splg.app/pago/exito')),
          isNull);
      expect(PaymentReturn.fromUri(Uri.parse('splg://otro/exito')), isNull);
      expect(
          PaymentReturn.fromUri(Uri.parse('splg://pago/quien-sabe')), isNull);
      expect(PaymentReturn.fromUri(Uri.parse('splg://pago')), isNull);
    });
  });

  group('MercadoPagoCheckoutService -', () {
    late _FakeBrowser browser;
    late StreamController<Uri> links;
    late MercadoPagoCheckoutService service;
    Uri? initial;
    Object? initialFails;

    setUp(() {
      browser = _FakeBrowser();
      links = StreamController<Uri>.broadcast();
      initial = null;
      initialFails = null;
      service = MercadoPagoCheckoutService(
        browser: browser,
        links: links.stream,
        initialLink: () async {
          if (initialFails != null) throw initialFails!;
          return initial;
        },
      );
    });
    tearDown(() => links.close());

    test('abre el payment_url en el navegador del sistema', () async {
      expect(
          await service.open('https://www.mercadopago.com.ar/pay?x=1'), isTrue);
      expect(browser.opened.single.toString(),
          'https://www.mercadopago.com.ar/pay?x=1');
    });

    test('una URL inválida no abre nada', () async {
      expect(await service.open('no es una url'), isFalse);
      expect(await service.open(''), isFalse);
      expect(browser.opened, isEmpty);
    });

    test('si el navegador falla devuelve false, no revienta', () async {
      browser.failWith = StateError('sin navegador');
      expect(await service.open('https://mp/pay'), isFalse);
    });

    test('la vuelta por deep link se emite y cierra la pestaña', () async {
      final got = <PaymentReturn>[];
      service.returns.listen(got.add);
      await service.open('https://mp/pay');

      links.add(Uri.parse('splg://pago/pendiente?external_reference=o-9'));
      await _pump();

      expect(got.single.outcome, PaymentOutcome.pending);
      expect(got.single.orderId, 'o-9');
      expect(browser.closed, 1);
    });

    test('un link que no es de pago no emite ni cierra nada', () async {
      final got = <PaymentReturn>[];
      service.returns.listen(got.add);
      await service.open('https://mp/pay');

      links.add(Uri.parse('splg://otra-cosa/exito'));
      await _pump();

      expect(got, isEmpty);
      expect(browser.closed, 0);
    });

    test('abrir dos veces no duplica la escucha de links', () async {
      final got = <PaymentReturn>[];
      service.returns.listen(got.add);
      await service.open('https://mp/pay');
      await service.open('https://mp/pay');

      links.add(Uri.parse('splg://pago/exito'));
      await _pump();

      expect(got, hasLength(1));
    });
  });

  group('arranque en frío -', () {
    late _FakeBrowser browser;
    late StreamController<Uri> links;
    late MercadoPagoCheckoutService service;
    Uri? initial;
    Object? initialFails;

    setUp(() {
      browser = _FakeBrowser();
      links = StreamController<Uri>.broadcast();
      initial = null;
      initialFails = null;
      service = MercadoPagoCheckoutService(
        browser: browser,
        links: links.stream,
        initialLink: () async {
          if (initialFails != null) throw initialFails!;
          return initial;
        },
      );
    });
    tearDown(() => links.close());

    test('el link que abrió la app cerrada queda pendiente', () async {
      initial = Uri.parse('splg://pago/exito?external_reference=o-1');

      await service.start();

      expect(service.pending?.outcome, PaymentOutcome.success);
      expect(service.pending?.orderId, 'o-1');
    });

    test('sin link inicial no hay nada pendiente', () async {
      await service.start();
      expect(service.pending, isNull);
    });

    test('un link inicial que no es de pago se ignora', () async {
      initial = Uri.parse('splg://otra-cosa');
      await service.start();
      expect(service.pending, isNull);
    });

    test('si leer el link inicial falla no rompe el arranque', () async {
      initialFails = StateError('sin plugin');
      await service.start();
      expect(service.pending, isNull);
    });

    test('el mismo link por el link inicial y por el stream se cuenta una vez',
        () async {
      final got = <PaymentReturn>[];
      initial = Uri.parse('splg://pago/exito?external_reference=o-1');
      await service.start();
      service.returns.listen(got.add);

      links.add(initial!);
      await _pump();

      expect(got, isEmpty);
    });

    test('un link que llega sin nadie mirando queda pendiente', () async {
      await service.start();

      links.add(Uri.parse('splg://pago/error?external_reference=o-2'));
      await _pump();

      expect(service.pending?.outcome, PaymentOutcome.failure);
    });

    test('con alguien mirando se emite y no queda pendiente', () async {
      final got = <PaymentReturn>[];
      service.returns.listen(got.add);
      await service.start();

      links.add(Uri.parse('splg://pago/exito'));
      await _pump();

      expect(got, hasLength(1));
      expect(service.pending, isNull);
    });

    test('takePending entrega una vez y sólo si es del pedido', () async {
      initial = Uri.parse('splg://pago/exito?external_reference=o-1');
      await service.start();

      expect(service.takePending(orderId: 'o-2'), isNull);
      expect(service.takePending(orderId: 'o-1')?.orderId, 'o-1');
      expect(service.takePending(orderId: 'o-1'), isNull);
    });

    test('un link sin pedido le sirve a cualquier seguimiento', () async {
      initial = Uri.parse('splg://pago/pendiente');
      await service.start();

      expect(
          service.takePending(orderId: 'o-9')?.outcome, PaymentOutcome.pending);
    });
  });
}
