import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:splg_customer/services/photo_picker.dart';

enum ReceiptSource { camera, gallery, pdf }

/// Archivo listo para subir como comprobante: foto limpia o PDF.
class PickedReceipt {
  const PickedReceipt(this.bytes, this.filename, this.contentType);

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// Elige el comprobante: foto de la cámara o la galería (se limpia igual que
/// el resto de las fotos) o un PDF del selector de archivos.
class ReceiptPicker {
  ReceiptPicker({PhotoPicker? photos, Future<PickedReceipt?> Function()? pdf})
      : _photos = photos ?? PhotoPicker(),
        _pdf = pdf ?? _pickPdf;

  /// Tope del back para un comprobante.
  static const maxBytes = 10 * 1024 * 1024;

  final PhotoPicker _photos;
  final Future<PickedReceipt?> Function() _pdf;

  /// Null si el usuario cancela o niega el permiso. Lanza [PhotoTooLarge] y
  /// [PhotoUnreadable] (fotos) o [ReceiptTooLarge] y [ReceiptUnreadable] (PDF).
  Future<PickedReceipt?> pick(ReceiptSource source) async {
    if (source == ReceiptSource.pdf) return _pdf();
    final photo = await _photos.pick(source == ReceiptSource.camera
        ? PhotoSource.camera
        : PhotoSource.gallery);
    if (photo == null) return null;
    return PickedReceipt(photo.bytes, 'comprobante.jpg', photo.contentType);
  }

  static Future<PickedReceipt?> _pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    // Se mide antes de leerlo: un PDF de cientos de MB no se carga entero en memoria.
    final size = await file.length();
    if (size != null && size > maxBytes) throw const ReceiptTooLarge();
    return fromPdfBytes(file.name, await file.readAsBytes());
  }

  /// Valida los bytes de un PDF elegido: que entre en el tope y que sea un PDF
  /// (el back también lo verifica por el contenido).
  static PickedReceipt fromPdfBytes(String name, Uint8List bytes) {
    if (bytes.length > maxBytes) throw const ReceiptTooLarge();
    final isPdf = bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if (!isPdf) throw const ReceiptUnreadable();
    return PickedReceipt(
        bytes, name.isEmpty ? 'comprobante.pdf' : name, 'application/pdf');
  }
}

class ReceiptTooLarge implements Exception {
  const ReceiptTooLarge();

  static const message = 'El PDF pesa más de 10 MB. Probá con otro.';
}

class ReceiptUnreadable implements Exception {
  const ReceiptUnreadable();

  static const message = 'No pudimos leer el PDF. Probá con otro.';
}
