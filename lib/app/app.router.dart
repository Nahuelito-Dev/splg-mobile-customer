// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedNavigatorGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as _i30;
import 'package:splg_customer/domain/my_claim.dart' as _i33;
import 'package:splg_customer/domain/order_breakdown.dart' as _i32;
import 'package:splg_customer/ui/views/about/about_view.dart' as _i26;
import 'package:splg_customer/ui/views/address_form/address_form_view.dart'
    as _i21;
import 'package:splg_customer/ui/views/addresses/addresses_view.dart' as _i9;
import 'package:splg_customer/ui/views/cancel_order/cancel_order_view.dart'
    as _i19;
import 'package:splg_customer/ui/views/change_password/change_password_view.dart'
    as _i29;
import 'package:splg_customer/ui/views/checkout/checkout_view.dart' as _i4;
import 'package:splg_customer/ui/views/claim_detail/claim_detail_view.dart'
    as _i23;
import 'package:splg_customer/ui/views/claims/claims_view.dart' as _i22;
import 'package:splg_customer/ui/views/edit_order/edit_order_view.dart' as _i20;
import 'package:splg_customer/ui/views/edit_profile/edit_profile_view.dart'
    as _i28;
import 'package:splg_customer/ui/views/help/help_view.dart' as _i25;
import 'package:splg_customer/ui/views/home/home_view.dart' as _i2;
import 'package:splg_customer/ui/views/legal/legal_view.dart' as _i12;
import 'package:splg_customer/ui/views/login/login_view.dart' as _i5;
import 'package:splg_customer/ui/views/map/map_view.dart' as _i7;
import 'package:splg_customer/ui/views/notifications/notifications_view.dart'
    as _i24;
import 'package:splg_customer/ui/views/order_detail/order_detail_view.dart'
    as _i18;
import 'package:splg_customer/ui/views/order_tracking/order_tracking_view.dart'
    as _i10;
import 'package:splg_customer/ui/views/orders/orders_view.dart' as _i17;
import 'package:splg_customer/ui/views/payment_webview/payment_webview_view.dart'
    as _i13;
import 'package:splg_customer/ui/views/personal_info/personal_info_view.dart'
    as _i27;
import 'package:splg_customer/ui/views/profile/profile_view.dart' as _i8;
import 'package:splg_customer/ui/views/qr_scan/qr_scan_view.dart' as _i11;
import 'package:splg_customer/ui/views/recover_password/recover_password_view.dart'
    as _i15;
import 'package:splg_customer/ui/views/signup/signup_view.dart' as _i6;
import 'package:splg_customer/ui/views/signup_done/signup_done_view.dart'
    as _i16;
