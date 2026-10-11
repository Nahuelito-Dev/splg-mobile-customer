// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:stacked_services/src/bottom_sheet/bottom_sheet_service.dart';
import 'package:stacked_services/src/dialog/dialog_service.dart';
import 'package:stacked_services/src/navigation/navigation_service.dart';
import 'package:stacked_shared/stacked_shared.dart';

import '../services/app_permissions.dart';
import '../services/cart_service.dart';
import '../services/claim_service.dart';
import '../services/customer_service.dart';
import '../services/gas_cylinder_service.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/order_tracking_service.dart';
import '../services/rating_service.dart';
import '../services/time_slot_service.dart';

final locator = StackedLocator.instance;

Future<void> setupLocator({
  String? environment,
  EnvironmentFilter? environmentFilter,
}) async {
// Register environments
  locator.registerEnvironment(
      environment: environment, environmentFilter: environmentFilter);

// Register dependencies
  locator.registerLazySingleton(() => BottomSheetService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => HistoryService());
  locator.registerLazySingleton(() => GasCylinderService());
  locator.registerLazySingleton(() => CustomerService());
  locator.registerLazySingleton(() => CartService());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton(() => OrderTrackingService());
  locator.registerLazySingleton(() => TimeSlotService());
  locator.registerLazySingleton(() => RatingService());
  locator.registerLazySingleton(() => ClaimService());
  locator.registerLazySingleton(() => NotificationService());
  locator.registerLazySingleton(() => AppPermissions());
}
