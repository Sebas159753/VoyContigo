import 'package:flutter/material.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/domain/stops_catalog.dart';
import 'package:voycontigo/features/trips/presentation/widgets/stop_map_sheet.dart';

/// Selector de tramo sobre la línea del corredor, estilo diagrama de metro.
///
/// El usuario toca el paradero donde se sube y luego donde se baja; el
/// tramo elegido se resalta. Un tercer toque reinicia la selección desde
/// el nuevo paradero.
class StopLinePicker extends StatelessWidget {
  /// Paraderos ya en el orden del viaje (usar [stopsForDirection]).
  final List<RouteStop> stops;
  final RouteStop? origin;
  final RouteStop? destination;
  final String originLabel;
  final String destinationLabel;
  final void Function(RouteStop? origin, RouteStop? destination) onChanged;

  /// Solo perfil conductor (oferta): permite afinar el punto exacto de la
  /// parada arrastrando el mapa desde el paradero elegido.
  final bool allowExactAdjust;
  final void Function(RouteStop stop, bool isOrigin, double lat, double lng)?
      onExactPointSaved;

  const StopLinePicker({
    super.key,
    required this.stops,
    required this.origin,
    required this.destination,
    required this.onChanged,
    this.originLabel = 'Subes',
    this.destinationLabel = 'Bajas',
    this.allowExactAdjust = false,
    this.onExactPointSaved,
  });

  int _indexOf(RouteStop? stop) =>
      stop == null ? -1 : stops.indexWhere((s) => s.id == stop.id);

  void _handleTap(RouteStop tapped) {
    final originIdx = _indexOf(origin);
    final tappedIdx = _indexOf(tapped);

    if (origin == null) {
      onChanged(tapped, null);
      return;
    }
    if (tapped.id == origin!.id) {
      onChanged(null, null); // deseleccionar todo
      return;
    }
    if (destination != null && tapped.id == destination!.id) {
      onChanged(origin, null); // quitar solo la bajada
      return;
    }
    if (tappedIdx < originIdx) {
      // Tocó antes de la subida: mueve la subida y conserva la bajada.
      onChanged(tapped, destination);
      return;
    }
    // Tocó después de la subida: fija (o mueve) la bajada.
    onChanged(origin, tapped);
  }

  /// Vista del paradero en el mapa. Si es un extremo elegido y el modo
  /// conductor lo permite, se abre en modo ajustable para fijar el punto
  /// exacto de la parada; si no, en modo solo lectura.
  void _showStopOnMap(BuildContext context, RouteStop stop) {
    final bool isEndpoint =
        stop.id == origin?.id || stop.id == destination?.id;
    final bool adjustable = allowExactAdjust && isEndpoint;

    showStopMapSheet(
      context,
      title: stop.name,
      subtitle: adjustable
          ? '${stop.reference} · ajusta tu parada exacta'
          : stop.reference,
      lat: stop.lat,
      lng: stop.lng,
      adjustable: adjustable,
      onSave: adjustable
          ? (lat, lng) =>
              onExactPointSaved?.call(stop, stop.id == origin?.id, lat, lng)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final originIdx = _indexOf(origin);
    final destIdx = _indexOf(destination);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < stops.length; i++) ...[
            if (i > 0 && stops[i].isMachachiSide != stops[i - 1].isMachachiSide)
              _ZoneDivider(
                label: stops[i].isMachachiSide ? 'MACHACHI' : 'QUITO',
              ),
            _StopRow(
              stop: stops[i],
              isFirst: i == 0,
              isLast: i == stops.length - 1,
              isOrigin: i == originIdx,
              isDestination: i == destIdx,
              inSegment: originIdx >= 0 &&
                  destIdx > originIdx &&
                  i >= originIdx &&
                  i <= destIdx,
              originLabel: originLabel,
              destinationLabel: destinationLabel,
              onTap: () => _handleTap(stops[i]),
              onViewMap: () => _showStopOnMap(context, stops[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  final String label;

  const _ZoneDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 40), // alineado con la línea
          const Expanded(child: Divider(color: AppTheme.outline)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.subtitleFont(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppTheme.outline)),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
  final bool isOrigin;
  final bool isDestination;
  final bool inSegment;
  final String originLabel;
  final String destinationLabel;
  final VoidCallback onTap;
  final VoidCallback onViewMap;

  const _StopRow({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isOrigin,
    required this.isDestination,
    required this.inSegment,
    required this.originLabel,
    required this.destinationLabel,
    required this.onTap,
    required this.onViewMap,
  });

  bool get _isEndpoint => isOrigin || isDestination;

  @override
  Widget build(BuildContext context) {
    final Color lineColor =
        inSegment ? AppTheme.purpleDark : AppTheme.outline;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Columna de la línea con el nodo del paradero.
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isFirst ? Colors.transparent : lineColor,
                    ),
                  ),
                  _StopNode(
                    isEndpoint: _isEndpoint,
                    inSegment: inSegment,
                    isOrigin: isOrigin,
                  ),
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isLast ? Colors.transparent : lineColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: AppTheme.bodyFont(
                      fontSize: 15,
                      fontWeight:
                          _isEndpoint ? FontWeight.w800 : FontWeight.w500,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    stop.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyFont(
                      fontSize: 11,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onViewMap,
              visualDensity: VisualDensity.compact,
              tooltip: 'Ver en el mapa',
              icon: const Icon(Icons.map_outlined,
                  size: 20, color: AppTheme.purpleMedium),
            ),
            if (isOrigin || isDestination)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOrigin
                      ? AppTheme.purpleDarkest
                      : AppTheme.successGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOrigin ? originLabel : destinationLabel,
                  style: AppTheme.subtitleFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.add_circle_outline,
                    size: 18, color: AppTheme.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopNode extends StatelessWidget {
  final bool isEndpoint;
  final bool inSegment;
  final bool isOrigin;

  const _StopNode({
    required this.isEndpoint,
    required this.inSegment,
    required this.isOrigin,
  });

  @override
  Widget build(BuildContext context) {
    if (isEndpoint) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isOrigin ? AppTheme.purpleDarkest : AppTheme.successGreen,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
            ),
          ],
        ),
      );
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: inSegment ? AppTheme.purpleDark : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: inSegment ? AppTheme.purpleDark : AppTheme.inkMuted,
          width: 2,
        ),
      ),
    );
  }
}
