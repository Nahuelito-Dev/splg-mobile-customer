import 'dart:typed_data';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:splg_customer/app/app.locator.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:splg_customer/services/history_service.dart';
import 'package:splg_customer/services/order_document_service.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/services/customer_service.dart';
import 'package:splg_customer/services/cart_service.dart';
import 'package:splg_customer/services/consumption_service.dart';
import 'package:splg_customer/domain/cart.dart';
import 'package:splg_customer/domain/consumption.dart';
import 'package:splg_customer/services/location_service.dart';
import 'package:splg_customer/services/notification_service.dart';
import 'package:splg_customer/services/time_slot_service.dart';
import 'package:splg_customer/services/app_permissions.dart';
import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/services/claim_service.dart';
import 'package:splg_customer/services/rating_service.dart';
import 'package:splg_customer/services/session_service.dart';
import 'package:splg_customer/services/photo_service.dart';
import 'package:splg_customer/services/profile_photo_service.dart';
import 'package:splg_customer/domain/signed_url.dart';
import 'package:splg_customer/domain/orders_page.dart';
import 'package:splg_lib/domain/address.dart';
import 'package:splg_lib/domain/order.dart';
import 'package:splg_customer/core/network/api_result.dart';
import 'package:splg_customer/domain/cancel_result.dart';
import 'package:splg_customer/domain/order_breakdown.dart';
import 'package:splg_customer/domain/delivery_options.dart';
import 'package:splg_customer/domain/order_quote.dart';
import 'package:splg_customer/domain/update_order_result.dart';
import 'package:splg_customer/domain/my_claim.dart';
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
    MockSpec<ConsumptionService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<LocationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<NotificationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<TimeSlotService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<AppPermissions>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<OrderTrackingService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<ClaimService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<RatingService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<SessionService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<PhotoService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<ProfilePhotoService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<OrderDocumentService>(onMissingStub: OnMissingStub.returnDefault),
// @stacked-mock-spec
  ],
)
void registerServices() {
  provideDummy<PermissionOutcome>(PermissionOutcome.granted);
  provideDummy<ApiResult<void>>(const ApiResult.ok());
  provideDummy<ApiResult<String?>>(const ApiResult.ok());
  provideDummy<ApiResult<SignedUrl?>>(const ApiResult.ok());
  provideDummy<ApiResult<Uint8List>>(ApiResult.ok(Uint8List(0)));
  provideDummy<ApiResult<Address?>>(const ApiResult.ok());
  provideDummy<Cart>(Cart.empty);
  provideDummy<ApiResult<Consumption>>(const ApiResult.ok(Consumption()));
  provideDummy<ConsumptionSaveOutcome>(
      const ConsumptionSaveOutcome(ConsumptionSaveStatus.failed));
  provideDummy<ApiResult<ClaimsPage>>(
      const ApiResult.ok(ClaimsPage(claims: [], total: 0)));
  provideDummy<PasswordChangeResult>(PasswordChangeResult.ok);
  provideDummy<CancelResult>(const CancelResult.ok());
  provideDummy<QuoteOutcome>(const QuoteOutcome.failed('dummy'));
  provideDummy<ConfirmDeliveryOutcome>(
      const ConfirmDeliveryOutcome(ConfirmDeliveryResult.success));
  provideDummy<SignInOutcome>(SignInOutcome.ok);
  provideDummy<OrdersPage>(const OrdersPage(orders: [], total: 0, offset: 0));
  final dummyOrder = Order(
    id: 'dummy',
    items: [],
    total: 0,
    status: OrderStatus.pending,
    createdAt: DateTime(2026),
    paymentMethod: PaymentMethod.cash,
  );
  provideDummy<Order>(dummyOrder);
  provideDummy<OrderDetail>(OrderDetail(dummyOrder, null));
  provideDummy<UpdateOrderResult>(const UpdateOrderResult(success: false));
  getAndRegisterNavigationService();
  getAndRegisterBottomSheetService();
  getAndRegisterDialogService();
  getAndRegisterHistoryService();
  getAndRegisterGasCylinderService();
  getAndRegisterCustomerService();
  getAndRegisterCartService();
  getAndRegisterConsumptionService();
  getAndRegisterLocationService();
  getAndRegisterNotificationService();
  getAndRegisterTimeSlotService();
  getAndRegisterAppPermissions();
  getAndRegisterOrderTrackingService();
  getAndRegisterClaimService();
  getAndRegisterRatingService();
  getAndRegisterSessionService();
  getAndRegisterPhotoService();
  getAndRegisterProfilePhotoService();
  getAndRegisterOrderDocumentService();
// @stacked-mock-register
}

MockOrderDocumentService getAndRegisterOrderDocumentService() {
  _removeRegistrationIfExists<OrderDocumentService>();
  final service = MockOrderDocumentService();
  locator.registerSingleton<OrderDocumentService>(service);
  return service;
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
  // Por omisión la distribuidora no ofrece modalidades: sólo el reparto común.
  when(service.deliveryOptions(any)).thenAnswer(
      (_) async => const ApiResult<DeliveryOptions>.ok(DeliveryOptions([])));
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
  when(service.cart).thenReturn(Cart.empty);
  when(service.refresh()).thenAnswer((_) async => const ApiResult.ok());
  locator.registerSingleton<CartService>(service);
  return service;
}

MockConsumptionService getAndRegisterConsumptionService() {
  _removeRegistrationIfExists<ConsumptionService>();
  final service = MockConsumptionService();
  locator.registerSingleton<ConsumptionService>(service);
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
  when(service.expressDegradedUpdates)
      .thenAnswer((_) => const Stream<void>.empty());
  locator.registerSingleton<OrderTrackingService>(service);
  return service;
}

MockClaimService getAndRegisterClaimService() {
  _removeRegistrationIfExists<ClaimService>();
  final service = MockClaimService();
  locator.registerSingleton<ClaimService>(service);
  return service;
}

MockRatingService getAndRegisterRatingService() {
  _removeRegistrationIfExists<RatingService>();
  final service = MockRatingService();
  locator.registerSingleton<RatingService>(service);
  return service;
}

MockPhotoService getAndRegisterPhotoService() {
  _removeRegistrationIfExists<PhotoService>();
  final service = MockPhotoService();
  locator.registerSingleton<PhotoService>(service);
  return service;
}

MockProfilePhotoService getAndRegisterProfilePhotoService() {
  _removeRegistrationIfExists<ProfilePhotoService>();
  final service = MockProfilePhotoService();
  locator.registerSingleton<ProfilePhotoService>(service);
  return service;
}

MockSessionService getAndRegisterSessionService() {
  _removeRegistrationIfExists<SessionService>();
  final service = MockSessionService();
  locator.registerSingleton<SessionService>(service);
  return service;
}
