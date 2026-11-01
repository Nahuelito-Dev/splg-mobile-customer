import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/payment_term.dart';
import 'package:splg_customer/domain/pricing.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/widgets/signed_image.dart';

/// Detalle de una garrafa: imagen, precio, promociones con el precio unitario
/// por tramo, métodos de pago y botón para agregar.
class CylinderDetailSheet extends StatefulWidget {
  const CylinderDetailSheet({
    super.key,
    required this.cylinder,
    required this.onAdd,
    this.photoUrl,
  });

  final GasCylinder cylinder;
  final VoidCallback onAdd;

  /// Foto firmada del back; sin ella (o vencida) va el asset.
  final String? photoUrl;

  @override
  State<CylinderDetailSheet> createState() => _CylinderDetailSheetState();
}

class _CylinderDetailSheetState extends State<CylinderDetailSheet> {
  /// Los recargos vigentes por medio de pago; hasta que el back responde (o si
  /// no responde) no se menciona ninguno.
  List<PaymentTerm> _terms = const [];

  GasCylinder get cylinder => widget.cylinder;
  VoidCallback get onAdd => widget.onAdd;
  String? get photoUrl => widget.photoUrl;

  @override
  void initState() {
    super.initState();
    locator<GasCylinderService>().paymentTerms().then((terms) {
      if (mounted) setState(() => _terms = terms);
    });
  }

  String _payNote(String key, String base) {
    final term = PaymentTerm.of(_terms, key);
    return term != null && term.hasSurcharge
        ? 'Recargo del ${term.percentageLabel}'
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final discounts = Pricing.sortedDiscounts(cylinder);

    Widget pay(IconData icon, String title, String subtitle) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: brasa.primaryStrong),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: type.value),
                    Text(subtitle, style: type.caption),
                  ],
                ),
              ),
            ],
          ),
        );

    return SplgBottomPanel(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: SignedImage(
                    url: photoUrl,
                    height: 130,
                    fallback: Image.asset('assets/cylinder_10.png',
                        height: 130, fit: BoxFit.contain))),
            const SizedBox(height: 12),
            Text(cylinder.label, style: type.heading),
            Text('${cylinder.weight} kg', style: type.caption),
            const SizedBox(height: 6),
            Text(money.format(cylinder.price),
                style: type.title.copyWith(color: brasa.ink2)),
            if (cylinder.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(cylinder.description, style: type.body),
            ],
            if (discounts.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Promociones por cantidad', style: type.subtitle),
              const SizedBox(height: 8),
              for (final d in discounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SplgStatusBadge(
                          label: '−${d.percentage.toStringAsFixed(0)}%',
                          tone: SplgTone.warn),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.unitPrice == null
                              ? 'Llevando ${d.quantity} o más'
                              : 'Llevando ${d.quantity} o más: '
                                  '${money.format(d.unitPrice!)} c/u',
                          style: type.body,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text('Métodos de pago', style: type.subtitle),
            const SizedBox(height: 10),
            pay(SplgIcons.cash, 'Efectivo',
                _payNote('CASH', 'Pagás al recibir el pedido')),
            pay(SplgIcons.bank, 'Transferencia',
                _payNote('TRANSFER', 'Pagás por transferencia bancaria')),
            pay(SplgIcons.card, 'Mercado Pago',
                _payNote('MERCADOPAGO', 'Tarjeta de crédito o débito')),
            const SizedBox(height: 16),
            SplgButton(
              title: 'Agregar al pedido',
              onPressed: () {
                onAdd();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
