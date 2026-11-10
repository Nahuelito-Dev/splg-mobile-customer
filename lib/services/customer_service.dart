import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:stacked/stacked.dart';
import 'package:splg_customer/data/datasource/address_remote_datasource.dart';
import 'package:splg_customer/data/repository/address_repository_imp.dart';

import 'package:splg_customer/domain/repository/customer_repository.dart';
import 'package:splg_customer/data/repository/customer_repository_imp.dart';
import 'package:splg_customer/data/datasource/customer_remote_datasource.dart';
import 'package:splg_customer/data/datasource/coverage_remote_datasource.dart';
import 'package:splg_customer/domain/coverage_check.dart';
import 'package:splg_customer/domain/usecases/create_address_usecases.dart';
import 'package:splg_customer/domain/usecases/create_customer_usecases.dart';
import 'package:splg_customer/domain/usecases/fetch_customer_usecases.dart';

import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/core/network/idempotency.dart';
import 'package:splg_customer/domain/address_draft.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/address_geocoder.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/network/api_error_text.dart';
import 'package:splg_lib/domain/customer.dart';

/// Resultado del alta: el back responde 409 si el email o teléfono ya existen.
enum RegisterOutcome {
  created,
  alreadyExists,

  /// El consumo declarado está fuera del rango razonable: no se creó la cuenta
  /// y hay que pedir confirmación y reenviar con `confirmOutOfRange`.
  consumptionOutOfRange,
  failed,
}

/// Resultado de cambiar la contraseña (Firebase: reautenticar y actualizar).
enum PasswordChangeResult {
  ok,
  wrongCurrent,
  weak,
  notMeetsRequirements,
  network,
  tooManyRequests,
  other;

  /// Código de `FirebaseAuthException` -> resultado.
  static PasswordChangeResult fromCode(String code) => switch (code) {
        'wrong-password' || 'invalid-credential' => wrongCurrent,
        'weak-password' => weak,
        'password-does-not-meet-requirements' => notMeetsRequirements,
        'network-request-failed' => network,
        'too-many-requests' => tooManyRequests,
        _ => other,
      };
}

/// Una dirección de la API (camelCase en `GET /user-address`) al modelo de la
/// lib, que lee los nombres con guion bajo.
Address addressFromApi(Map<String, dynamic> json) => Address.fromJson({
      ...json,
      'postal_code': json['postal_code'] ?? json['postalCode'],
      'formatted_address':
          json['formatted_address'] ?? json['formattedAddress'],
      'additional_instructions':
          json['additional_instructions'] ?? json['additionalInstructions'],
    });

/// Resultado de iniciar sesión.
enum SignInOutcome {
  ok,

  /// Firebase tiene la cuenta deshabilitada (p. ej. dada de baja desde la app).
  disabled,

  /// Usuario o contraseña incorrectos.
  badCredentials,
  failed;

  /// Código de `FirebaseAuthException` -> resultado.
  static SignInOutcome fromCode(String code) => switch (code) {
        'user-disabled' => disabled,
        'wrong-password' ||
        'invalid-credential' ||
        'user-not-found' ||
        'invalid-email' =>
          badCredentials,
        _ => failed,
      };
}

class CustomerService with ListenableServiceMixin {
  /// [geocoder], [addressDatasource], [coverageDatasource] y [tokenReader] sólo
  /// se inyectan en los tests.
  CustomerService({
    AddressGeocoder? geocoder,
    AddressRemoteDataSource? addressDatasource,
    CoverageRemoteDatasource? coverageDatasource,
    Future<String?> Function()? tokenReader,
  })  : _geocoder = geocoder ?? const DeviceAddressGeocoder(),
        _addresses = addressDatasource ?? AddressRemoteDataSource(),
        _coverage = coverageDatasource ?? CoverageRemoteDatasource(),
        _tokenReader = tokenReader {
    _customerRepository = CustomerRepositoryImp(_customerDatasource);
    listenToReactiveValues([_addressesRev]);
  }

  /// Claves de idempotencia del alta de direcciones, por dirección.
  final _addressKeys = IdempotencyKeys();

