import 'package:flutter/material.dart';
import 'package:splg_lib/theme/brasa_palette.dart';

/// Aviso "Tu garrafa está llegando": fondo suave de aviso con borde y texto
/// del color de aviso (AA en claro y en oscuro; el aviso sólido con texto
/// blanco no llega a 4,5:1 sobre el aviso del tema oscuro).
class ArrivingBanner extends StatelessWidget {
  const ArrivingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.brasa;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warnSoft,
        border: Border.all(color: palette.warn),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'Tu garrafa está llegando. Por favor salí a recibirla.',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: palette.warn,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
