import 'package:splg_lib/domain/customer.dart';
import 'package:splg_customer/domain/repository/customer_repository.dart';

class FetchCustomerUseCase {
  final CustomerRepository _customerRepository;

  FetchCustomerUseCase(this._customerRepository);

  Future<Customer?> call(String email, String token) async =>
      await _customerRepository.fetchCustomerByEmail(email, token);
}
