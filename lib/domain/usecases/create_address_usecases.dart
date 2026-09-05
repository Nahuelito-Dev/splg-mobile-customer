import 'package:splg_lib/domain/address.dart';

import 'package:splg_customer/domain/repository/address_repository.dart';

class CreateAddressUsecases {
  final AddressRepository _addressRepository;

  CreateAddressUsecases(this._addressRepository);

  Future<bool> call(Address address, String token, String userId) async =>
      await _addressRepository.createAddress(address, token, userId);
}
