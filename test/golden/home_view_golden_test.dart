import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_lib/theme/app_theme.dart';
import 'package:splg_customer/ui/views/home/home_view.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() => registerServices());
  tearDown(() => locator.reset());

  testGoldens('HomeView - default state', (tester) async {
    await loadAppFonts();

    // Set device pixel ratio and size
    await tester.binding.setSurfaceSize(const Size(393, 852));
    tester.binding.window.devicePixelRatioTestValue = 1.0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(393, 852), devicePixelRatio: 1.0),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HomeView(),
        ),
      ),
    );

    await screenMatchesGolden(tester, 'home_view_default');
  });
}
