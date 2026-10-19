import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

/// Bloque de datos de una ficha: ícono y título de la sección, y debajo las
/// filas "dato ... valor" a todo el ancho.
class AppInfoSection extends StatelessWidget {
  const AppInfoSection({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<AppInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final brasa = context.brasa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: brasa.primaryStrong),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: SplgType.of(context).subtitle)),
          ],
        ),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 8),
            child: r,
          ),
        Divider(color: brasa.outline, height: 28),
      ],
    );
  }
}

/// Un par dato / valor de [AppInfoSection]: el dato en tono apagado a la
/// izquierda y el valor, en tinta, a la derecha.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({super.key, required this.title, required this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final label =
        title.endsWith(':') ? title.substring(0, title.length - 1) : title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: type.body.copyWith(color: brasa.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value ?? 'Sin datos',
            textAlign: TextAlign.right,
            style: type.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
