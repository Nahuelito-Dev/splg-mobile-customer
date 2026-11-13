import 'package:flutter/material.dart';

/// Imagen de una URL firmada que da el back. Si falta, venció o falla la
/// descarga, muestra [fallback] y avisa la falla por [onError] (para volver a
/// pedir la URL). La caché es la de memoria de Flutter.
class SignedImage extends StatelessWidget {
  const SignedImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.height,
    this.onError,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;
  final double? height;
  final void Function(String url)? onError;

  @override
  Widget build(BuildContext context) {
    if (url == null) return fallback;
    return Image.network(
      url!,
      fit: fit,
      height: height,
      errorBuilder: (_, __, ___) {
        final notify = onError;
        if (notify != null) {
          final failed = url!;
          // Fuera del build: el aviso puede terminar repintando la pantalla.
          Future.microtask(() => notify(failed));
        }
        return fallback;
      },
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
