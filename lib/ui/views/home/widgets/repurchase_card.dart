import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/domain/repurchase.dart';
import 'package:splg_customer/ui/common/formatters.dart';

/// Invitación a reponer (M3): «Te estás quedando sin gas», con lo que suele
/// pedir, dónde y en qué franja. «Pedir» crea el pedido; «Ahora no» la descarta.
class RepurchaseCard extends StatelessWidget {
  const RepurchaseCard({
    super.key,
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDismiss,
  });

  final RepurchaseInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final scheme = Theme.of(context).colorScheme;
    final slot = invitation.slot;
    return Material(
      key: const Key('home-repurchase-card'),
      color: scheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(SplgIcons.flame, color: brasa.warn, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Te estás quedando sin gas', style: type.value),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(invitation.itemsLabel,
                key: const Key('home-repurchase-items'), style: type.body),
            if (invitation.addressLabel != null)
              Text('Entrega en ${invitation.addressLabel}',
                  style: type.caption),
            if (slot != null) Text('Franja: ${slot.label}', style: type.caption),
            Text('Total aproximado ${money.format(invitation.estimatedTotal)}',
                key: const Key('home-repurchase-total'), style: type.caption),
            if (invitation.hasUnavailable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Alguna garrafa ya no tiene stock.',
                    key: const Key('home-repurchase-unavailable'),
                    style: type.caption.copyWith(color: brasa.danger)),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SplgButton(
                    key: const Key('home-repurchase-dismiss'),
                    title: 'Ahora no',
                    style: SplgButtonStyle.outlined,
                    onPressed: busy ? null : onDismiss,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SplgButton(
                    key: const Key('home-repurchase-accept'),
                    title: 'Pedir',
                    loading: busy,
                    onPressed: busy || invitation.hasUnavailable ? null : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
