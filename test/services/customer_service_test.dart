import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/address_remote_datasource.dart';
import 'package:splg_customer/domain/address_draft.dart';
import 'package:splg_customer/services/address_geocoder.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_lib/domain/address.dart';

class _Geocoder implements AddressGeocoder {
  _Geocoder(this.point);
  final GeoPoint? point;
  final queries = <String>[];

  @override
  Future<GeoPoint?> locate(String query) async {
    queries.add(query);
    return point;
  }
}

/// Registra qué se mandó a la API de direcciones.
class _Addresses extends AddressRemoteDataSource {
  final calls = <String>[];
  Map<String, dynamic>? lastBody;
  ApiResult<void> result = const ApiResult.ok();

  /// Qué hace el back al crear (por defecto nada).
  void Function()? onCreate;

  @override
  Future<ApiResult<void>> create(
      Map<String, dynamic> body, String token) async {
    calls.add('create');
    lastBody = body;
    onCreate?.call();
    return result;
  }

  @override
  Future<ApiResult<void>> update(
      String id, Map<String, dynamic> body, String token) async {
    calls.add('update:$id');
    lastBody = body;
    return result;
  }

  /// Lo que devuelve la lectura de direcciones (o lanza si `fetchError`).
  List<Map<String, dynamic>> existing = const [];
  Object? fetchError;
  var _fetches = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchByUser(
      String userId, String token) async {
    calls.add(_fetches++ == 0 ? 'fetch-check' : 'fetch');
    if (fetchError != null) throw fetchError!;
    return existing;
  }
}

class _Slow extends _Addresses {
  _Slow(this.gate);
  final Future<void> gate;

  @override
  Future<List<Map<String, dynamic>>> fetchByUser(
      String userId, String token) async {
    await gate;
    return existing;
  }
}

