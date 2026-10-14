import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/ui/common/app_icons.dart';

/// Pregunta si la foto sale de la cámara o de la galería (null = cancelado).
Future<PhotoSource?> choosePhotoSource(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SplgOptionRow(
              key: const Key('photo-source-camera'),
              icon: AppIcons.camera,
              title: 'Sacar foto',
              onTap: () => Navigator.pop(ctx, PhotoSource.camera),
            ),
            SplgOptionRow(
              key: const Key('photo-source-gallery'),
              icon: AppIcons.gallery,
              title: 'Elegir de la galería',
              onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
