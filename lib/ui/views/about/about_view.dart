import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/ui/widgets/app_header.dart';

const aboutEntries = [
  SplgAccordionEntry(
    title: '¿Qué es SPLG?',
    body: 'SPLG es el sistema de pedidos y logística de garrafas: los '
        'clientes piden desde su app, la distribuidora administra todo desde '
        'el panel y los choferes entregan con su propia app.',
  ),
  SplgAccordionEntry(
    title: '¿Cómo hago un pedido?',
    body: 'En Inicio elegí las garrafas, confirmá la dirección de entrega y '
        'la forma de pago, y listo. Podés seguir el pedido hasta que llega.',
  ),
  SplgAccordionEntry(
    title: '¿Quién desarrolla la app?',
    body: 'SPLG es un proyecto de tesis. Para consultas escribí a '
        'soporte@splg.app.',
  ),
];

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        appBar: AppHeader(title: 'Acerca de nosotros', bell: false),
        body: SafeArea(
          child: SingleChildScrollView(
            child: SplgAccordion(
                entries: aboutEntries, initiallyOpen: 0, iconUp: true),
          ),
        ),
      );
}
