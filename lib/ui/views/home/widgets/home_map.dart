import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:splg_customer/core/config/app_config.dart';
import 'package:splg_lib/splg_lib.dart';

/// Mapa del inicio a pantalla completa: marca la dirección de entrega elegida y
/// se recentra cuando cambia o cuando el usuario pide "Mi ubicación".
class HomeMap extends StatefulWidget {
  const HomeMap({
    super.key,
    this.delivery,
    this.user,
    this.showUserLocation = false,
  });

  /// Dirección de entrega (con coordenadas) a marcar.
  final LatLng? delivery;

  /// Última posición pedida con el botón "Mi ubicación".
  final LatLng? user;

  /// Habilita el punto azul del SDK (sólo con el permiso ya concedido).
  final bool showUserLocation;

  /// Los tests lo activan: no hay mapa de Google en el entorno de pruebas.
  @visibleForTesting
  static bool placeholder = false;

  static LatLng get fallback =>
      LatLng(AppConfig.mapFallbackLat, AppConfig.mapFallbackLng);

  @override
  State<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(HomeMap old) {
    super.didUpdateWidget(old);
    final target = widget.user != old.user && widget.user != null
        ? widget.user
        : widget.delivery != old.delivery
            ? widget.delivery
            : null;
    if (target != null) {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (HomeMap.placeholder) {
      return ColoredBox(
        key: const Key('home-map-placeholder'),
        color: context.brasa.surfaceSunken,
        child: Center(
          child: Icon(SplgIcons.location,
              size: 56, color: context.brasa.primaryStrong),
        ),
      );
    }
    final delivery = widget.delivery;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: delivery ?? HomeMap.fallback,
        zoom: delivery == null ? 12 : 16,
      ),
      onMapCreated: (c) {
        _controller = c;
        // Si las direcciones llegaron antes que el mapa, se centra recién acá.
        final target = widget.user ?? widget.delivery;
        if (target != null) {
          c.moveCamera(CameraUpdate.newLatLngZoom(target, 16));
        }
      },
      markers: {
        if (delivery != null)
          Marker(markerId: const MarkerId('delivery'), position: delivery),
      },
      myLocationEnabled: widget.showUserLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
