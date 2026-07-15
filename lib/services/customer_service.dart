import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:jennigas_customer/data/datasource/address_remote_datasource.dart';
import 'package:jennigas_customer/data/repository/address_repository_imp.dart';

import 'package:jennigas_customer/domain/repository/customer_repository.dart';
import 'package:jennigas_customer/data/repository/customer_repository_imp.dart';
import 'package:jennigas_customer/data/datasource/customer_remote_datasource.dart';
import 'package:jennigas_customer/domain/usecases/create_address_usecases.dart';
import 'package:jennigas_customer/domain/usecases/create_customer_usecases.dart';
import 'package:jennigas_customer/domain/usecases/fetch_customer_usecases.dart';

import 'package:jennygas_lib/domain/address.dart';
import 'package:jennygas_lib/domain/customer.dart';

class CustomerService {
  CustomerService() {
    _customerRepository = CustomerRepositoryImp(_customerDatasource);
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool get isUserLoggedIn => _firebaseAuth.currentUser != null;

  Future<String?> get token async {
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

    final customer =
        await fetchCustomerByEmail(_firebaseAuth.currentUser?.email ?? '');
    return customer;
  }

  Future<bool> registerCustomer({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    final body = {
      'full_name': name,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
    };

    final createCustomerUseCase = CreateCustomerUseCase(_customerRepository);

    final customer = await createCustomerUseCase(body);
    if (customer != null) {
      setCustomer(customer);
      return true;
    }

    return false;
  }

  Future<bool> fetchCustomerByEmail(String email) async {
    final token = await this.token;
    if (token == null) {
      return false;
    }

    final fetchCustomerUseCase = FetchCustomerUseCase(_customerRepository);
    final customer = await fetchCustomerUseCase(email, token);
    if (customer != null) {
      setCustomer(customer);
      return true;
    }
    return false;
  }

  /// Signs in a user with email and password.
  /// Returns true if sign in was successful, false otherwise.
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);

      final success = await fetchCustomerByEmail(email);
      if (success) {
        return true;
      }

      await _firebaseAuth.signOut();
      return false;
    } on FirebaseAuthException catch (e) {
      log('Error during sign in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  bool _isInvalidUserError(FirebaseAuthException error) {
    return error.code == 'user-not-found' || error.code == 'user-disabled';
  }

  Customer get customer => _customer;

  void setCustomer(Customer customer) {
    _customer = customer;
  }

  /// Actualiza el perfil (nombre y/o teléfono) contra `PATCH /users/:id` y, si
  /// el backend confirma, refleja el cambio en el customer local.
  Future<bool> updateProfile({String? fullName, String? phoneNumber}) async {
    final token = await this.token;
    if (token == null) return false;

    final data = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      data['full_name'] = fullName.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      data['phone_number'] = phoneNumber.trim();
    }
    if (data.isEmpty) return false;

    final ok = await _customerDatasource.updateUser(
      _customer.customerId,
      data,
      token,
    );
    if (ok) {
      _customer = _customer.copyWith(
        fullName: data['full_name'] as String? ?? _customer.fullName,
        phoneNumber: data['phone_number'] as String? ?? _customer.phoneNumber,
      );
    }
    return ok;
  }

  /// Recarga las direcciones del usuario desde el backend
  /// (`GET /user-address/user/:id`) y las refleja en el customer local.
  Future<void> refreshAddresses() async {
    final token = await this.token;
    if (token == null) return;

    final raw = await AddressRemoteDataSource().fetchByUser(
      _customer.customerId,
      token,
    );
    final addresses = raw.map(Address.fromJson).toList();
    _customer = _customer.copyWith(addresses: addresses);
  }

  /// Crea una dirección esperando la confirmación del backend y recarga la
  /// lista (a diferencia de [addAddress], que es optimista y fire-and-forget).
  Future<bool> createAndSyncAddress(Address address) async {
    final token = await this.token;
    if (token == null) return false;
    final ok = await AddressRemoteDataSource().createAddress(
      address.toJson(),
      token,
      _customer.customerId,
    );
    if (ok) await refreshAddresses();
    return ok;
  }

  /// Actualiza una dirección existente y recarga la lista.
  Future<bool> updateAddress(Address address) async {
    final token = await this.token;
    if (token == null) return false;
    final ok = await AddressRemoteDataSource().updateAddress(
      address.addressId,
      address.toJson(),
      token,
    );
    if (ok) await refreshAddresses();
    return ok;
  }

  /// Marca una dirección como predeterminada y recarga la lista.
  Future<bool> setDefaultAddress(String addressId) async {
    final token = await this.token;
    if (token == null) return false;
    final ok = await AddressRemoteDataSource().setDefault(addressId, token);
    if (ok) await refreshAddresses();
    return ok;
  }

  /// Elimina una dirección y recarga la lista.
  Future<bool> deleteAddress(String addressId) async {
    final token = await this.token;
    if (token == null) return false;
    final ok = await AddressRemoteDataSource().deleteAddress(addressId, token);
    if (ok) await refreshAddresses();
    return ok;
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

  // Mock user.
  Customer _customer = Customer(
      customerId: '1234',
      fullName: 'Demo user',
      email: 'demo@email.com',
      phoneNumber: '(+54) 3895677879',
      blocked: false,
      addresses: []);
}
