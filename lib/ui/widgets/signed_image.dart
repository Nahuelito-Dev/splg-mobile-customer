import 'package:flutter/material.dart';

/// Imagen de una URL firmada que da el back. Si falta, venció o falla la
/// descarga, muestra [fallback]. La caché es la de memoria de Flutter.
class SignedImage extends StatelessWidget {
  const SignedImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.height,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (url == null) return fallback;
    return Image.network(
      url!,
      fit: fit,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
