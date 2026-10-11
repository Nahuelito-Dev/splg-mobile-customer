import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/services/profile_photo_service.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPhotoService photos;
  late DateTime now;
  late ProfilePhotoService service;

  SignedUrl link(String url, Duration life) => SignedUrl(url, now.add(life));
  ApiResult<SignedUrl?> ok(String url, Duration life) =>
      ApiResult.ok(link(url, life));

  setUp(() {
    registerServices();
    photos = MockPhotoService();
    now = DateTime(2026, 10, 11, 12);
    service = ProfilePhotoService(photos: photos, now: () => now);
  });

  group('refresh', () {
    test('trae la URL y la expone', () async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 5)));
      await service.refresh();
      expect(service.url, 'u1');
      expect(service.hasPhoto, isTrue);
    });

    test('con la URL vigente no vuelve a pedir; force sí', () async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 5)));
      await service.refresh();
      await service.refresh();
      verify(photos.myPhotoLink()).called(1);
      await service.refresh(force: true);
      verify(photos.myPhotoLink()).called(1);
    });

    test('sin foto en el back no vuelve a preguntar hasta forzar', () async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => const ApiResult.ok(null));
      await service.refresh();
      await service.refresh();
      verify(photos.myPhotoLink()).called(1);
      expect(service.hasPhoto, isFalse);
      expect(service.url, isNull);
    });

    test('vencida: url es null, hasPhoto sigue y refresh la renueva', () async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 5)));
      await service.refresh();
      now = now.add(const Duration(minutes: 5));
      expect(service.url, isNull);
      expect(service.hasPhoto, isTrue);
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u2', const Duration(minutes: 5)));
      await service.refresh();
      expect(service.url, 'u2');
    });
  });

  group('renovación automática', () {
    testWidgets('pide la URL de nuevo antes de que venza', (t) async {
      var n = 0;
      when(photos.myPhotoLink()).thenAnswer((_) async {
        n++;
        return ok('u$n', const Duration(minutes: 5));
      });
      await service.refresh();
      expect(service.url, 'u1');
      // Vence en 5 min; se renueva 30 s antes.
      now = now.add(const Duration(minutes: 4, seconds: 31));
      await t.pump(const Duration(minutes: 4, seconds: 31));
      await t.pump();
      expect(service.url, 'u2');
      service.clear();
    });

    testWidgets('si la renovación falla conserva hasPhoto y reintenta',
        (t) async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 1)));
      await service.refresh();
      when(photos.myPhotoLink())
          .thenAnswer((_) async => const ApiResult.fail('sin red'));
      await t.pump(const Duration(seconds: 31));
      now = now.add(const Duration(minutes: 2));
      expect(service.hasPhoto, isTrue);
      expect(service.url, isNull);
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u3', const Duration(minutes: 5)));
      await t.pump(const Duration(seconds: 31));
      await t.pump();
      expect(service.url, 'u3');
      service.clear();
    });

    testWidgets('clear cancela la renovación pendiente', (t) async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 5)));
      await service.refresh();
      service.clear();
      clearInteractions(photos);
      await t.pump(const Duration(minutes: 10));
      verifyNever(photos.myPhotoLink());
    });
  });

  group('clear', () {
    test('borra la foto', () async {
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('u1', const Duration(minutes: 5)));
      await service.refresh();
      service.clear();
      expect(service.url, isNull);
      expect(service.hasPhoto, isFalse);
    });

    test('una respuesta en vuelo que llega después de clear no escribe',
        () async {
      final gate = Completer<ApiResult<SignedUrl?>>();
      when(photos.myPhotoLink()).thenAnswer((_) => gate.future);
      final pending = service.refresh();
      service.clear(); // cierra la sesión mientras la respuesta viaja
      gate.complete(
          ok('foto-de-la-cuenta-anterior', const Duration(minutes: 5)));
      await pending;
      expect(service.url, isNull);
      expect(service.hasPhoto, isFalse);
    });

    test('lo mismo para una subida que termina después de clear', () async {
      final photo = PickedPhoto(Uint8List.fromList([1]));
      final gate = Completer<ApiResult<void>>();
      when(photos.uploadMyPhoto(photo)).thenAnswer((_) => gate.future);
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('vieja', const Duration(minutes: 5)));
      final pending = service.upload(photo);
      service.clear();
      gate.complete(const ApiResult.ok());
      await pending;
      expect(service.hasPhoto, isFalse);
      verifyNever(photos.myPhotoLink());
    });
  });

  group('upload y remove', () {
    test('subir refresca la URL; quitar la borra', () async {
      final photo = PickedPhoto(Uint8List.fromList([1]));
      when(photos.uploadMyPhoto(photo))
          .thenAnswer((_) async => const ApiResult.ok());
      when(photos.myPhotoLink())
          .thenAnswer((_) async => ok('nueva', const Duration(minutes: 5)));
      await service.upload(photo);
      expect(service.url, 'nueva');
      when(photos.removeMyPhoto())
          .thenAnswer((_) async => const ApiResult.ok());
      await service.remove();
      expect(service.hasPhoto, isFalse);
    });

    test('si el back rechaza la subida no cambia nada', () async {
      final photo = PickedPhoto(Uint8List.fromList([1]));
      when(photos.uploadMyPhoto(photo)).thenAnswer(
          (_) async => const ApiResult.fail('Formato no soportado.'));
      final r = await service.upload(photo);
      expect(r.ok, isFalse);
      expect(service.hasPhoto, isFalse);
      verifyNever(photos.myPhotoLink());
    });
  });
}
