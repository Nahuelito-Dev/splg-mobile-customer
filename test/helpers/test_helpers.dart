import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_lib/permissions/app_permission.dart';
// @stacked-import

import 'test_helpers.mocks.dart';

@GenerateMocks(
  [],
  customMocks: [
    MockSpec<NavigationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<BottomSheetService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<DialogService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<HistoryService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<GasCylinderService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<CustomerService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<CartService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<LocationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<NotificationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<TimeSlotService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<AppPermissions>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<OrderTrackingService>(onMissingStub: OnMissingStub.returnDefault),
// @stacked-mock-spec
  ],
)
void registerServices() {
  provideDummy<PermissionOutcome>(PermissionOutcome.granted);
  getAndRegisterNavigationService();
  getAndRegisterBottomSheetService();
  getAndRegisterDialogService();
  getAndRegisterHistoryService();
  getAndRegisterGasCylinderService();
  getAndRegisterCustomerService();
  getAndRegisterCartService();
  getAndRegisterLocationService();
  getAndRegisterNotificationService();
  getAndRegisterTimeSlotService();
  getAndRegisterAppPermissions();
  getAndRegisterOrderTrackingService();
// @stacked-mock-register
}

MockNavigationService getAndRegisterNavigationService() {
  _removeRegistrationIfExists<NavigationService>();
  final service = MockNavigationService();
  locator.registerSingleton<NavigationService>(service);
  return service;
}

MockBottomSheetService getAndRegisterBottomSheetService<T>({
  SheetResponse<T>? showCustomSheetResponse,
}) {
  _removeRegistrationIfExists<BottomSheetService>();
  final service = MockBottomSheetService();

  when(
    service.showCustomSheet<T, T>(
      enableDrag: anyNamed('enableDrag'),
      enterBottomSheetDuration: anyNamed('enterBottomSheetDuration'),
      exitBottomSheetDuration: anyNamed('exitBottomSheetDuration'),
      ignoreSafeArea: anyNamed('ignoreSafeArea'),
      isScrollControlled: anyNamed('isScrollControlled'),
      barrierDismissible: anyNamed('barrierDismissible'),
      additionalButtonTitle: anyNamed('additionalButtonTitle'),
      variant: anyNamed('variant'),
      title: anyNamed('title'),
      hasImage: anyNamed('hasImage'),
      imageUrl: anyNamed('imageUrl'),
      showIconInMainButton: anyNamed('showIconInMainButton'),
      mainButtonTitle: anyNamed('mainButtonTitle'),
      showIconInSecondaryButton: anyNamed('showIconInSecondaryButton'),
      secondaryButtonTitle: anyNamed('secondaryButtonTitle'),
      showIconInAdditionalButton: anyNamed('showIconInAdditionalButton'),
      takesInput: anyNamed('takesInput'),
      barrierColor: anyNamed('barrierColor'),
      barrierLabel: anyNamed('barrierLabel'),
      customData: anyNamed('customData'),
      data: anyNamed('data'),
      description: anyNamed('description'),
    ),
  ).thenAnswer(
    (realInvocation) =>
        Future.value(showCustomSheetResponse ?? SheetResponse<T>()),
  );

  locator.registerSingleton<BottomSheetService>(service);
  return service;
}

MockDialogService getAndRegisterDialogService() {
  _removeRegistrationIfExists<DialogService>();
  final service = MockDialogService();
  locator.registerSingleton<DialogService>(service);
  return service;
}

MockHistoryService getAndRegisterHistoryService() {
  _removeRegistrationIfExists<HistoryService>();
  final service = MockHistoryService();
  locator.registerSingleton<HistoryService>(service);
  return service;
}

MockGasCylinderService getAndRegisterGasCylinderService() {
  _removeRegistrationIfExists<GasCylinderService>();
  final service = MockGasCylinderService();
  locator.registerSingleton<GasCylinderService>(service);
  return service;
}

MockCustomerService getAndRegisterCustomerService() {
  _removeRegistrationIfExists<CustomerService>();
  final service = MockCustomerService();
  locator.registerSingleton<CustomerService>(service);
  return service;
}

MockCartService getAndRegisterCartService() {
  _removeRegistrationIfExists<CartService>();
  final service = MockCartService();
  locator.registerSingleton<CartService>(service);
  return service;
}

MockLocationService getAndRegisterLocationService() {
  _removeRegistrationIfExists<LocationService>();
  final service = MockLocationService();
  locator.registerSingleton<LocationService>(service);
  return service;
}
// @stacked-mock-create

void _removeRegistrationIfExists<T extends Object>() {
  if (locator.isRegistered<T>()) {
    locator.unregister<T>();
  }
}

MockNotificationService getAndRegisterNotificationService() {
  _removeRegistrationIfExists<NotificationService>();
  final service = MockNotificationService();
  locator.registerSingleton<NotificationService>(service);
  return service;
}

MockTimeSlotService getAndRegisterTimeSlotService() {
  _removeRegistrationIfExists<TimeSlotService>();
  final service = MockTimeSlotService();
  locator.registerSingleton<TimeSlotService>(service);
  return service;
}

MockAppPermissions getAndRegisterAppPermissions() {
  _removeRegistrationIfExists<AppPermissions>();
  final service = MockAppPermissions();
  locator.registerSingleton<AppPermissions>(service);
  return service;
}

MockOrderTrackingService getAndRegisterOrderTrackingService() {
  _removeRegistrationIfExists<OrderTrackingService>();
  final service = MockOrderTrackingService();
  locator.registerSingleton<OrderTrackingService>(service);
  return service;
}
