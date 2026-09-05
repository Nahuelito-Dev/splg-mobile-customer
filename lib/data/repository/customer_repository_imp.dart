import 'dart:developer';

import 'package:splg_lib/domain/customer.dart';
import 'package:splg_customer/domain/repository/customer_repository.dart';
import 'package:splg_customer/data/datasource/customer_remote_datasource.dart';

class CustomerRepositoryImp implements CustomerRepository {
  final CustomerRemoteDatasource remoteDatasource;

  CustomerRepositoryImp(this.remoteDatasource);

  @override
  Future<Customer?> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final (isSuccess, data) =
          await remoteDatasource.createCustomer(customerData);
      if (isSuccess && data != null) {
        log('UserRepositoryImp - createCustomer: $data');
        return Customer.fromJson(data);
      }
    } catch (e) {
      log(e.toString());
    }

    return null;
  }

  @override
  Future<Customer?> fetchCustomerByEmail(String email, String token) async {
    try {
      final (isSuccess, data) =
          await remoteDatasource.fetchCustomerByEmail(email, token);
      if (isSuccess && data != null) {
        log('UserRepositoryImp - fetchCustomerByEmail: $data');
        return Customer.fromJson(data);
      }
    } catch (e) {
      log(e.toString());
    }

    return null;
  }
}
