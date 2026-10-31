import 'package:flutter/material.dart';
import 'package:splg_lib/splg_lib.dart';

import 'package:splg_customer/ui/common/formatters.dart';
import 'package:splg_customer/ui/views/home/home_viewmodel.dart';
import 'package:splg_customer/ui/widgets/signed_image.dart';

/// Tira horizontal con las garrafas a la vista, arriba del campo «¿Qué
/// necesitás?»: foto, nombre y precio. Tocar una la suma y abre el catálogo.
class FeaturedStrip extends StatelessWidget {
  const FeaturedStrip({super.key, required this.model, required this.onTap});

  final HomeViewModel model;
  final void Function(GasCylinder cylinder) onTap;

  static const height = 68.0;

  @override
  Widget build(BuildContext context) {
    final type = SplgType.of(context);
    final brasa = context.brasa;
    final items = model.cylinders;
    return SizedBox(
      key: const Key('home-featured-strip'),
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = items[i];
          final qty = model.getItemQuantity(c.id);
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('home-featured-${c.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => onTap(c),
              child: Container(
                width: 168,
                padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: qty > 0 ? brasa.primaryStrong : brasa.outline,
                      width: qty > 0 ? 2 : 1),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: SignedImage(
                        url: model.cylinderPhoto(c.id),
                        fallback: Image.asset('assets/cylinder_10.png',
                            fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.value),
                          Text(money.format(c.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.caption.copyWith(color: brasa.ink2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
