import 'package:flutter/material.dart';

import 'package:splg_customer/services/photo_picker.dart';

/// Pregunta si la foto sale de la cámara o de la galería (null = cancelado).
Future<PhotoSource?> choosePhotoSource(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar foto'),
              onTap: () => Navigator.pop(ctx, PhotoSource.camera),
            ),
            ListTile(
              key: const Key('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