  /// Cambia cada vez que se reemplaza la lista de direcciones: quien depende de
  /// ella (el inicio) se entera sin tener que preguntar.
  final ReactiveValue<int> _addressesRev = ReactiveValue<int>(0);

  /// Época de la sesión: `reset()` la incrementa y las respuestas que vuelven
  /// de una consulta anterior al cierre de sesión se descartan.
  int _session = 0;

  final AddressGeocoder _geocoder;
  final AddressRemoteDataSource _addresses;
  final CoverageRemoteDatasource _coverage;

  /// `customer_id` del cliente en sesión; se lee una vez, al primer uso.
  String? _customerRecordId;
  final Future<String?> Function()? _tokenReader;

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  bool get isUserLoggedIn => _firebaseAuth.currentUser != null;

  Future<String?> get token async {
    final read = _tokenReader;
    if (read != null) return read();
    try {
      return await _firebaseAuth.currentUser?.getIdToken();
    } on FirebaseAuthException catch (e) {
      if (_isInvalidUserError(e)) {
        await _firebaseAuth.signOut();
        return null;
      }

      log('Error getting auth token: $e');
      return null;
    }
  }

  final _customerDatasource = CustomerRemoteDatasource();
  late CustomerRepository _customerRepository;

  Future<bool> init() async {
    final token = await this.token;
    if (token == null) {
      return false;
    }

    final customer = await fetchCustomerByEmail(
      _firebaseAuth.currentUser?.email ?? '',
    );
    return customer;
  }

  Future<RegisterOutcome> registerCustomer({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    ConsumptionDeclaration? consumption,
  }) async {
    final body = {
      'full_name': name,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      if (consumption != null) 'consumption': consumption.toJson(),
    };

    final createCustomerUseCase = CreateCustomerUseCase(_customerRepository);

    try {
      final customer = await createCustomerUseCase(body);
      if (customer != null) {
        setCustomer(customer);
        return RegisterOutcome.created;
      }
    } on RegistrationConflictException {
      return RegisterOutcome.alreadyExists;
    } on ConsumptionOutOfRangeException {
      return RegisterOutcome.consumptionOutOfRange;
    }

    return RegisterOutcome.failed;
  }

  Future<bool> fetchCustomerByEmail(String email) async {
    final session = _session;
    final token = await this.token;
    if (token == null) {
      return false;
    }

    final fetchCustomerUseCase = FetchCustomerUseCase(_customerRepository);
    final customer = await fetchCustomerUseCase(email, token);
    if (session != _session) return false;
    if (customer != null) {
      setCustomer(customer);
      return true;
    }
    return false;
  }

