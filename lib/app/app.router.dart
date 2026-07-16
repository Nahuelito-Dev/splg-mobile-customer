// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedNavigatorGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter/material.dart' as _i13;
import 'package:flutter/material.dart';
import 'package:jennigas_customer/ui/views/addresses/addresses_view.dart'
    as _i9;
import 'package:jennigas_customer/ui/views/checkout/checkout_view.dart' as _i4;
import 'package:jennigas_customer/ui/views/home/home_view.dart' as _i2;
import 'package:jennigas_customer/ui/views/legal/legal_view.dart' as _i12;
import 'package:jennigas_customer/ui/views/login/login_view.dart' as _i5;
import 'package:jennigas_customer/ui/views/map/map_view.dart' as _i7;
import 'package:jennigas_customer/ui/views/order_tracking/order_tracking_view.dart'
    as _i10;
import 'package:jennigas_customer/ui/views/profile/profile_view.dart' as _i8;
import 'package:jennigas_customer/ui/views/qr_scan/qr_scan_view.dart' as _i11;
import 'package:jennigas_customer/ui/views/signup/signup_view.dart' as _i6;
import 'package:jennigas_customer/ui/views/startup/startup_view.dart' as _i3;
import 'package:stacked/stacked.dart' as _i1;
import 'package:stacked_services/stacked_services.dart' as _i14;

class Routes {
  static const homeView = '/home-view';

  static const startupView = '/startup-view';

  static const checkoutView = '/checkout-view';

  static const loginView = '/login-view';

  static const signupView = '/signup-view';

  static const mapView = '/map-view';

  static const profileView = '/profile-view';

  static const addressesView = '/addresses-view';

  static const orderTrackingView = '/order-tracking-view';

  static const qrScanView = '/qr-scan-view';

  static const legalView = '/legal-view';

  static const all = <String>{
    homeView,
    startupView,
    checkoutView,
    loginView,
    signupView,
    mapView,
    profileView,
    addressesView,
    orderTrackingView,
    qrScanView,
    legalView,
  };
}

class StackedRouter extends _i1.RouterBase {
  final _routes = <_i1.RouteDef>[
    _i1.RouteDef(Routes.homeView, page: _i2.HomeView),
    _i1.RouteDef(Routes.startupView, page: _i3.StartupView),
    _i1.RouteDef(Routes.checkoutView, page: _i4.CheckoutView),
    _i1.RouteDef(Routes.loginView, page: _i5.LoginView),
    _i1.RouteDef(Routes.signupView, page: _i6.SignupView),
    _i1.RouteDef(Routes.mapView, page: _i7.MapView),
    _i1.RouteDef(Routes.profileView, page: _i8.ProfileView),
    _i1.RouteDef(Routes.addressesView, page: _i9.AddressesView),
    _i1.RouteDef(Routes.orderTrackingView, page: _i10.OrderTrackingView),
    _i1.RouteDef(Routes.qrScanView, page: _i11.QrScanView),
    _i1.RouteDef(Routes.legalView, page: _i12.LegalView),
  ];

  final _pagesMap = <Type, _i1.StackedRouteFactory>{
    _i2.HomeView: (data) {
      final args = data.getArgs<HomeViewArguments>(
        orElse: () => const HomeViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i2.HomeView(key: args.key),
        settings: data,
      );
    },
    _i3.StartupView: (data) {
      final args = data.getArgs<StartupViewArguments>(
        orElse: () => const StartupViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i3.StartupView(key: args.key),
        settings: data,
      );
    },
    _i4.CheckoutView: (data) {
      final args = data.getArgs<CheckoutViewArguments>(
        orElse: () => const CheckoutViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i4.CheckoutView(key: args.key),
        settings: data,
      );
    },
    _i5.LoginView: (data) {
      final args = data.getArgs<LoginViewArguments>(
        orElse: () => const LoginViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i5.LoginView(key: args.key),
        settings: data,
      );
    },
    _i6.SignupView: (data) {
      final args = data.getArgs<SignupViewArguments>(
        orElse: () => const SignupViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i6.SignupView(key: args.key),
        settings: data,
      );
    },
    _i7.MapView: (data) {
      final args = data.getArgs<MapViewArguments>(
        orElse: () => const MapViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i7.MapView(key: args.key),
        settings: data,
      );
    },
    _i8.ProfileView: (data) {
      final args = data.getArgs<ProfileViewArguments>(
        orElse: () => const ProfileViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i8.ProfileView(key: args.key),
        settings: data,
      );
    },
    _i9.AddressesView: (data) {
      final args = data.getArgs<AddressesViewArguments>(
        orElse: () => const AddressesViewArguments(),
      );
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) => _i9.AddressesView(key: args.key),
        settings: data,
      );
    },
    _i10.OrderTrackingView: (data) {
      final args = data.getArgs<OrderTrackingViewArguments>(nullOk: false);
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i10.OrderTrackingView(key: args.key, orderId: args.orderId),
        settings: data,
      );
    },
    _i11.QrScanView: (data) {
      final args = data.getArgs<QrScanViewArguments>(nullOk: false);
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i11.QrScanView(key: args.key, orderId: args.orderId),
        settings: data,
      );
    },
    _i12.LegalView: (data) {
      final args = data.getArgs<LegalViewArguments>(nullOk: false);
      return _i13.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i12.LegalView(key: args.key, document: args.document),
        settings: data,
      );
    },
  };

  @override
  List<_i1.RouteDef> get routes => _routes;

  @override
  Map<Type, _i1.StackedRouteFactory> get pagesMap => _pagesMap;
}

