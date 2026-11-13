import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/domain/repurchase.dart';

/// Invitación a reponer (M3): «Te estás quedando sin gas», con lo que suele
/// pedir, dónde y en qué franja. [addressLabel] es la dirección con la que se
/// va a pedir y «Cambiar» la elige. «Pedir» crea el pedido; «Ahora no» la
/// descarta.
class RepurchaseCard extends StatelessWidget {
  const RepurchaseCard({
    super.key,
    required this.invitation,
    required this.addressLabel,
    required this.totalText,
    required this.totalError,
    required this.canAccept,
    this.onRetryQuote,
    required this.busy,
    required this.onChangeAddress,
    required this.onAccept,
    required this.onDismiss,
  });

  final RepurchaseInvitation invitation;
  final String? addressLabel;

  /// «Total aproximado …» o «Calculando…»; null si no se pudo cotizar.
  final String? totalText;

  /// Por qué no se pudo cotizar con la dirección elegida (texto del back).
  final String? totalError;

  /// «Pedir» habilitado (lo decide el ViewModel).
  final bool canAccept;

  /// «Reintentar» la cotización; null si el rechazo es definitivo.
  final VoidCallback? onRetryQuote;
  final bool busy;
  final VoidCallback onChangeAddress;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                      addressLabel == null
                          ? 'Elegí dónde te lo llevamos'
                          : 'Entrega en $addressLabel',
                      key: const Key('home-repurchase-address'),
                      style: type.caption),
                ),
                TextButton(
                  key: const Key('home-repurchase-change'),
                  onPressed: busy ? null : onChangeAddress,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            if (slot != null) Text('Franja: ${slot.label}', style: type.caption),
            if (totalText != null)
              Text(totalText!,
                  key: const Key('home-repurchase-total'), style: type.caption),
            if (totalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(totalError!,
                          key: const Key('home-repurchase-quote-error'),
                          style: type.caption.copyWith(color: brasa.danger)),
                    ),
                    if (onRetryQuote != null)
                      TextButton(
                        key: const Key('home-repurchase-quote-retry'),
                        onPressed: busy ? null : onRetryQuote,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
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
                    onPressed: canAccept ? onAccept : null,
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
