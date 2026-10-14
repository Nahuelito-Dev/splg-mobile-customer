import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS explica que las fotos sirven al perfil y al reclamo', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final text = RegExp(
            r'<key>NSPhotoLibraryUsageDescription</key>\s*<string>(.*?)</string>')
        .firstMatch(plist)!
        .group(1)!;

    expect(text, contains('perfil'));
    expect(text, contains('reclamo'));
  });

  test('Android no pide el permiso de fotos: se usa el selector del sistema',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
  });

  test('la galería se abre con el selector del sistema, sin pedir permiso', () {
    final picker = File('lib/services/photo_picker.dart').readAsStringSync();

    expect(picker, contains('ImageSource.gallery'));
    expect(picker, isNot(contains('AppPermission.photos')));
  });
}
