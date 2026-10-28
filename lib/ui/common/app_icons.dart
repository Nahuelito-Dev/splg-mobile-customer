import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Íconos Phosphor (los mismos de `SplgIcons`) que la app del cliente usa y la
/// lib compartida todavía no trae: cámara, galería, copiar, PDF y banco. Cuando `SplgIcons` los
/// sume, se borran de acá.
class AppIcons {
  AppIcons._();

  static const IconData camera = PhosphorIconsRegular.camera;
  static const IconData cameraSlash = PhosphorIconsRegular.cameraSlash;
  static const IconData gallery = PhosphorIconsRegular.image;
  static const IconData copy = PhosphorIconsRegular.copy;
  static const IconData filePdf = PhosphorIconsRegular.filePdf;
  static const IconData fileUpload = PhosphorIconsRegular.fileArrowUp;
  static const IconData bank = PhosphorIconsRegular.bank;
}
