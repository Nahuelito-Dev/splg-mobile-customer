import 'package:jennygas_lib/domain/customer.dart';

abstract interface class CustomerRepository {
  Future<Customer?> createCustomer(Map<String, dynamic> customerData);
  Future<Customer?> fetchCustomerByEmail(String email, String token);
}
