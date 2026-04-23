import 'package:jennygas_lib/domain/address.dart';
import 'package:jennigas_customer/data/datasource/address_remote_datasource.dart';
import 'package:jennigas_customer/domain/repository/address_repository.dart';

class AddressRepositoryImp implements AddressRepository {
  final AddressRemoteDataSource _addressRemoteDataSource;

  AddressRepositoryImp(this._addressRemoteDataSource);

  @override
  Future<bool> createAddress(
          Address address, String token, String userId) async =>
      await _addressRemoteDataSource.createAddress(
          address.toJson(), token, userId);
}
