import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';

const helpEntries = [
  SplgAccordionEntry(
    title: '¿Cómo hago un pedido?',
    body: 'En Inicio sumá las garrafas que necesitás con el botón +, elegí '
        'la dirección de entrega y tocá "Continuar". En la confirmación '
        'elegís cuándo y cómo pagás.',
  ),
  SplgAccordionEntry(
    title: '¿Cómo cancelo un pedido?',
    body: 'Entrá a "Mis pedidos", abrí el pedido y tocá "Cancelar pedido". '
        'Sólo se puede cancelar mientras está pendiente; si ya salió a '
        'entregar, comunicate con tu distribuidora.',
  ),
  SplgAccordionEntry(
    title: '¿Qué formas de pago hay?',
    body: 'Efectivo al recibir, transferencia (con un 10 % de recargo) y '
        'Mercado Pago.',
  ),
  SplgAccordionEntry(
    title: '¿Cómo cambio mis direcciones?',
    body: 'En "Mis direcciones" podés agregar una nueva, editarla, '
        'marcarla como predeterminada o eliminarla.',
  ),
  SplgAccordionEntry(
    title: '¿Cómo cambio mi contraseña?',
    body: 'Entrá a Mi perfil y elegí "Cambiar contraseña". Si la olvidaste, '
        'en la pantalla de inicio de sesión tocá "¿Olvidaste tu '
        'contraseña?" y te mandamos un correo.',
  ),
  SplgAccordionEntry(
    title: 'Tengo un problema con un pedido',
    body: 'Abrí el pedido en "Mis pedidos" y tocá "Hacer un reclamo". '
        'Después seguís su estado en "Mis reclamos".',
  ),
  SplgAccordionEntry(
    title: '¿Cómo elimino mi cuenta?',
    body: 'En Mi perfil, "Eliminar cuenta". Es definitiva y no se puede '
        'hacer con un pedido en curso.',
  ),
];

class HelpView extends StatefulWidget {
  const HelpView({super.key});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  String _query = '';

  List<SplgAccordionEntry> get _entries {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return helpEntries;
    return [
      for (final e in helpEntries)
        if (e.title.toLowerCase().contains(q) ||
            e.body.toLowerCase().contains(q))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: const AppHeader(title: 'Ayuda'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: SplgSearchField(
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No encontramos nada con esa búsqueda.',
                      textAlign: TextAlign.center,
                      style: SplgType.of(context).body),
                )
              else
                // La clave fuerza a reconstruir el acordeón al cambiar el filtro.
                SplgAccordion(
                    key: ValueKey(_query.trim().toLowerCase()),
                    entries: entries),
            ],
          ),
        ),
      ),
    );
  }
}
