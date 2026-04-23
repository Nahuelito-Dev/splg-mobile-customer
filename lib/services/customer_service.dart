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
