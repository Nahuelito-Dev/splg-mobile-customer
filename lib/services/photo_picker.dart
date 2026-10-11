import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:splg_lib/permissions/app_permission.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/services/app_permissions.dart';

enum PhotoSource { camera, gallery }

/// Foto lista para subir: ya orientada, redimensionada y sin metadatos.
class PickedPhoto {
  const PickedPhoto(this.bytes,
      {this.filename = 'foto.jpg', this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// Elige una foto de la cámara o la galería y la deja lista para subir:
/// orientada, reducida y recodificada a JPEG desde los píxeles, lo que descarta
/// el EXIF (ubicación GPS). El archivo temporal del selector se borra.
class PhotoPicker {
  /// Lado mayor de la foto que se sube.
  static const maxSide = 1280;

  /// Calidad JPEG de la foto que se sube.
  static const jpegQuality = 85;

  /// Tope del back (5 MB para perfil, 10 MB reclamo); se queda por debajo.
  static const maxBytes = 4 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();

  /// Null si el usuario cancela o niega el permiso. Lanza [PhotoTooLarge] si
  /// aun reducida no entra en el tope y [PhotoUnreadable] si no se puede leer.
  Future<PickedPhoto?> pick(PhotoSource source) async {
    if (source == PhotoSource.camera) {
      final outcome = await locator<AppPermissions>().ensureCameraForPhoto();
      if (!outcome.isGranted) return null;
    }
    // La galería usa el selector del sistema (PHPicker / Photo Picker): da
    // acceso sólo a la foto elegida, sin permiso de fotos.
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxSide.toDouble(),
      maxHeight: maxSide.toDouble(),
      imageQuality: jpegQuality,
    );
    if (file == null) return null;
    return fromFile(file);
  }

  /// Lee y limpia la foto; el temporal del selector se borra siempre (la copia
  /// original puede traer el GPS).
  static Future<PickedPhoto> fromFile(XFile file) async {
    try {
      return await sanitize(await file.readAsBytes());
    } finally {
      await _deleteQuietly(file.path);
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    if (kIsWeb || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Aplica la orientación EXIF, reduce a [maxSide] y recodifica a JPEG: el
  /// resultado no conserva ningún metadato de la foto original.
  static Future<PickedPhoto> sanitize(Uint8List original) async {
    final bytes = await compute(_reencode, original);
    if (bytes == null) throw const PhotoUnreadable();
    if (bytes.length > maxBytes) throw const PhotoTooLarge();
    return PickedPhoto(bytes);
  }
}

Uint8List? _reencode(Uint8List original) {
  final decoded = img.decodeImage(original);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > PhotoPicker.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image,
            width: PhotoPicker.maxSide,
            interpolation: img.Interpolation.average)
        : img.copyResize(image,
            height: PhotoPicker.maxSide,
            interpolation: img.Interpolation.average);
  }
  // Ni EXIF ni perfil de color de la original viajan en el JPEG.
  image.exif = img.ExifData();
  image.iccProfile = null;
  return Uint8List.fromList(
      img.encodeJpg(image, quality: PhotoPicker.jpegQuality));
}

class PhotoTooLarge implements Exception {
  const PhotoTooLarge();

  static const message = 'La foto es demasiado pesada. Probá con otra.';
}

class PhotoUnreadable implements Exception {
  const PhotoUnreadable();

  static const message = 'No pudimos leer la foto. Probá con otra.';
}
