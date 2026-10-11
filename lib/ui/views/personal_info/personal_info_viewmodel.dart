import 'package:stacked/stacked.dart';

import 'package:splg_lib/domain/customer.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/customer_service.dart';

class PersonalInfoViewModel extends BaseViewModel {
  final _customerService = locator<CustomerService>();

  Customer get customer => _customerService.customer;

  /// Domicilio predeterminado en una línea, o null si no hay.
  String? get primaryAddress {
    final list = customer.addresses;
    if (list.isEmpty) return null;
    final a = list.firstWhere((x) => x.primary, orElse: () => list.first);
    return [
      a.streetName,
      if ((a.city ?? '').isNotEmpty) a.city!,
    ].join(', ');
  }
}
