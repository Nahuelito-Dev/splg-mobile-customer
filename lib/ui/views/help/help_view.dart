import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/app/app.locator.dart';
import 'package:splg_customer/domain/payment_term.dart';
import 'package:splg_customer/services/gas_cylinder_service.dart';
import 'package:splg_customer/ui/widgets/app_header.dart';

/// Las preguntas frecuentes. El recargo de cada medio de pago lo informa el
/// back: sin él (todavía no respondió) no se menciona ninguno.
List<SplgAccordionEntry> helpEntriesFor(List<PaymentTerm> terms) => [
      const SplgAccordionEntry(
        title: '¿Cómo hago un pedido?',
        body: 'En Inicio sumá las garrafas que necesitás con el botón +, elegí '
            'la dirección de entrega y tocá "Continuar". En la confirmación '
            'elegís cuándo y cómo pagás.',
      ),
      const SplgAccordionEntry(
        title: '¿Cómo cancelo un pedido?',
        body: 'Entrá a "Mis pedidos", abrí el pedido y tocá "Cancelar pedido". '
            'Sólo se puede cancelar mientras está pendiente; si ya salió a '
            'entregar, comunicate con tu distribuidora.',
      ),
      SplgAccordionEntry(
        title: '¿Qué formas de pago hay?',
        body: paymentHelpBody(terms),
      ),
      const SplgAccordionEntry(
        title: '¿Cómo cambio mis direcciones?',
        body: 'En "Mis direcciones" podés agregar una nueva, editarla, '
            'marcarla como predeterminada o eliminarla.',
      ),
      const SplgAccordionEntry(
        title: '¿Cómo cambio mi contraseña?',
        body:
            'Entrá a Mi perfil y elegí "Cambiar contraseña". Si la olvidaste, '
            'en la pantalla de inicio de sesión tocá "¿Olvidaste tu '
            'contraseña?" y te mandamos un correo.',
      ),
      const SplgAccordionEntry(
        title: 'Tengo un problema con un pedido',
        body: 'Abrí el pedido en "Mis pedidos" y tocá "Hacer un reclamo". '
            'Después seguís su estado en "Mis reclamos".',
      ),
      const SplgAccordionEntry(
        title: '¿Cómo elimino mi cuenta?',
        body: 'En Mi perfil, "Eliminar cuenta". Es definitiva y no se puede '
            'hacer con un pedido en curso.',
      ),
    ];

/// "Efectivo al recibir, transferencia (con un 10 % de recargo) y Mercado Pago."
/// Lo que no tiene recargo, o que el back no informó, va sin mención.
String paymentHelpBody(List<PaymentTerm> terms) {
  String withSurcharge(String text, String key) {
    final term = PaymentTerm.of(terms, key);
    return term != null && term.hasSurcharge
        ? '$text (con un ${term.percentageLabel} de recargo)'
        : text;
  }

  return '${withSurcharge('Efectivo al recibir', 'CASH')}, '
      '${withSurcharge('transferencia', 'TRANSFER')} y '
      '${withSurcharge('Mercado Pago', 'MERCADOPAGO')}.';
}

class HelpView extends StatefulWidget {
  const HelpView({super.key});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  String _query = '';
  List<PaymentTerm> _terms = const [];

  @override
  void initState() {
    super.initState();
    locator<GasCylinderService>().paymentTerms().then((terms) {
      if (mounted) setState(() => _terms = terms);
    });
  }

  List<SplgAccordionEntry> get _entries {
    final q = _query.trim().toLowerCase();
    final all = helpEntriesFor(_terms);
    if (q.isEmpty) return all;
    return [
      for (final e in all)
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
