import 'package:jennygas_lib/domain/address.dart';

abstract interface class AddressRepository {
  Future<bool> createAddress(Address address, String token, String userId);
}