import 'package:splg_customer/ui/views/startup/startup_view.dart' as _i3;
import 'package:splg_customer/ui/views/welcome/welcome_view.dart' as _i14;
import 'package:splg_lib/splg_lib.dart' as _i31;
import 'package:stacked/stacked.dart' as _i1;
import 'package:stacked_services/stacked_services.dart' as _i34;

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

  static const paymentWebViewView = '/payment-web-view-view';

  static const welcomeView = '/welcome-view';

  static const recoverPasswordView = '/recover-password-view';

  static const signupDoneView = '/signup-done-view';

  static const ordersView = '/orders-view';

  static const orderDetailView = '/order-detail-view';

  static const cancelOrderView = '/cancel-order-view';

  static const editOrderView = '/edit-order-view';

  static const addressFormView = '/address-form-view';

  static const claimsView = '/claims-view';

  static const claimDetailView = '/claim-detail-view';

  static const notificationsView = '/notifications-view';

  static const helpView = '/help-view';

  static const aboutView = '/about-view';

  static const personalInfoView = '/personal-info-view';

  static const editProfileView = '/edit-profile-view';

  static const changePasswordView = '/change-password-view';

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
    paymentWebViewView,
    welcomeView,
    recoverPasswordView,
    signupDoneView,
    ordersView,
    orderDetailView,
    cancelOrderView,
    editOrderView,
    addressFormView,
    claimsView,
    claimDetailView,
    notificationsView,
    helpView,
    aboutView,
    personalInfoView,
    editProfileView,
    changePasswordView,
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
    _i1.RouteDef(Routes.paymentWebViewView, page: _i13.PaymentWebViewView),
    _i1.RouteDef(Routes.welcomeView, page: _i14.WelcomeView),
    _i1.RouteDef(Routes.recoverPasswordView, page: _i15.RecoverPasswordView),
    _i1.RouteDef(Routes.signupDoneView, page: _i16.SignupDoneView),
    _i1.RouteDef(Routes.ordersView, page: _i17.OrdersView),
    _i1.RouteDef(Routes.orderDetailView, page: _i18.OrderDetailView),
    _i1.RouteDef(Routes.cancelOrderView, page: _i19.CancelOrderView),
    _i1.RouteDef(Routes.editOrderView, page: _i20.EditOrderView),
    _i1.RouteDef(Routes.addressFormView, page: _i21.AddressFormView),
    _i1.RouteDef(Routes.claimsView, page: _i22.ClaimsView),
    _i1.RouteDef(Routes.claimDetailView, page: _i23.ClaimDetailView),
    _i1.RouteDef(Routes.notificationsView, page: _i24.NotificationsView),
    _i1.RouteDef(Routes.helpView, page: _i25.HelpView),
    _i1.RouteDef(Routes.aboutView, page: _i26.AboutView),
    _i1.RouteDef(Routes.personalInfoView, page: _i27.PersonalInfoView),
    _i1.RouteDef(Routes.editProfileView, page: _i28.EditProfileView),
    _i1.RouteDef(Routes.changePasswordView, page: _i29.ChangePasswordView),
  ];

  final _pagesMap = <Type, _i1.StackedRouteFactory>{
    _i2.HomeView: (data) {
      final args = data.getArgs<HomeViewArguments>(
        orElse: () => const HomeViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i2.HomeView(key: args.key),
        settings: data,
      );
    },
    _i3.StartupView: (data) {
      final args = data.getArgs<StartupViewArguments>(
        orElse: () => const StartupViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i3.StartupView(key: args.key),
        settings: data,
      );
    },
    _i4.CheckoutView: (data) {
      final args = data.getArgs<CheckoutViewArguments>(
        orElse: () => const CheckoutViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i4.CheckoutView(key: args.key),
        settings: data,
      );
    },
    _i5.LoginView: (data) {
      final args = data.getArgs<LoginViewArguments>(
        orElse: () => const LoginViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i5.LoginView(key: args.key),
        settings: data,
      );
    },
    _i6.SignupView: (data) {
      final args = data.getArgs<SignupViewArguments>(
        orElse: () => const SignupViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i6.SignupView(key: args.key),
        settings: data,
      );
    },
    _i7.MapView: (data) {
      final args = data.getArgs<MapViewArguments>(
        orElse: () => const MapViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i7.MapView(key: args.key),
        settings: data,
      );
    },
    _i8.ProfileView: (data) {
      final args = data.getArgs<ProfileViewArguments>(
        orElse: () => const ProfileViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i8.ProfileView(key: args.key),
        settings: data,
      );
    },
    _i9.AddressesView: (data) {
      final args = data.getArgs<AddressesViewArguments>(
        orElse: () => const AddressesViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i9.AddressesView(key: args.key),
        settings: data,
      );
    },
    _i10.OrderTrackingView: (data) {
      final args = data.getArgs<OrderTrackingViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i10.OrderTrackingView(key: args.key, orderId: args.orderId),
        settings: data,
      );
    },
    _i11.QrScanView: (data) {
      final args = data.getArgs<QrScanViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i11.QrScanView(key: args.key, orderId: args.orderId),
        settings: data,
      );
    },
    _i12.LegalView: (data) {
      final args = data.getArgs<LegalViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i12.LegalView(key: args.key, document: args.document),
        settings: data,
      );
    },
    _i13.PaymentWebViewView: (data) {
      final args = data.getArgs<PaymentWebViewViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i13.PaymentWebViewView(key: args.key, paymentUrl: args.paymentUrl),
        settings: data,
      );
    },
    _i14.WelcomeView: (data) {
      final args = data.getArgs<WelcomeViewArguments>(
        orElse: () => const WelcomeViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i14.WelcomeView(key: args.key),
        settings: data,
      );
    },
    _i15.RecoverPasswordView: (data) {
      final args = data.getArgs<RecoverPasswordViewArguments>(
        orElse: () => const RecoverPasswordViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i15.RecoverPasswordView(key: args.key, email: args.email),
        settings: data,
      );
    },
    _i16.SignupDoneView: (data) {
      final args = data.getArgs<SignupDoneViewArguments>(
        orElse: () => const SignupDoneViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i16.SignupDoneView(key: args.key),
        settings: data,
      );
    },
    _i17.OrdersView: (data) {
      final args = data.getArgs<OrdersViewArguments>(
        orElse: () => const OrdersViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i17.OrdersView(key: args.key),
        settings: data,
      );
    },
    _i18.OrderDetailView: (data) {
      final args = data.getArgs<OrderDetailViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i18.OrderDetailView(
          key: args.key,
          orderId: args.orderId,
          order: args.order,
        ),
        settings: data,
      );
    },
    _i19.CancelOrderView: (data) {
      final args = data.getArgs<CancelOrderViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i19.CancelOrderView(key: args.key, orderId: args.orderId),
        settings: data,
      );
    },
    _i20.EditOrderView: (data) {
      final args = data.getArgs<EditOrderViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i20.EditOrderView(
          key: args.key,
          order: args.order,
          breakdown: args.breakdown,
        ),
        settings: data,
      );
    },
    _i21.AddressFormView: (data) {
      final args = data.getArgs<AddressFormViewArguments>(
        orElse: () => const AddressFormViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i21.AddressFormView(key: args.key, address: args.address),
        settings: data,
      );
    },
    _i22.ClaimsView: (data) {
      final args = data.getArgs<ClaimsViewArguments>(
        orElse: () => const ClaimsViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i22.ClaimsView(key: args.key),
        settings: data,
      );
    },
    _i23.ClaimDetailView: (data) {
      final args = data.getArgs<ClaimDetailViewArguments>(nullOk: false);
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) =>
            _i23.ClaimDetailView(key: args.key, claim: args.claim),
        settings: data,
      );
    },
    _i24.NotificationsView: (data) {
      final args = data.getArgs<NotificationsViewArguments>(
        orElse: () => const NotificationsViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i24.NotificationsView(key: args.key),
        settings: data,
      );
    },
    _i25.HelpView: (data) {
      final args = data.getArgs<HelpViewArguments>(
        orElse: () => const HelpViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i25.HelpView(key: args.key),
        settings: data,
      );
    },
    _i26.AboutView: (data) {
      final args = data.getArgs<AboutViewArguments>(
        orElse: () => const AboutViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i26.AboutView(key: args.key),
        settings: data,
      );
    },
    _i27.PersonalInfoView: (data) {
      final args = data.getArgs<PersonalInfoViewArguments>(
        orElse: () => const PersonalInfoViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i27.PersonalInfoView(key: args.key),
        settings: data,
      );
    },
    _i28.EditProfileView: (data) {
      final args = data.getArgs<EditProfileViewArguments>(
        orElse: () => const EditProfileViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i28.EditProfileView(key: args.key),
        settings: data,
      );
    },
    _i29.ChangePasswordView: (data) {
      final args = data.getArgs<ChangePasswordViewArguments>(
        orElse: () => const ChangePasswordViewArguments(),
      );
      return _i30.MaterialPageRoute<dynamic>(
        builder: (context) => _i29.ChangePasswordView(key: args.key),
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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

  final _i30.Key? key;

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

class PaymentWebViewViewArguments {
  const PaymentWebViewViewArguments({this.key, required this.paymentUrl});

  final _i30.Key? key;

  final String paymentUrl;

  @override
  String toString() {
    return '{"key": "$key", "paymentUrl": "$paymentUrl"}';
  }

  @override
  bool operator ==(covariant PaymentWebViewViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.paymentUrl == paymentUrl;
  }

  @override
  int get hashCode {
    return key.hashCode ^ paymentUrl.hashCode;
  }
}

class WelcomeViewArguments {
  const WelcomeViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant WelcomeViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class RecoverPasswordViewArguments {
  const RecoverPasswordViewArguments({this.key, this.email});

  final _i30.Key? key;

  final String? email;

  @override
  String toString() {
    return '{"key": "$key", "email": "$email"}';
  }

  @override
  bool operator ==(covariant RecoverPasswordViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.email == email;
  }

  @override
  int get hashCode {
    return key.hashCode ^ email.hashCode;
  }
}

class SignupDoneViewArguments {
  const SignupDoneViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant SignupDoneViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class OrdersViewArguments {
  const OrdersViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant OrdersViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class OrderDetailViewArguments {
  const OrderDetailViewArguments({this.key, required this.orderId, this.order});

  final _i30.Key? key;

  final String orderId;

  final _i31.Order? order;

  @override
  String toString() {
    return '{"key": "$key", "orderId": "$orderId", "order": "$order"}';
  }

  @override
  bool operator ==(covariant OrderDetailViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.orderId == orderId && other.order == order;
  }

  @override
  int get hashCode {
    return key.hashCode ^ orderId.hashCode ^ order.hashCode;
  }
}

class CancelOrderViewArguments {
  const CancelOrderViewArguments({this.key, required this.orderId});

  final _i30.Key? key;

  final String orderId;

  @override
  String toString() {
    return '{"key": "$key", "orderId": "$orderId"}';
  }

  @override
  bool operator ==(covariant CancelOrderViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.orderId == orderId;
  }

  @override
  int get hashCode {
    return key.hashCode ^ orderId.hashCode;
  }
}

class EditOrderViewArguments {
  const EditOrderViewArguments({this.key, required this.order, this.breakdown});

  final _i30.Key? key;

  final _i31.Order order;

  final _i32.OrderBreakdown? breakdown;

  @override
  String toString() {
    return '{"key": "$key", "order": "$order", "breakdown": "$breakdown"}';
  }

  @override
  bool operator ==(covariant EditOrderViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key &&
        other.order == order &&
        other.breakdown == breakdown;
  }

  @override
  int get hashCode {
    return key.hashCode ^ order.hashCode ^ breakdown.hashCode;
  }
}

class AddressFormViewArguments {
  const AddressFormViewArguments({this.key, this.address});

  final _i30.Key? key;

  final _i31.Address? address;

  @override
  String toString() {
    return '{"key": "$key", "address": "$address"}';
  }

  @override
  bool operator ==(covariant AddressFormViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.address == address;
  }

  @override
  int get hashCode {
    return key.hashCode ^ address.hashCode;
  }
}

class ClaimsViewArguments {
  const ClaimsViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ClaimsViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ClaimDetailViewArguments {
  const ClaimDetailViewArguments({this.key, required this.claim});

  final _i30.Key? key;

  final _i33.MyClaim claim;

  @override
  String toString() {
    return '{"key": "$key", "claim": "$claim"}';
  }

  @override
  bool operator ==(covariant ClaimDetailViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key && other.claim == claim;
  }

  @override
  int get hashCode {
    return key.hashCode ^ claim.hashCode;
  }
}

class NotificationsViewArguments {
  const NotificationsViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant NotificationsViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class HelpViewArguments {
  const HelpViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant HelpViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class AboutViewArguments {
  const AboutViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant AboutViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class PersonalInfoViewArguments {
  const PersonalInfoViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant PersonalInfoViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class EditProfileViewArguments {
  const EditProfileViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant EditProfileViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

class ChangePasswordViewArguments {
  const ChangePasswordViewArguments({this.key});

  final _i30.Key? key;

  @override
  String toString() {
    return '{"key": "$key"}';
  }

  @override
  bool operator ==(covariant ChangePasswordViewArguments other) {
    if (identical(this, other)) return true;
    return other.key == key;
  }

  @override
  int get hashCode {
    return key.hashCode;
  }
}

extension NavigatorStateExtension on _i34.NavigationService {
  Future<dynamic> navigateToHomeView({
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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

  Future<dynamic> navigateToPaymentWebViewView({
    _i30.Key? key,
    required String paymentUrl,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.paymentWebViewView,
      arguments: PaymentWebViewViewArguments(key: key, paymentUrl: paymentUrl),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToWelcomeView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.welcomeView,
      arguments: WelcomeViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToRecoverPasswordView({
    _i30.Key? key,
    String? email,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.recoverPasswordView,
      arguments: RecoverPasswordViewArguments(key: key, email: email),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToSignupDoneView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.signupDoneView,
      arguments: SignupDoneViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToOrdersView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.ordersView,
      arguments: OrdersViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToOrderDetailView({
    _i30.Key? key,
    required String orderId,
    _i31.Order? order,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.orderDetailView,
      arguments: OrderDetailViewArguments(
        key: key,
        orderId: orderId,
        order: order,
      ),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToCancelOrderView({
    _i30.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.cancelOrderView,
      arguments: CancelOrderViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToEditOrderView({
    _i30.Key? key,
    required _i31.Order order,
    _i32.OrderBreakdown? breakdown,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.editOrderView,
      arguments: EditOrderViewArguments(
        key: key,
        order: order,
        breakdown: breakdown,
      ),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToAddressFormView({
    _i30.Key? key,
    _i31.Address? address,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.addressFormView,
      arguments: AddressFormViewArguments(key: key, address: address),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToClaimsView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.claimsView,
      arguments: ClaimsViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToClaimDetailView({
    _i30.Key? key,
    required _i33.MyClaim claim,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.claimDetailView,
      arguments: ClaimDetailViewArguments(key: key, claim: claim),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToNotificationsView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.notificationsView,
      arguments: NotificationsViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToHelpView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.helpView,
      arguments: HelpViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToAboutView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.aboutView,
      arguments: AboutViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToPersonalInfoView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.personalInfoView,
      arguments: PersonalInfoViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToEditProfileView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.editProfileView,
      arguments: EditProfileViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> navigateToChangePasswordView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return navigateTo<dynamic>(
      Routes.changePasswordView,
      arguments: ChangePasswordViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithHomeView({
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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
    _i30.Key? key,
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

  Future<dynamic> replaceWithPaymentWebViewView({
    _i30.Key? key,
    required String paymentUrl,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.paymentWebViewView,
      arguments: PaymentWebViewViewArguments(key: key, paymentUrl: paymentUrl),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithWelcomeView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.welcomeView,
      arguments: WelcomeViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithRecoverPasswordView({
    _i30.Key? key,
    String? email,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.recoverPasswordView,
      arguments: RecoverPasswordViewArguments(key: key, email: email),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithSignupDoneView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.signupDoneView,
      arguments: SignupDoneViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithOrdersView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.ordersView,
      arguments: OrdersViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithOrderDetailView({
    _i30.Key? key,
    required String orderId,
    _i31.Order? order,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.orderDetailView,
      arguments: OrderDetailViewArguments(
        key: key,
        orderId: orderId,
        order: order,
      ),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithCancelOrderView({
    _i30.Key? key,
    required String orderId,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.cancelOrderView,
      arguments: CancelOrderViewArguments(key: key, orderId: orderId),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithEditOrderView({
    _i30.Key? key,
    required _i31.Order order,
    _i32.OrderBreakdown? breakdown,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.editOrderView,
      arguments: EditOrderViewArguments(
        key: key,
        order: order,
        breakdown: breakdown,
      ),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithAddressFormView({
    _i30.Key? key,
    _i31.Address? address,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.addressFormView,
      arguments: AddressFormViewArguments(key: key, address: address),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithClaimsView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.claimsView,
      arguments: ClaimsViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithClaimDetailView({
    _i30.Key? key,
    required _i33.MyClaim claim,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.claimDetailView,
      arguments: ClaimDetailViewArguments(key: key, claim: claim),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithNotificationsView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.notificationsView,
      arguments: NotificationsViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithHelpView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.helpView,
      arguments: HelpViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithAboutView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.aboutView,
      arguments: AboutViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithPersonalInfoView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.personalInfoView,
      arguments: PersonalInfoViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithEditProfileView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.editProfileView,
      arguments: EditProfileViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }

  Future<dynamic> replaceWithChangePasswordView({
    _i30.Key? key,
    int? routerId,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)?
        transition,
  }) async {
    return replaceWith<dynamic>(
      Routes.changePasswordView,
      arguments: ChangePasswordViewArguments(key: key),
      id: routerId,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
      transition: transition,
    );
  }
}
