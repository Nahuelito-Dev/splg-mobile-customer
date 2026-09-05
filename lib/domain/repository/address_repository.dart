import 'package:splg_lib/domain/address.dart';

abstract interface class AddressRepository {
  Future<bool> createAddress(Address address, String token, String userId);
}
