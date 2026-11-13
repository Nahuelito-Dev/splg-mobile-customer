import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Íconos de la barra de estado (hora, batería) según el fondo que queda
/// detrás. Las pantallas con AppBar ya lo resuelven; las que no tienen lo
/// declaran con [StatusBarRegion], porque si nadie lo declara queda el estilo
/// de la pantalla anterior.
class StatusBarStyles {
  StatusBarStyles._();

  /// Íconos claros: fondo naranja de marca (Brasa) u oscuro.
  static const lightIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Íconos oscuros: fondo claro (superficie, mapa, blanco).
  static const darkIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );
}

enum _StatusBarBackground { brand, light, surface }

/// Declara cómo se ven los íconos de la barra de estado sobre [child].
class StatusBarRegion extends StatelessWidget {
  /// Fondo naranja de marca: íconos claros.
  const StatusBarRegion.brand({super.key, required this.child})
      : _background = _StatusBarBackground.brand;

  /// Fondo claro fijo (mapa, blanco): íconos oscuros con cualquier tema.
  const StatusBarRegion.light({super.key, required this.child})
      : _background = _StatusBarBackground.light;

  /// Fondo de superficie del tema: oscuros en el claro, claros en el oscuro.
  const StatusBarRegion.surface({super.key, required this.child})
      : _background = _StatusBarBackground.surface;

  final Widget child;
  final _StatusBarBackground _background;

  @override
  Widget build(BuildContext context) {
    final style = switch (_background) {
      _StatusBarBackground.brand => StatusBarStyles.lightIcons,
      _StatusBarBackground.light => StatusBarStyles.darkIcons,
      _StatusBarBackground.surface =>
        Theme.of(context).brightness == Brightness.dark
            ? StatusBarStyles.lightIcons
            : StatusBarStyles.darkIcons,
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
  }
}
