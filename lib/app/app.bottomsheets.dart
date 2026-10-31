// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedBottomsheetGenerator
// **************************************************************************

import 'package:stacked_services/stacked_services.dart';

import 'app.locator.dart';
import '../ui/bottom_sheets/address_list/address_list_sheet.dart';
import '../ui/bottom_sheets/claim/claim_sheet.dart';
import '../ui/bottom_sheets/delivery_code/delivery_code_sheet.dart';
import '../ui/bottom_sheets/notice/notice_sheet.dart';
import '../ui/bottom_sheets/rate_driver/rate_driver_sheet.dart';
import '../ui/bottom_sheets/receiver/receiver_sheet.dart';

enum BottomSheetType {
  notice,
  addressList,
  rateDriver,
  claim,
  receiver,
  deliveryCode,
}

void setupBottomSheetUi() {
  final bottomsheetService = locator<BottomSheetService>();

  final Map<BottomSheetType, SheetBuilder> builders = {
    BottomSheetType.notice: (context, request, completer) =>
        NoticeSheet(request: request, completer: completer),
    BottomSheetType.addressList: (context, request, completer) =>
        AddressListSheet(request: request, completer: completer),
    BottomSheetType.rateDriver: (context, request, completer) =>
        RateDriverSheet(request: request, completer: completer),
    BottomSheetType.claim: (context, request, completer) =>
        ClaimSheet(request: request, completer: completer),
    BottomSheetType.receiver: (context, request, completer) =>
        ReceiverSheet(request: request, completer: completer),
    BottomSheetType.deliveryCode: (context, request, completer) =>
        DeliveryCodeSheet(request: request, completer: completer),
  };

  bottomsheetService.setCustomSheetBuilders(builders);
}
