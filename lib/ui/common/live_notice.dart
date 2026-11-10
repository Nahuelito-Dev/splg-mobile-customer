import 'package:splg_customer/services/order_tracking_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';

/// Texto para el cliente de un aviso en vivo del pedido.
extension OrderLiveEventText on OrderLiveEvent {
  String get notice => switch (kind) {
        OrderLiveEventKind.paymentApproved => isDeposit
            ? 'Recibimos la seña de tu reserva. Se activa el día de la entrega.'
            : 'Recibimos tu pago.',
        OrderLiveEventKind.paymentRefunded => amount == null
            ? 'Te devolvimos el pago.'
            : 'Te devolvimos ${money.format(amount!)}.',
        OrderLiveEventKind.updated => totalAmount == null
            ? 'Tu pedido se modificó.'
            : previousTotalAmount == null
                ? 'Tu pedido se modificó: el total ahora es '
                    '${money.format(totalAmount!)}.'
                : 'Tu pedido se modificó: el total pasó de '
                    '${money.format(previousTotalAmount!)} a '
                    '${money.format(totalAmount!)}.',
      };
}