class HomeViewArguments {
  const HomeViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant HomeViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class StartupViewArguments {
  const StartupViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant StartupViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class CheckoutViewArguments {
  const CheckoutViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant CheckoutViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class LoginViewArguments {
  const LoginViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant LoginViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class SignupViewArguments {
  const SignupViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant SignupViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class MapViewArguments {
  const MapViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant MapViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ProfileViewArguments {
  const ProfileViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ProfileViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class AddressesViewArguments {
  const AddressesViewArguments({this.key});

  final _i13.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant AddressesViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class OrderTrackingViewArguments {
  const OrderTrackingViewArguments({this.key, required this.orderId});

  final _i13.Key? key;

  final String orderId;

  @override
  String toString() {
    return '{"key": "$key", "orderId": "$orderId"}';
  }

  @override
  bool operator ==(covariant OrderTrackingViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.orderId == orderId;
  }

  @override
  int get hashCode {
    return key.hashCode ^ orderId.hashCode;
  }
}

class QrScanViewArguments {
  const QrScanViewArguments({this.key, required this.orderId});

  final _i13.Key? key;

  final String orderId;

  @override
  String toString() {
    return '{"key": "$key", "orderId": "$orderId"}';
  }

  @override
  bool operator ==(covariant QrScanViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.orderId == orderId;
  }

  @override
  int get hashCode {
    return key.hashCode ^ orderId.hashCode;
  }
}

class LegalViewArguments {
  const LegalViewArguments({this.key, required this.document});

  final _i13.Key? key;

  final _i12.LegalDocument document;

  @override
  String toString() {
    return '{"key": "$key", "document": "$document"}';
  }

  @override
  bool operator ==(covariant LegalViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.document == document;
  }

  @override
  int get hashCode {
    return key.hashCode ^ document.hashCode;
  }
}

extension NavigatorStateExtension on _i14.NavigationService {
  Future<dynamic> navigateToHomeView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.homeView,
      arguments: HomeViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToStartupView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.startupView,
      arguments: StartupViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToCheckoutView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.checkoutView,
      arguments: CheckoutViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToLoginView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.loginView,
      arguments: LoginViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToSignupView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.signupView,
      arguments: SignupViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToMapView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.mapView,
      arguments: MapViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToProfileView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.profileView,
      arguments: ProfileViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToAddressesView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.addressesView,
      arguments: AddressesViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToOrderTrackingView({
    _i13.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.orderTrackingView,
      arguments: OrderTrackingViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToQrScanView({
    _i13.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.qrScanView,
      arguments: QrScanViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToLegalView({
    _i13.Key? key,
    required _i12.LegalDocument document,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.legalView,
      arguments: LegalViewArguments(key: key, document: document),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithHomeView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.homeView,
      arguments: HomeViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithStartupView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.startupView,
      arguments: StartupViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithCheckoutView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.checkoutView,
      arguments: CheckoutViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithLoginView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.loginView,
      arguments: LoginViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithSignupView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.signupView,
      arguments: SignupViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithMapView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.mapView,
      arguments: MapViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithProfileView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.profileView,
      arguments: ProfileViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithAddressesView({
    _i13.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.addressesView,
      arguments: AddressesViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithOrderTrackingView({
    _i13.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.orderTrackingView,
      arguments: OrderTrackingViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithQrScanView({
    _i13.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.qrScanView,
      arguments: QrScanViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithLegalView({
    _i13.Key? key,
    required _i12.LegalDocument document,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.legalView,
      arguments: LegalViewArguments(key: key, document: document),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }
}
