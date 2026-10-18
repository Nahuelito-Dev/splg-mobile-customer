import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/order_receiver.dart';
import 'package:splg_customer/services/history_service.dart';

/// Formulario de quién recibe el pedido (CU-128). Con [orderId] lo guarda en el
/// pedido (`PATCH /orders/:id/receiver`) y muestra el rechazo del back en la
/// misma hoja; sin él sólo valida y devuelve el receptor (para el alta).
class ReceiverSheetModel extends BaseViewModel {
  ReceiverSheetModel({this.orderId, OrderReceiver? initial}) {
    nameController.text = initial?.name ?? '';
    documentController.text = initial?.document ?? '';
    relationshipController.text = initial?.relationship ?? '';
  }

  final String? orderId;

  final nameController = TextEditingController();
  final documentController = TextEditingController();
  final relationshipController = TextEditingController();

  String? errorMessage;

  /// El receptor que quedó guardado o validado; null si todavía no.
  OrderReceiver? result;

  /// Valida y, con pedido, guarda. Devuelve si se pudo.
  Future<bool> submit() async {
    if (isBusy) return false;
    final parsed = OrderReceiver.parse(
      name: nameController.text,
      document: documentController.text,
      relationship: relationshipController.text,
    );
    final receiver = parsed.receiver;
    if (receiver == null) {
      errorMessage = parsed.error;
      notifyListeners();
      return false;
    }
    final id = orderId;
    if (id != null) {
      setBusy(true);
      errorMessage = null;
      final saved =
          await locator<HistoryService>().setOrderReceiver(id, receiver);
      setBusy(false);
      if (!saved.success) {
        errorMessage = saved.message;
        notifyListeners();
        return false;
      }
    }
    errorMessage = null;
    result = receiver;
    return true;
  }

  @override
  void dispose() {
    nameController.dispose();
    documentController.dispose();
    relationshipController.dispose();
    super.dispose();
  }
}
