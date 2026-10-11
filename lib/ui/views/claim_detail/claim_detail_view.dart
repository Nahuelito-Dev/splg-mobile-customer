import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/domain/my_claim.dart';
import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/claims/claims_view.dart';
import 'package:splg_customer/ui/widgets/app_header.dart';

/// Detalle de un reclamo propio: motivo, descripción, estado y la nota con la
/// que se resolvió.
class ClaimDetailView extends StatelessWidget {
  const ClaimDetailView({super.key, required this.claim});

  final MyClaim claim;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    return Scaffold(
      appBar: const AppHeader(title: 'Reclamo', bell: false),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SplgSectionBar(
                  title: dateTimeLabel(claim.createdAt),
                  trailing: claim.status.label.toUpperCase()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(claim.reason, style: type.heading)),
                        const SizedBox(width: 10),
                        SplgStatusBadge(
                            label: claim.status.label,
                            tone: claimTone(claim.status)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(claim.description, style: type.body),
                    const SizedBox(height: 16),
                    SplgInfoSection(
                      icon: SplgIcons.deliveries,
                      title: 'Pedido reclamado',
                      rows: [
                        SplgInfoRow(
                            title: 'Código:',
                            value: claim.orderId.length > 6
                                ? '#${claim.orderId.substring(claim.orderId.length - 6)}'
                                : claim.orderId),
                        if (claim.orderTotal != null)
                          SplgInfoRow(
                              title: 'Total:',
                              value: money.format(claim.orderTotal)),
                      ],
                    ),
                    if ((claim.resolutionNote ?? '').isNotEmpty)
                      SplgInfoSection(
                        icon: SplgIcons.ok,
                        title: 'Respuesta de la distribuidora',
                        rows: [
                          SplgInfoRow(
                              title: 'Nota:', value: claim.resolutionNote)
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
