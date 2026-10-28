import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/ui/common/app_icons.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/order_detail/order_detail_viewmodel.dart';
import 'package:splg_customer/ui/widgets/receipt_source_sheet.dart';

/// Pago por transferencia en el detalle del pedido: datos bancarios con copiar,
/// subir el comprobante y los ya subidos.
class TransferCard extends StatelessWidget {
  const TransferCard({super.key, required this.model});

  final OrderDetailViewModel model;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final bank = model.bankDetails;
    return Column(
      key: const Key('detail-transfer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(AppIcons.bank, size: 22, color: brasa.primaryStrong),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Pago por transferencia', style: type.subtitle)),
          ],
        ),
        const SizedBox(height: 10),
        if (model.canPayByTransfer) ...[
          if (model.bankError != null)
            Text(model.bankError!,
                key: const Key('transfer-bank-error'), style: type.caption)
          else if (model.bankMissing)
            Text(
                'La distribuidora todavía no cargó sus datos bancarios. '
                'Consultale cómo transferir antes de pagar.',
                key: const Key('transfer-bank-missing'),
                style: type.caption)
          else if (bank != null) ...[
            if (bank.holder != null)
              _Line(title: 'Titular', value: bank.holder!),
            if (bank.cbu != null)
              _Line(
                  copyKey: const Key('transfer-cbu-copy'),
                  title: 'CBU',
                  value: bank.cbu!,
                  copied: model.copied == 'cbu',
                  onCopy: () => model.copy('cbu', bank.cbu!)),
            if (bank.alias != null)
              _Line(
                  copyKey: const Key('transfer-alias-copy'),
                  title: 'Alias',
                  value: bank.alias!,
                  copied: model.copied == 'alias',
                  onCopy: () => model.copy('alias', bank.alias!)),
            const SizedBox(height: 4),
            Text(
                'Transferí el total del pedido y subí el comprobante para que '
                'la distribuidora confirme tu pago.',
                style: type.caption),
          ],
          const SizedBox(height: 12),
          SplgButton(
            key: const Key('transfer-upload'),
            title: 'Subir comprobante',
            loading: model.uploading,
            onPressed: model.canUploadReceipt
                ? () async {
                    final source = await chooseReceiptSource(context);
                    if (source != null) await model.uploadReceipt(source);
                  }
                : null,
          ),
        ],
        if (model.receiptsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(model.receiptsError!,
                key: const Key('transfer-receipts-error'), style: type.caption),
          ),
        if (model.receipts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Comprobantes enviados', style: type.body),
          for (final r in model.receipts)
            SplgOptionRow(
              key: Key('receipt-${r.id}'),
              icon: r.isPdf ? AppIcons.filePdf : AppIcons.gallery,
              title: r.name,
              value: dateTimeLabel(r.uploadedAt),
              onTap: () => model.openReceipt(r),
            ),
        ],
        Divider(color: brasa.outline, height: 28),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.value,
    this.onCopy,
    this.copied = false,
    this.copyKey,
  });

  final String title;
  final String value;
  final VoidCallback? onCopy;
  final bool copied;
  final Key? copyKey;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: type.body.copyWith(color: brasa.muted)),
                SelectableText(value,
                    style: type.body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (onCopy != null)
            TextButton.icon(
              key: copyKey,
              onPressed: onCopy,
              icon: Icon(copied ? Icons.check : AppIcons.copy, size: 18),
              label: Text(copied ? 'Copiado' : 'Copiar'),
            ),
        ],
      ),
    );
  }
}