void main() {
  const draft = AddressDraft(
      street: 'Mitre', number: '100', city: 'Posadas', reference: 'Timbre 2');

  CustomerService service(_Geocoder g, _Addresses a) => CustomerService(
      geocoder: g, addressDatasource: a, tokenReader: () async => 'tok');

  test(
      'alta: ubica la dirección y manda latitud/longitud con los nombres del DTO',
      () async {
    final g = _Geocoder(const GeoPoint(-27.36, -55.89));
    final a = _Addresses();
    final r = await service(g, a).saveAddress(draft);

    expect(r.ok, isTrue);
    expect(g.queries, ['Mitre 100, Posadas, Argentina']);
    expect(a.lastBody!['street'], 'Mitre 100');
    expect(a.lastBody!['city'], 'Posadas');
    expect(a.lastBody!['latitude'], '-27.360000');
    expect(a.lastBody!['longitude'], '-55.890000');
    expect(a.lastBody!['additionalInstructions'], 'Timbre 2');
    expect(a.lastBody!['isDefault'], isTrue); // es la primera dirección
    expect(a.lastBody!.containsKey('user_id'), isTrue);
    expect(a.calls, ['fetch-check', 'create', 'fetch']);
  });

  test('si el geocoder no encuentra nada no llama a la API', () async {
    final a = _Addresses();
    final r = await service(_Geocoder(null), a).saveAddress(draft);
    expect(r.ok, isFalse);
    expect(r.message, contains('No pudimos ubicar'));
    expect(a.calls, isEmpty);
  });

  test('edición sin cambiar calle ni localidad no vuelve a geocodificar',
      () async {
    final g = _Geocoder(const GeoPoint(1, 1));
    final a = _Addresses();
    final editing =
        Address(addressId: 'a1', streetName: 'Mitre 100', city: 'Posadas');

    final r = await service(g, a).saveAddress(draft, editing: editing);

    expect(r.ok, isTrue);
    expect(g.queries, isEmpty);
    expect(a.calls.first, 'update:a1');
    expect(a.lastBody!.containsKey('latitude'), isFalse);
    expect(a.lastBody!['additionalInstructions'], 'Timbre 2');
  });

  test('edición que cambia la calle vuelve a ubicarla', () async {
    final g = _Geocoder(const GeoPoint(-27, -55));
    final a = _Addresses();
    final editing =
        Address(addressId: 'a1', streetName: 'Otra 5', city: 'Posadas');

    await service(g, a).saveAddress(draft, editing: editing);

    expect(g.queries, hasLength(1));
    expect(a.lastBody!['latitude'], '-27.000000');
  });

  test('un error del back llega con su texto y no refresca', () async {
    final a = _Addresses()
      ..result = const ApiResult.fail('No tenés permiso para hacer esto.');
    final r =
        await service(_Geocoder(const GeoPoint(1, 1)), a).saveAddress(draft);
    expect(r.message, 'No tenés permiso para hacer esto.');
    expect(a.calls, ['fetch-check', 'create']);
  });

  test('si ya tiene direcciones en el back la nueva no es predeterminada',
      () async {
    final a = _Addresses()
      ..existing = [
        {'address_id': 'x', 'street': 'Otra 1'}
      ];
    await service(_Geocoder(const GeoPoint(1, 1)), a).saveAddress(draft);
    expect(a.lastBody!['isDefault'], isFalse);
  });

  test(
      'si falla la lectura de direcciones NO se da de alta como predeterminada',
      () async {
    final a = _Addresses()..fetchError = Exception('sin red');
    final r =
        await service(_Geocoder(const GeoPoint(1, 1)), a).saveAddress(draft);
    expect(r.ok, isFalse);
    expect(a.calls, ['fetch-check']);
    expect(a.lastBody, isNull);
  });

  test('un 0,0 del geocoder se rechaza como "no se pudo ubicar"', () async {
    final a = _Addresses();
    final r =
        await service(_Geocoder(const GeoPoint(0, 0)), a).saveAddress(draft);
    expect(r.ok, isFalse);
    expect(r.message, contains('No pudimos ubicar'));
    expect(a.calls, isEmpty);
  });

  Map<String, dynamic> json(String id, String street) =>
      {'address_id': id, 'street': street, 'city': 'Posadas'};

  test('el alta devuelve la dirección creada, no la predeterminada', () async {
    final a = _Addresses()
      ..existing = [json('a1', 'Calle A')]
      ..onCreate = () {};
    final s = service(_Geocoder(const GeoPoint(1, 1)), a);
    a.onCreate = () => a.existing = [
          json('a1', 'Calle A'),
          json('a2', 'Calle B'),
          json('a3', 'Mitre 100'),
        ];
    final r = await s.saveAddress(draft);
    expect(r.ok, isTrue);
    expect(r.data?.addressId, 'a3');
    expect(s.customer.addresses, hasLength(3));
  });

  test('si la lista no se puede releer tras el alta, el alta sigue ok',
      () async {
    final a = _Addresses()..existing = [];
    final s = service(_Geocoder(const GeoPoint(1, 1)), a);
    a.onCreate = () => a.fetchError = Exception('sin red');
    final r = await s.saveAddress(draft);
    expect(r.ok, isTrue);
    expect(r.data, isNull);
  });

  test('una lectura de direcciones en vuelo al cerrar sesión se descarta',
      () async {
    final gate = Completer<void>();
    final a = _Slow(gate.future)..existing = [json('a1', 'Calle A')];
    final s = service(_Geocoder(const GeoPoint(1, 1)), a);
    final refresh = s.refreshAddresses();
    await Future<void>.delayed(Duration.zero);
    s.reset();
    gate.complete();
    await refresh;
    expect(s.customer.addresses, isEmpty);
  });

  test('un refresh fallido no pisa las direcciones locales', () async {
    final a = _Addresses()..fetchError = Exception('sin red');
    final s = service(_Geocoder(const GeoPoint(1, 1)), a);
    await expectLater(s.refreshAddresses(), throwsException);
    expect(s.customer.addresses, isEmpty);
  });

  test('sin sesión no hace nada', () async {
    final a = _Addresses();
    final s = CustomerService(
        geocoder: _Geocoder(const GeoPoint(1, 1)),
        addressDatasource: a,
        tokenReader: () async => null);
    final r = await s.saveAddress(draft);
    expect(r.ok, isFalse);
    expect(a.calls, isEmpty);
  });

  test('addressFromApi lee los nombres camelCase del back', () {
    final a = addressFromApi({
      'address_id': 'x',
      'street': 'Mitre 1',
      'city': 'Posadas',
      'postalCode': '3300',
      'additionalInstructions': 'Timbre',
      'isDefault': true,
    });
    expect(a.additionalInstructions, 'Timbre');
    expect(a.postalCode, '3300');
    expect(a.primary, isTrue);
  });

  test('SignInOutcome.fromCode distingue la cuenta deshabilitada', () {
    expect(SignInOutcome.fromCode('user-disabled'), SignInOutcome.disabled);
    expect(
        SignInOutcome.fromCode('wrong-password'), SignInOutcome.badCredentials);
    expect(SignInOutcome.fromCode('invalid-credential'),
        SignInOutcome.badCredentials);
    expect(
        SignInOutcome.fromCode('network-request-failed'), SignInOutcome.failed);
  });

  test('PasswordChangeResult.fromCode', () {
    expect(PasswordChangeResult.fromCode('wrong-password'),
        PasswordChangeResult.wrongCurrent);
    expect(PasswordChangeResult.fromCode('invalid-credential'),
        PasswordChangeResult.wrongCurrent);
    expect(PasswordChangeResult.fromCode('weak-password'),
        PasswordChangeResult.weak);
    expect(PasswordChangeResult.fromCode('network-request-failed'),
        PasswordChangeResult.network);
    expect(PasswordChangeResult.fromCode('too-many-requests'),
        PasswordChangeResult.tooManyRequests);
    expect(PasswordChangeResult.fromCode('algo'), PasswordChangeResult.other);
  });
}
