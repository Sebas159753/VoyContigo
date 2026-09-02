import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

/// Hoja con el punto de un paradero/parada sobre OpenStreetMap.
///
/// - Modo lectura (por defecto): pin fijo en el punto; el pasajero solo ve.
/// - Modo ajustable ([adjustable] = true, solo perfil conductor): el pin
///   queda fijo al centro y el conductor arrastra el mapa con el dedo hasta
///   el punto exacto por el que pasa; al guardar se devuelve la coordenada.
Future<void> showStopMapSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required double lat,
  required double lng,
  bool adjustable = false,
  void Function(double lat, double lng)? onSave,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _StopMapSheet(
      title: title,
      subtitle: subtitle,
      lat: lat,
      lng: lng,
      adjustable: adjustable,
      onSave: onSave,
    ),
  );
}

class _StopMapSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double lat;
  final double lng;
  final bool adjustable;
  final void Function(double lat, double lng)? onSave;

  const _StopMapSheet({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.adjustable,
    required this.onSave,
  });

  @override
  State<_StopMapSheet> createState() => _StopMapSheetState();
}

class _StopMapSheetState extends State<_StopMapSheet> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Widget _pin() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.purpleDarkest,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTheme.titleFont(fontSize: 22, color: AppTheme.ink),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style:
                    AppTheme.bodyFont(fontSize: 13, color: AppTheme.inkMuted),
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(widget.lat, widget.lng),
                        initialZoom: 16.5,
                        // En modo lectura el mapa igual se puede explorar.
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.voycontigo.voycontigo',
                        ),
                        if (!widget.adjustable)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(widget.lat, widget.lng),
                                width: 46,
                                height: 46,
                                child: _pin(),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Pin fijo al centro: el conductor mueve el mapa debajo.
                    if (widget.adjustable)
                      Center(
                        child: IgnorePointer(
                          child: SizedBox(width: 46, height: 46, child: _pin()),
                        ),
                      ),
                    if (widget.adjustable)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                          child: Text(
                            'Arrastra el mapa hasta el punto exacto de tu parada 👆',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyFont(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.adjustable)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Guardar punto'),
                      onPressed: () {
                        final center = _mapController.camera.center;
                        widget.onSave
                            ?.call(center.latitude, center.longitude);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
