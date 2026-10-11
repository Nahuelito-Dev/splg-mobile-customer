import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/data/datasource/claim_remote_datasource.dart';
import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/photo_service.dart';
import 'package:splg_customer/services/profile_photo_service.dart';
import 'package:splg_customer/ui/bottom_sheets/claim/claim_sheet_model.dart';
import 'package:splg_customer/ui/views/claim_detail/claim_detail_viewmodel.dart';
import 'package:splg_customer/ui/views/profile/profile_viewmodel.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

class FakePicker extends PhotoPicker {
  FakePicker(this.result, {this.error});

  final PickedPhoto? result;
  final Object? error;
  PhotoSource? asked;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    asked = source;
    if (error != null) throw error!;
    return result;
  }
}

class GatedPicker extends PhotoPicker {
  GatedPicker(this.gate);

  final Future<PickedPhoto?> gate;
  int calls = 0;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) {
    calls++;
    return gate;
  }
}

final photo = PickedPhoto(Uint8List.fromList([1, 2, 3]));

void main() {
  test('el alta de reclamo devuelve el id en snake_case (contrato del back)',
      () {
    expect(ClaimRemoteDatasource.claimIdFrom({'claim_id': 'c9'}), 'c9');
    expect(ClaimRemoteDatasource.claimIdFrom({'claimId': 'c8'}), 'c8');
    expect(ClaimRemoteDatasource.claimIdFrom('x'), isNull);
  });

  late MockClaimService claims;
  late MockPhotoService photos;
  late MockProfilePhotoService profilePhoto;
  late MockCustomerService customers;

  setUp(() {
    registerServices();
    claims = locator<ClaimService>() as MockClaimService;
    photos = locator<PhotoService>() as MockPhotoService;
    profilePhoto = locator<ProfilePhotoService>() as MockProfilePhotoService;
    customers = locator<CustomerService>() as MockCustomerService;
    when(customers.customer).thenReturn(customerWith());
  });
  tearDown(() => locator.reset());

  group('ClaimSheetModel con foto', () {
    ClaimSheetModel model(FakePicker p) {
      final m = ClaimSheetModel()..picker = p;
      m.descriptionController.text = 'Pierde gas';
      return m;
    }

    test('crea el reclamo y después sube la foto al id creado', () async {
      when(claims.createClaim(
              orderId: 'o1',
              reason: anyNamed('reason'),
              description: 'Pierde gas'))
          .thenAnswer((_) async => const ApiResult.ok('c1'));
      when(photos.uploadClaimPhoto('c1', photo))
          .thenAnswer((_) async => const ApiResult.ok());
      final m = model(FakePicker(photo));
      await m.attach(PhotoSource.camera);
      expect(m.photo, photo);
      expect(await m.submit('o1'), isTrue);
      verifyInOrder([
        claims.createClaim(
            orderId: 'o1',
            reason: anyNamed('reason'),
            description: 'Pierde gas'),
        photos.uploadClaimPhoto('c1', photo),
      ]);
      expect(m.photoWarning, isNull);
    });

    test('sin foto no se sube nada', () async {
      when(claims.createClaim(
              orderId: 'o1',
              reason: anyNamed('reason'),
              description: 'Pierde gas'))
          .thenAnswer((_) async => const ApiResult.ok('c1'));
      final m = model(FakePicker(null));
      await m.attach(PhotoSource.gallery);
      expect(m.photo, isNull);
      expect(await m.submit('o1'), isTrue);
      verifyNever(photos.uploadClaimPhoto(any, any));
    });

    test('si la foto falla el reclamo igual queda enviado y se avisa',
        () async {
      when(claims.createClaim(
              orderId: 'o1',
              reason: anyNamed('reason'),
              description: 'Pierde gas'))
          .thenAnswer((_) async => const ApiResult.ok('c1'));
      when(photos.uploadClaimPhoto('c1', photo)).thenAnswer(
          (_) async => const ApiResult.fail('La foto supera los 10 MB.'));
      final m = model(FakePicker(photo));
      await m.attach(PhotoSource.camera);
      expect(await m.submit('o1'), isTrue);
      expect(m.photoWarning, contains('La foto supera los 10 MB.'));
    });

    test('foto demasiado pesada: mensaje y no se adjunta', () async {
      final m = model(FakePicker(null, error: const PhotoTooLarge()));
      await m.attach(PhotoSource.gallery);
      expect(m.photo, isNull);
      expect(m.errorMessage, PhotoTooLarge.message);
    });
  });

  group('ProfileViewModel con foto', () {
    test('cambiar sube la foto elegida', () async {
      when(profilePhoto.upload(photo))
          .thenAnswer((_) async => const ApiResult.ok());
      final p = FakePicker(photo);
      final m = ProfileViewModel()..picker = p;
      await m.changePhoto(PhotoSource.gallery);
      expect(p.asked, PhotoSource.gallery);
      verify(profilePhoto.upload(photo)).called(1);
      expect(m.photoError, isNull);
    });

    test('cancelar el selector no sube nada', () async {
      final m = ProfileViewModel()..picker = FakePicker(null);
      await m.changePhoto(PhotoSource.camera);
      verifyNever(profilePhoto.upload(any));
    });

    test('un rechazo del back (415) se muestra', () async {
      when(profilePhoto.upload(photo)).thenAnswer((_) async =>
          const ApiResult.fail('Formato no soportado.', status: 415));
      final m = ProfileViewModel()..picker = FakePicker(photo);
      await m.changePhoto(PhotoSource.gallery);
      expect(m.photoError, 'Formato no soportado.');
    });

    test('quitar llama al back', () async {
      when(profilePhoto.remove()).thenAnswer((_) async => const ApiResult.ok());
      await ProfileViewModel().removePhoto();
      verify(profilePhoto.remove()).called(1);
    });
  });

  group('ClaimDetailViewModel', () {
    test('muestra la URL firmada vigente', () async {
      when(photos.claimPhotoLink('c1')).thenAnswer((_) async => ApiResult.ok(
          SignedUrl(
              'https://s3/x', DateTime.now().add(const Duration(minutes: 5)))));
      final m = ClaimDetailViewModel('c1', ClaimStatus.pending);
      await m.loadPhoto();
      expect(m.photoUrl, 'https://s3/x');
    });

    test('una URL vencida no se muestra', () async {
      when(photos.claimPhotoLink('c1')).thenAnswer((_) async => ApiResult.ok(
          SignedUrl('https://s3/x',
              DateTime.now().subtract(const Duration(minutes: 1)))));
      final m = ClaimDetailViewModel('c1', ClaimStatus.pending);
      await m.loadPhoto();
      expect(m.photoUrl, isNull);
    });

    test('reclamo sin foto', () async {
      when(photos.claimPhotoLink('c1'))
          .thenAnswer((_) async => const ApiResult.ok(null));
      final m = ClaimDetailViewModel('c1', ClaimStatus.pending);
      await m.loadPhoto();
      expect(m.photoUrl, isNull);
    });
  });

  group('ClaimSheetModel: foto en proceso', () {
    test('mientras se procesa la foto no se puede enviar', () async {
      final gate = Completer<PickedPhoto?>();
      final m = ClaimSheetModel()..picker = GatedPicker(gate.future);
      m.descriptionController.text = 'Pierde gas';
      final pending = m.attach(PhotoSource.gallery);
      expect(m.processingPhoto, isTrue);
      expect(await m.submit('o1'), isFalse);
      verifyNever(claims.createClaim(
          orderId: anyNamed('orderId'),
          reason: anyNamed('reason'),
          description: anyNamed('description')));
      gate.complete(photo);
      await pending;
      expect(m.processingPhoto, isFalse);
      expect(m.photo, photo);
    });

    test('el aviso de foto fallida manda a Mis reclamos', () async {
      when(claims.createClaim(
              orderId: 'o1',
              reason: anyNamed('reason'),
              description: 'Pierde gas'))
          .thenAnswer((_) async => const ApiResult.ok('c1'));
      when(photos.uploadClaimPhoto('c1', photo))
          .thenAnswer((_) async => const ApiResult.fail('Sin conexión.'));
      final m = ClaimSheetModel()..picker = FakePicker(photo);
      m.descriptionController.text = 'Pierde gas';
      await m.attach(PhotoSource.camera);
      await m.submit('o1');
      expect(m.photoWarning, contains('Mis reclamos'));
    });
  });

  group('ClaimDetailViewModel: agregar o cambiar la foto', () {
    SignedUrl vigente() => SignedUrl(
        'https://s3/x', DateTime.now().add(const Duration(minutes: 5)));

    test('sube y vuelve a pedir la URL firmada', () async {
      when(photos.uploadClaimPhoto('c1', photo))
          .thenAnswer((_) async => const ApiResult.ok());
      when(photos.claimPhotoLink('c1'))
          .thenAnswer((_) async => ApiResult.ok(vigente()));
      final p = FakePicker(photo);
      final m = ClaimDetailViewModel('c1', ClaimStatus.pending)..picker = p;
      expect(m.canAttach, isTrue);
      await m.attach(PhotoSource.gallery);
      verify(photos.uploadClaimPhoto('c1', photo)).called(1);
      expect(m.photoUrl, 'https://s3/x');
      expect(m.photoError, isNull);
    });

    test('un reclamo resuelto o rechazado no admite foto (409 del back)',
        () async {
      for (final s in [ClaimStatus.resolved, ClaimStatus.rejected]) {
        final p = FakePicker(photo);
        final m = ClaimDetailViewModel('c1', s)..picker = p;
        expect(m.canAttach, isFalse);
        await m.attach(PhotoSource.gallery);
        expect(p.asked, isNull);
      }
      verifyNever(photos.uploadClaimPhoto(any, any));
    });

    test('un rechazo del back se muestra y no pide la URL', () async {
      when(photos.uploadClaimPhoto('c1', photo)).thenAnswer((_) async =>
          const ApiResult.fail('El reclamo ya está cerrado.', status: 409));
      final m = ClaimDetailViewModel('c1', ClaimStatus.inProcess)
        ..picker = FakePicker(photo);
      await m.attach(PhotoSource.gallery);
      expect(m.photoError, 'El reclamo ya está cerrado.');
      verifyNever(photos.claimPhotoLink(any));
    });

    test('un segundo toque mientras el selector está abierto se ignora',
        () async {
      final gate = Completer<PickedPhoto?>();
      final p = GatedPicker(gate.future);
      final m = ClaimDetailViewModel('c1', ClaimStatus.pending)..picker = p;
      final first = m.attach(PhotoSource.gallery);
      await m.attach(PhotoSource.camera);
      expect(p.calls, 1);
      gate.complete(null);
      await first;
    });
  });

  group('ProfileViewModel: un solo selector a la vez', () {
    test('el segundo toque se ignora mientras el primero está abierto',
        () async {
      when(profilePhoto.upload(photo))
          .thenAnswer((_) async => const ApiResult.ok());
      final gate = Completer<PickedPhoto?>();
      final p = GatedPicker(gate.future);
      final m = ProfileViewModel()..picker = p;
      final first = m.changePhoto(PhotoSource.gallery);
      await m.changePhoto(PhotoSource.camera);
      expect(p.calls, 1);
      expect(m.busy('photo'), isTrue);
      gate.complete(photo);
      await first;
      expect(m.busy('photo'), isFalse);
      verify(profilePhoto.upload(photo)).called(1);
    });
  });
}
