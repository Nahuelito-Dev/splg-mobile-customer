import 'package:jennigas_customer/ui/bottom_sheets/notice/notice_sheet.dart';
import 'package:jennigas_customer/ui/dialogs/info_alert/info_alert_dialog.dart';
import 'package:jennigas_customer/ui/views/home/home_view.dart';
import 'package:jennigas_customer/ui/views/startup/startup_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:jennigas_customer/services/history_service.dart';
import 'package:jennigas_customer/services/gas_cylinder_service.dart';
import 'package:jennigas_customer/services/customer_service.dart';
import 'package:jennigas_customer/services/cart_service.dart';
import 'package:jennigas_customer/ui/views/checkout/checkout_view.dart';
import 'package:jennigas_customer/ui/views/login/login_view.dart';
import 'package:jennigas_customer/ui/views/signup/signup_view.dart';
import 'package:jennigas_customer/ui/views/map/map_view.dart';
import 'package:jennigas_customer/services/location_service.dart';
import 'package:jennigas_customer/ui/bottom_sheets/address_list/address_list_sheet.dart';
import 'package:jennigas_customer/ui/views/profile/profile_view.dart';
import 'package:jennigas_customer/ui/views/order_tracking/order_tracking_view.dart';
import 'package:jennigas_customer/services/order_tracking_service.dart';
import 'package:jennigas_customer/services/time_slot_service.dart';
import 'package:jennigas_customer/services/rating_service.dart';
import 'package:jennigas_customer/services/claim_service.dart';
import 'package:jennigas_customer/ui/bottom_sheets/rate_driver/rate_driver_sheet.dart';
import 'package:jennigas_customer/ui/bottom_sheets/claim/claim_sheet.dart';
import 'package:jennigas_customer/ui/views/qr_scan/qr_scan_view.dart';
// @stacked-import

@StackedApp(
  routes: [
    MaterialRoute(page: HomeView),
    MaterialRoute(page: StartupView),
    MaterialRoute(page: CheckoutView),
    MaterialRoute(page: LoginView),
    MaterialRoute(page: SignupView),
    MaterialRoute(page: MapView),
    MaterialRoute(page: ProfileView),
    MaterialRoute(page: OrderTrackingView),
    MaterialRoute(page: QrScanView),
// @stacked-route
  ],
  dependencies: [
    LazySingleton(classType: BottomSheetService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: HistoryService),
    LazySingleton(classType: GasCylinderService),
    LazySingleton(classType: CustomerService),
    LazySingleton(classType: CartService),
    LazySingleton(classType: LocationService),
    LazySingleton(classType: OrderTrackingService),
    LazySingleton(classType: TimeSlotService),
    LazySingleton(classType: RatingService),
    LazySingleton(classType: ClaimService),
// @stacked-service
  ],
  bottomsheets: [
    StackedBottomsheet(classType: NoticeSheet),
    StackedBottomsheet(classType: AddressListSheet),
    StackedBottomsheet(classType: RateDriverSheet),
    StackedBottomsheet(classType: ClaimSheet),
// @stacked-bottom-sheet
  ],
  dialogs: [
    StackedDialog(classType: InfoAlertDialog),
    // @stacked-dialog
  ],
)
class App {}
