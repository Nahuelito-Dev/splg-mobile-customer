import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:splg_lib/theme/app_theme.dart';
import 'package:splg_lib/theme/splg_licenses.dart';
import 'package:splg_customer/app/app.router.dart';
import 'package:splg_customer/app/app.dialogs.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/firebase_options.dart';
import 'package:splg_customer/app/app.bottomsheets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La licencia de la tipografía (Geist, OFL) viaja en la app.
  registerSplgLicenses();
  await initializeDateFormatting('es_AR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await setupLocator();
  setupDialogUi();
  setupBottomSheetUi();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: Routes.startupView,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      navigatorKey: StackedService.navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      navigatorObservers: [StackedService.routeObserver],
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
      ],
    );
  }
}