  /// Inicia sesión. Distingue la cuenta deshabilitada del resto de las fallas.
  Future<SignInOutcome> signIn(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final success = await fetchCustomerByEmail(email);
      if (success) return SignInOutcome.ok;

      await _firebaseAuth.signOut();
      return SignInOutcome.failed;
    } on FirebaseAuthException catch (e) {
      log('Error during sign in: $e');
      return SignInOutcome.fromCode(e.code);
    }
  }

  /// Signs in a user with email and password.
  /// Returns true if sign in was successful, false otherwise.
  Future<bool> signInWithEmailAndPassword(
          String email, String password) async =>
      await signIn(email, password) == SignInOutcome.ok;

  /// Envía el mail de recuperación de contraseña. Devuelve false si Firebase
  /// rechaza el pedido (email mal formado, demasiados intentos, sin red).
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      log('Error sending password reset: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  bool _isInvalidUserError(FirebaseAuthException error) {
    return error.code == 'user-not-found' || error.code == 'user-disabled';
  }

  /// Olvida al usuario actual (cierre de sesión o baja de cuenta).
  void reset() {
    _customerRecordId = null;
    _session++;
    _addressKeys.clear();
    _customer = _anonymous;
    _addressesRev.value++;
  }

  Customer get customer => _customer;

  void setCustomer(Customer customer) {
    _customer = customer;
  }

  /// Actualiza el perfil (nombre y/o teléfono) contra `PATCH /users/:id` y, si
  /// el backend confirma, refleja el cambio en el customer local.
  Future<ApiResult<void>> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    final session = _session;
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);

    final data = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      data['full_name'] = fullName.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      data['phone_number'] = phoneNumber.trim();
    }
    if (data.isEmpty) return const ApiResult.ok();

    final result = await _customerDatasource.updateUser(
      _customer.customerId,
      data,
      token,
    );
    if (result.ok && session == _session) {
      _customer = _customer.copyWith(
        fullName: data['full_name'] as String? ?? _customer.fullName,
        phoneNumber: data['phone_number'] as String? ?? _customer.phoneNumber,
      );
    }
    return result;
  }

  /// Cambia la contraseña: Firebase pide reautenticar con la actual.
  Future<PasswordChangeResult> changePassword(
    String current,
    String next,
  ) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return PasswordChangeResult.other;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(next);
      return PasswordChangeResult.ok;
    } on FirebaseAuthException catch (e) {
      log('Cambio de contraseña falló: ${e.code}');
      return PasswordChangeResult.fromCode(e.code);
    } catch (e) {
      log('Cambio de contraseña falló: $e');
      return PasswordChangeResult.other;
    }
  }

  /// Baja lógica de la propia cuenta (`DELETE /users/me`). Es definitiva: el
  /// back deshabilita el acceso y reserva el correo. Con pedidos en curso
  /// responde 409 y el resultado trae el motivo.
  Future<ApiResult<void>> deleteAccount() async {
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    return _customerDatasource.deleteMe(token);
  }

  /// Recarga las direcciones del usuario desde el backend
  /// (`GET /user-address/user/:id`) y las refleja en el customer local.
  Future<void> refreshAddresses() async {
    final session = _session;
    final token = await this.token;
    if (token == null) return;

    final raw = await _addresses.fetchByUser(
      _customer.customerId,
      token,
    );
    if (session != _session) return;
    final addresses = raw.map(addressFromApi).toList();
    _customer = _customer.copyWith(addresses: addresses);
    _addressesRev.value++;
  }

  /// Guarda una dirección del formulario. Ubica la dirección con el geocoder
  /// del dispositivo (el back no geocodifica y exige latitud y longitud); al
  /// editar sólo vuelve a ubicarla si cambió la calle o la localidad.
  /// En un alta, `data` trae la dirección creada (la que no estaba antes).
  Future<ApiResult<Address?>> saveAddress(
    AddressDraft draft, {
    Address? editing,
  }) async {
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);

    final moved = editing == null ||
        editing.streetName != draft.streetLine ||
        (editing.city ?? '') != draft.city.trim();
    GeoPoint? point;
    if (moved) {
      point = await _geocoder.locate(draft.query);
      if (point == null || !point.isUsable) {
        return const ApiResult.fail(
          'No pudimos ubicar esa dirección. Revisá la calle, el número y la localidad.',
        );
      }
      // CU-058: fuera de la cobertura no se puede pedir, así que no se guarda.
      // Si no se pudo consultar, no se da por cubierta.
      final coverage =
          await _coverage.check(point.latitude, point.longitude, token);
      if (!coverage.ok) {
        return ApiResult.fail(coverage.message ?? ApiErrorText.generic,
            status: coverage.status);
      }
      final check = CoverageCheck.fromJson(coverage.data);
      if (check == null) return const ApiResult.fail(ApiErrorText.generic);
      if (!check.covered) {
        return const ApiResult.fail(
          'Esa dirección está fuera de la zona de cobertura de la distribuidora. '
          'Revisá la calle, el número y la localidad.',
        );
      }
    }

    final body = <String, dynamic>{
      'street': draft.streetLine,
      'city': draft.city.trim(),
      'additionalInstructions': draft.reference.trim(),
      if (point != null) ...{
        'latitude': point.latitude.toStringAsFixed(6),
        'longitude': point.longitude.toStringAsFixed(6),
        'formattedAddress': draft.query,
        'geocodePrecision': 'approximate',
      },
    };

    final datasource = _addresses;
    ApiResult<void> result;
    var knownIds = <String>{};
    if (editing == null) {
      // "Primera dirección" se decide con lo que tiene el back, no con la lista
      // local: si la lectura falla no se adivina (una lista vacía por error de
      // red no puede marcar como predeterminada a la nueva).
      final bool isFirst;
      try {
        final existing = await datasource.fetchByUser(
          _customer.customerId,
          token,
        );
        isFirst = existing.isEmpty;
        knownIds = {
          for (final e in existing) addressFromApi(e).addressId,
        };
      } catch (e) {
        return ApiResult.fromError(e);
      }
      // La clave es de la dirección (sin `isDefault`, que cambia si la primera
      // llamada llegó): un reintento tras red caída o 5xx no la crea dos veces.
      final intention = jsonEncode({...body, 'user_id': _customer.customerId});
      result = await datasource.create({
        ...body,
        'user_id': _customer.customerId,
        'isDefault': isFirst,
      }, token, _addressKeys.keyFor(intention));
      // Un 422 de idempotencia significa que el primer envío llegó (el back
      // sólo guarda respuestas 2xx): la dirección existe. No se reenvía con
      // otra clave (se duplicaría) ni se conserva la actual (devolvería esa
      // respuesta guardada aunque la dirección se borre): se relee la lista.
      final landed = result.status == 422 && result.keepKey;
      _addressKeys.settle(intention,
          keep: !result.ok && result.keepKey && !landed);
      if (landed) result = const ApiResult.ok();
    } else {
      result = await datasource.update(editing.addressId, body, token);
    }
    if (!result.ok) {
      return ApiResult.fail(result.message!, status: result.status);
    }
    try {
      await refreshAddresses();
    } catch (_) {
      // La dirección quedó guardada; la lista se recarga en la próxima lectura.
      return const ApiResult.ok();
    }
    if (editing != null) return const ApiResult.ok();
    final created = _customer.addresses
        .where((a) => !knownIds.contains(a.addressId))
        .lastOrNull;
    return ApiResult.ok(created);
  }

  /// Guarda la ubicación de referencia del cliente en su perfil (CU-094). Quien
  /// llama la usa como complemento: una falla no corta nada.
  Future<ApiResult<void>> updateLocation(double lat, double lng) async {
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final userId = _customer.customerId;
    if (userId.isEmpty) return const ApiResult.fail(ApiErrorText.generic);
    // La ruta pide el `customer_id`; `customerId` de la app es el id de usuario.
    var recordId = _customerRecordId;
    if (recordId == null) {
      final read =
          await _customerDatasource.fetchCustomerRecordId(userId, token);
      if (!read.ok || read.data == null) {
        return ApiResult.fail(read.message ?? ApiErrorText.generic,
            status: read.status);
      }
      recordId = _customerRecordId = read.data;
    }
    return _customerDatasource.updateLocation(recordId!, '$lat,$lng', token);
  }

  /// Marca una dirección como predeterminada y recarga la lista.
  Future<ApiResult<void>> setDefaultAddress(String addressId) async {
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final result = await _addresses.setDefault(addressId, token);
    if (result.ok) await refreshAddresses();
    return result;
  }

  /// Elimina una dirección y recarga la lista.
  Future<ApiResult<void>> deleteAddress(String addressId) async {
    final token = await this.token;
    if (token == null) return const ApiResult.fail(ApiErrorText.sessionExpired);
    final result = await _addresses.delete(addressId, token);
    if (result.ok) await refreshAddresses();
    return result;
  }

  void addAddress(Address address) {
    List<Address> addresses = List<Address>.from(_customer.addresses);
    // Last address is primary
    if (addresses.isNotEmpty) {
      addresses = addresses.map((e) => e.copyWith(primary: false)).toList();
    }

    addresses.insert(0, address);
    _customer = _customer.copyWith(addresses: addresses);
    // This not check if the address was created successfully
    _submitAddress(address);
  }

  Future<void> _submitAddress(Address address) async {
    final token = await this.token;
    if (token == null) {
      return;
    }

    final addressRemoteDataSource = AddressRemoteDataSource();
    final addressRepositoryImp = AddressRepositoryImp(addressRemoteDataSource);
    final addressUseCase = CreateAddressUsecases(addressRepositoryImp);
    await addressUseCase(address, token, _customer.customerId);
  }

  static final Customer _anonymous = Customer(
    customerId: '',
    fullName: '',
    email: '',
    phoneNumber: '',
    blocked: false,
    addresses: [],
  );

  Customer _customer = _anonymous;
}
