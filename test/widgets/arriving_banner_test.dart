import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splg_customer/ui/views/order_tracking/widgets/arriving_banner.dart';
import 'package:splg_lib/theme/app_theme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final entry in {
    'claro': AppTheme.lightTheme,
    'oscuro': AppTheme.darkTheme,
  }.entries) {
    testWidgets('ArrivingBanner se lee (AA) en tema ${entry.key}', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: entry.value,
        home: const Scaffold(body: Center(child: ArrivingBanner())),
      ));

      final text = t.widget<Text>(find.textContaining('llegando'));
      final box = t.widget<Container>(find.byType(Container).first);
      final bg = (box.decoration as BoxDecoration).color!;

      expect(_contrast(text.style!.color!, bg), greaterThanOrEqualTo(4.5));
    });
  }
}
