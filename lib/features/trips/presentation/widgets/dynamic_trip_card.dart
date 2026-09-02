import 'dart:ui'; // For ImageFilter
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/core/utils/date_format.dart';

class DynamicTripCard extends StatefulWidget {
  final TripBoardItem item;
  final bool isOfferList;
  final bool isReadOnly;
  final bool isCensored;
  final VoidCallback onActionPressed;
  final VoidCallback? onCancelPressed;

  const DynamicTripCard({
    super.key,
    required this.item,
    required this.isOfferList,
    required this.isReadOnly,
    this.isCensored = false,
    required this.onActionPressed,
    this.onCancelPressed,
  });

  @override
  State<DynamicTripCard> createState() => _DynamicTripCardState();
}

class _DynamicTripCardState extends State<DynamicTripCard> {
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final item = widget.item;
    if (item.originLat == null || item.originLng == null || item.destLat == null || item.destLng == null) {
      if (mounted) setState(() => _isLoadingRoute = false);
      return;
    }
    
    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${item.originLng},${item.originLat};${item.destLng},${item.destLat}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final points = coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          if (mounted) {
            setState(() {
              _routePoints = points;
              _isLoadingRoute = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingRoute = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'CANCELLED':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red[700]!;
        text = 'CANCELADO';
        icon = Icons.cancel;
        break;
      case 'COMPLETED':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green[700]!;
        text = 'COMPLETADO';
        icon = Icons.check_circle;
        break;
      case 'EN_ROUTE':
        bgColor = AppTheme.tommyNavy.withOpacity(0.1);
        textColor = AppTheme.tommyNavy;
        text = 'EN CAMINO';
        icon = Icons.directions_car;
        break;
      case 'ACCEPTED':
        bgColor = AppTheme.purpleLightest.withOpacity(0.15);
        textColor = AppTheme.purpleDarkest;
        text = 'ACEPTADO';
        icon = Icons.handshake;
        break;
      case 'FULL':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[800]!;
        text = 'LLENO';
        icon = Icons.group;
        break;
      default: // PENDING
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.black54;
        text = 'BUSCANDO...';
        icon = Icons.search;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.bodyFont(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isOfferList = widget.isOfferList;
    final isReadOnly = widget.isReadOnly;
    final isCensored = widget.isCensored;
    final onActionPressed = widget.onActionPressed;

    // Calculamos el tiempo restante
    final now = DateTime.now();
    final difference = item.scheduleTime.difference(now);

    final String timeLeftText = VoyDate.relativeDeparture(item.scheduleTime, now: now);
    final Color timeLeftColor = difference.isNegative ? AppTheme.inkMuted : AppTheme.ink;

    // Simulador de urgencia realista: más vistas si la salida está próxima
    int viewersCount = 1;
    if (!difference.isNegative) {
      if (difference.inMinutes < 30) {
        viewersCount = (item.id.hashCode % 3) + 3; // 3 a 5 personas si sale en menos de 30 min
      } else if (difference.inMinutes < 120) {
        viewersCount = (item.id.hashCode % 2) + 2; // 2 a 3 personas si sale en menos de 2 horas
      } else {
        viewersCount = 1; // 1 persona si falta mucho
      }
    } else {
      viewersCount = 0; // 0 si ya pasó la hora
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 8, 
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.status != 'PENDING' && item.status != 'FULL') ...[
            _buildStatusBadge(item.status),
            const SizedBox(height: 12),
          ],
          if (item.status == 'PENDING' || item.status == 'FULL') ...[
            _buildStatusBadge(item.status),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: isCensored ? 4 : 0, sigmaY: isCensored ? 4 : 0),
                            child: Text(
                              isCensored ? 'Conductor Oculto' : item.userName, 
                              style: AppTheme.bodyFont(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (item.isCreatorVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppTheme.tommyNavy),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text('${item.rating}', style: AppTheme.bodyFont(color: Colors.amber[900], fontWeight: FontWeight.w700, fontSize: 11)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 12, color: Colors.black45),
                            const SizedBox(width: 4),
                            Text('$viewersCount viendo', style: AppTheme.bodyFont(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (item.womenOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.pink.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.female, color: Colors.pink, size: 10),
                                const SizedBox(width: 2),
                                Text('Solo Mujeres', style: AppTheme.bodyFont(color: Colors.pink, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6)
                ),
                child: Text('\$${item.price?.toStringAsFixed(2) ?? '0.00'}', style: AppTheme.bodyFont(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
              )
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.black12),
          ),
          
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.black),
                  Container(height: 20, width: 2, color: Colors.black12),
                  const Icon(Icons.location_on, size: 12, color: Colors.black),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: isCensored ? 3 : 0, sigmaY: isCensored ? 3 : 0),
                      child: Text(isCensored ? item.origin.split(',').first : '${item.origin} - ${item.exactPickup}', style: AppTheme.bodyFont(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 10),
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: isCensored ? 3 : 0, sigmaY: isCensored ? 3 : 0),
                      child: Text(isCensored ? item.destination.split(',').first : '${item.destination} - ${item.exactDropoff}', style: AppTheme.bodyFont(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (item.stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vía: ${item.stops.join(', ')}',
                      style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (item.originLat != null && item.originLng != null && item.destLat != null && item.destLng != null)
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: isCensored ? 4 : 0, sigmaY: isCensored ? 4 : 0),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (item.originLat! + item.destLat!) / 2,
                      (item.originLng! + item.destLng!) / 2,
                    ),
                    initialZoom: 10.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.voycontigo.voycontigo',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppTheme.tommyNavy,
                            strokeWidth: 4.0,
                          ),
                        ],
                      )
                    else if (_isLoadingRoute)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(item.originLat!, item.originLng!),
                              LatLng(item.destLat!, item.destLng!),
                            ],
                            color: Colors.black38,
                            strokeWidth: 2.0,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(item.originLat!, item.originLng!),
                          child: const Icon(Icons.circle, color: Colors.black, size: 12),
                        ),
                        Marker(
                          point: LatLng(item.destLat!, item.destLng!),
                          child: const Icon(Icons.location_on, color: Colors.black, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 11, color: AppTheme.ink),
                      const SizedBox(width: 4),
                      Text(VoyDate.shortDateTime(item.scheduleTime),
                          style: AppTheme.subtitleFont(color: AppTheme.ink, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 11, color: timeLeftColor),
                      const SizedBox(width: 4),
                      Text(timeLeftText,
                          style: AppTheme.bodyFont(color: timeLeftColor, fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              if (item.isOffer && item.carModel != null && item.carModel!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.tommyNavy.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.tommyNavy.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 12, color: AppTheme.tommyNavy),
                      const SizedBox(width: 4),
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: isCensored ? 4 : 0, sigmaY: isCensored ? 4 : 0),
                        child: Text(
                          isCensored 
                            ? 'Auto Oculto' 
                            : '${item.carModel}${item.carPlate != null && item.carPlate!.isNotEmpty ? ' (${item.carPlate})' : ''}',
                          style: AppTheme.bodyFont(color: AppTheme.tommyNavy, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isOffer ? AppTheme.tommyRed.withOpacity(0.1) : AppTheme.tommyNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item.isOffer ? AppTheme.tommyRed.withOpacity(0.3) : AppTheme.tommyNavy.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.isOffer ? Icons.event_seat : Icons.person_outline, size: 14, color: item.isOffer ? AppTheme.tommyRed : AppTheme.tommyNavy),
                    const SizedBox(width: 4),
                    Text(
                      item.isOffer ? '${item.availableSeats} libres' : 'Busca ${item.seats}', 
                      style: AppTheme.bodyFont(
                        color: item.isOffer ? AppTheme.tommyRed : AppTheme.tommyNavy, 
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (!isReadOnly)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: isCensored
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Theme.of(context).colorScheme.primary, // Dark premium look
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: onActionPressed,
                    icon: const Icon(Icons.lock, size: 16, color: Colors.amber),
                    label: Text('Desbloquear Viaje', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber, letterSpacing: -0.3)),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: onActionPressed,
                    child: Text(isOfferList ? 'Reservar Asiento' : 'Aceptar Pasajero', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3)),
                  ),
            )
          else if (item.status == 'ACCEPTED' || item.status == 'EN_ROUTE' || item.status == 'FULL' || (item.status == 'PENDING' && isReadOnly && (item.isOffer ? item.passengers.isNotEmpty : item.acceptedByUid != null)))
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => context.push('/tracking/${item.id}'),
                icon: const Icon(Icons.location_on, size: 18, color: Colors.white),
                label: Text('Ir al Chat / Seguimiento', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: Text(item.status == 'PENDING' ? (item.isOffer ? 'Esperando más pasajeros...' : 'Esperando conductor...') : 'Solo lectura', style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45)),
                  ),
                ),
                if (widget.onCancelPressed != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: widget.onCancelPressed,
                      child: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ),
                ],
              ],
            )
        ],
      ),
    );
  }
}
