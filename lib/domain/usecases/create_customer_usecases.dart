import 'package:splg_lib/splg_lib.dart';
import 'package:splg_customer/domain/repository/customer_repository.dart';

class CreateCustomerUseCase {
  final CustomerRepository userRepository;

  CreateCustomerUseCase(this.userRepository);

  Future<Customer?> call(Map<String, dynamic> customerData) async =>
      await userRepository.createCustomer(customerData);
}
