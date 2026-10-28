import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/services/receipt_picker.dart';
import 'package:splg_customer/ui/common/app_icons.dart';

/// Pregunta de dónde sale el comprobante: cámara, galería o un PDF (null =
/// cancelado).
Future<ReceiptSource?> chooseReceiptSource(BuildContext context) =>
    showModalBottomSheet<ReceiptSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SplgOptionRow(
              key: const Key('receipt-source-camera'),
              icon: AppIcons.camera,
              title: 'Sacar foto',
              onTap: () => Navigator.pop(ctx, ReceiptSource.camera),
            ),
            SplgOptionRow(
              key: const Key('receipt-source-gallery'),
              icon: AppIcons.gallery,
              title: 'Elegir de la galería',
              onTap: () => Navigator.pop(ctx, ReceiptSource.gallery),
            ),
            SplgOptionRow(
              key: const Key('receipt-source-pdf'),
              icon: AppIcons.filePdf,
              title: 'Elegir un PDF',
              onTap: () => Navigator.pop(ctx, ReceiptSource.pdf),
            ),
          ],
        ),
      ),
    );
