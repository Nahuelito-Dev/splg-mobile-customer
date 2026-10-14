import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/services/photo_picker.dart';
import 'package:splg_customer/ui/common/app_icons.dart';
import 'package:splg_customer/ui/widgets/photo_source_sheet.dart';
import 'package:splg_lib/splg_lib.dart';

/// Pantallas ya migradas al sistema de íconos (Phosphor vía `SplgIcons`): no
/// vuelven los `Icons.` de Material.
const _migradas = [
  'lib/ui/widgets/photo_source_sheet.dart',
  'lib/ui/views/profile/profile_view.dart',
  'lib/ui/views/claim_detail/claim_detail_view.dart',
  'lib/ui/views/qr_scan/qr_scan_view.dart',
  'lib/ui/views/order_tracking/order_tracking_view.dart',
];

void main() {
  for (final path in _migradas) {
    test('$path no usa íconos de Material', () {
      final source = File(path).readAsStringSync();
      expect(RegExp(r'\bIcons\.').hasMatch(source), isFalse);
    });
  }

  testWidgets('el selector de foto ofrece cámara y galería con Phosphor',
      (t) async {
    PhotoSource? elegido;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => elegido = await choosePhotoSource(context),
          child: const Text('abrir'),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.byIcon(AppIcons.camera), findsOneWidget);
    expect(find.byIcon(AppIcons.gallery), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);

    await t.tap(find.byKey(const Key('photo-source-gallery')));
    await t.pumpAndSettle();
    expect(elegido, PhotoSource.gallery);
  });
}
