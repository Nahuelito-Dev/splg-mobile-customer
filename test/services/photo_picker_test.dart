import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/services/photo_picker.dart';

/// Marcadores de los segmentos del JPEG antes de los datos de imagen.
List<int> _markers(Uint8List jpeg) {
  final out = <int>[];
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF) {
    final m = jpeg[i + 1];
    out.add(m);
    if (m == 0xDA) break;
    i += 2 + ((jpeg[i + 2] << 8) | jpeg[i + 3]);
  }
  return out;
}

bool _contains(Uint8List bytes, String text) {
  final n = text.codeUnits;
  for (var i = 0; i <= bytes.length - n.length; i++) {
    var ok = true;
    for (var j = 0; j < n.length; j++) {
      if (bytes[i + j] != n[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// JPEG de [w]x[h] con la mitad izquierda roja y la derecha azul, con EXIF
/// (GPS + orientación) en un segmento APP1.
Uint8List _jpegConExif(int w, int h, {int orientation = 1}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(0, 0, 255));
  img.fillRect(image,
      x1: 0, y1: 0, x2: w ~/ 2, y2: h, color: img.ColorRgb8(255, 0, 0));
  image.exif.imageIfd.orientation = orientation;
  image.exif.gpsIfd.gpsLatitude = 27.3671;
  image.exif.gpsIfd.gpsLongitude = 55.8961;
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

class _FotoDelDisco extends ImagePickerPlatform {
  _FotoDelDisco(this.path);

  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoPicker.sanitize', () {
    test('un JPEG con EXIF (GPS + orientación) sale sin APP1 y bien orientado',
        () async {
      final original = _jpegConExif(200, 100, orientation: 6);
      expect(_markers(original), contains(0xE1));
      expect(_contains(original, 'Exif'), isTrue);

      final clean = await PhotoPicker.sanitize(original);

      expect(clean.contentType, 'image/jpeg');
      expect(clean.filename, 'foto.jpg');
      expect(_markers(clean.bytes), isNot(contains(0xE1)));
      expect(_contains(clean.bytes, 'Exif'), isFalse);
      final out = img.decodeJpg(clean.bytes)!;
      // Orientación 6 = girar 90° a la derecha: 200x100 pasa a 100x200 y la
      // mitad izquierda (roja) queda arriba.
      expect((out.width, out.height), (100, 200));
      final top = out.getPixel(50, 20);
      final bottom = out.getPixel(50, 180);
      expect(top.r > 200 && top.b < 80, isTrue, reason: 'arriba roja');
      expect(bottom.b > 200 && bottom.r < 80, isTrue, reason: 'abajo azul');
    });

    test('reduce el lado mayor y baja el peso', () async {
      final original = _jpegConExif(3000, 1500);
      final clean = await PhotoPicker.sanitize(original);
      final out = img.decodeJpg(clean.bytes)!;
      expect(out.width, PhotoPicker.maxSide);
      expect(out.height, PhotoPicker.maxSide ~/ 2);
      expect(clean.bytes.length, lessThan(original.length));
    });

    test('un PNG con texto de metadatos sale como JPEG limpio', () async {
      final image = img.Image(width: 50, height: 50);
      image.textData = {'Comment': 'ubicacion-SECRETA'};
      final png = Uint8List.fromList(img.encodePng(image));
      expect(_contains(png, 'SECRETA'), isTrue);
      final clean = await PhotoPicker.sanitize(png);
      expect(_contains(clean.bytes, 'SECRETA'), isFalse);
      expect(img.decodeJpg(clean.bytes), isNotNull);
    });

    test('una foto chica no se agranda', () async {
      final clean = await PhotoPicker.sanitize(_jpegConExif(200, 100));
      final out = img.decodeJpg(clean.bytes)!;
      expect((out.width, out.height), (200, 100));
    });

    test('bytes que no son imagen: PhotoUnreadable', () {
      expect(PhotoPicker.sanitize(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<PhotoUnreadable>()));
    });
  });

  group('temporal del selector', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('foto_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('fromFile borra el archivo con GPS después de leerlo', () async {
      final f = File('${dir.path}/orig.jpg')
        ..writeAsBytesSync(_jpegConExif(100, 100));
      final photo = await PhotoPicker.fromFile(XFile(f.path));
      expect(f.existsSync(), isFalse);
      expect(_markers(photo.bytes), isNot(contains(0xE1)));
    });

    test('también lo borra si la foto no se puede leer', () async {
      final f = File('${dir.path}/rota.jpg')..writeAsBytesSync([1, 2, 3]);
      await expectLater(
          PhotoPicker.fromFile(XFile(f.path)), throwsA(isA<PhotoUnreadable>()));
      expect(f.existsSync(), isFalse);
    });

    test('pick(galería) entrega la foto limpia y no deja el temporal',
        () async {
      final f = File('${dir.path}/galeria.jpg')
        ..writeAsBytesSync(_jpegConExif(120, 80, orientation: 3));
      ImagePickerPlatform.instance = _FotoDelDisco(f.path);
      final photo = await PhotoPicker().pick(PhotoSource.gallery);
      expect(photo, isNotNull);
      expect(f.existsSync(), isFalse);
      expect(_markers(photo!.bytes), isNot(contains(0xE1)));
    });
  });

  group('SignedUrl', () {
    test('lee el vencimiento de { url, expiresAt }', () {
      final future = DateTime.now().add(const Duration(minutes: 5));
      final s = SignedUrl.fromLink(
          {'url': 'https://x/y', 'expiresAt': future.toIso8601String()});
      expect(s!.isValid, isTrue);
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      expect(
          SignedUrl.fromLink(
                  {'url': 'https://x/y', 'expiresAt': past.toIso8601String()})!
              .isValid,
          isFalse);
    });

    test('sin foto (url null) no hay URL', () {
      expect(SignedUrl.fromLink({'url': null, 'expiresAt': null}), isNull);
    });

    test('calcula el vencimiento de una URL prefirmada de S3', () {
      final s = SignedUrl.fromPresigned(
          'https://b.s3.amazonaws.com/a.png?X-Amz-Date=20200101T000000Z&X-Amz-Expires=300');
      expect(s!.expiresAt, DateTime.utc(2020, 1, 1, 0, 5));
      expect(s.isValid, isFalse);
    });
  });
}
