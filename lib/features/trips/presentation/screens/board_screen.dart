import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/data/trip_repository.dart';
import 'package:voycontigo/features/trips/presentation/widgets/dynamic_trip_card.dart';
import 'package:voycontigo/features/trips/presentation/widgets/my_active_trips_section.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/core/utils/error_handler.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  bool _isLoadingMore = false;

  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(-0.5097, -78.5672); // Machachi por defecto
  bool _isLoadingLocation = true;
  String? _selectedMarkerTripId;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation, 14.0);
      }
    } catch(e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<String?> _showPhoneRequiredDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Celular Requerido', style: AppTheme.bodyFont(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por motivos de seguridad y coordinación, los demás usuarios necesitan poder contactarte durante el viaje.',
              style: AppTheme.bodyFont(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Celular (ej: 0987654321)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isEmpty || phone.length < 7) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Por favor, ingresa un número celular válido')),
                );
                return;
              }
              await ref.read(appStateProvider.notifier).updateEmergencyPhone(phone);
              if (ctx.mounted) {
                Navigator.pop(ctx, phone);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Guardar y Continuar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeal(BuildContext context, TripBoardItem item, bool isOfferList) async {
    final isDriverAction = !isOfferList;
    final appState = ref.read(appStateProvider);

    // Aceptar una demanda implica conducir: exige identidad validada,
    // igual que para publicar una oferta.
    if (isDriverAction && !appState.isVerified) {
      _requireVehicleData(() {});
      return;
    }

    if (appState.emergencyPhone.isEmpty) {
      final newPhone = await _showPhoneRequiredDialog();
      if (newPhone == null || newPhone.isEmpty) {
        return;
      }
    }
    
    int seatsToBook = 1;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmar Viaje'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDriverAction 
                      ? '¿Deseas aceptar a este pasajero en tu vehículo y reservar el puesto?'
                      : '¿Cuántos asientos deseas reservar con este conductor?',
                  ),
                  if (!isDriverAction) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: seatsToBook > 1 ? () => setState(() => seatsToBook--) : null,
                        ),
                        Text('$seatsToBook', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: seatsToBook < item.availableSeats ? () => setState(() => seatsToBook++) : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      if (!isDriverAction) {
                        final passengerData = {
                          'uid': appState.uid,
                          'name': appState.userName,
                          'seats': seatsToBook,
                        };
                        await ref.read(tripRepositoryProvider).joinTripAsPassenger(
                          tripId: item.id,
                          uid: appState.uid,
                          passengerData: passengerData,
                          seatsToBook: seatsToBook,
                        );
                      } else {
                        await ref.read(tripRepositoryProvider).acceptTripAsDriver(
                          tripId: item.id,
                          uid: appState.uid,
                          userName: appState.userName,
                        );
                      }
                      
                      if (mounted) {
                        ErrorHandler.showSuccessSnackBar(context, '¡Transacción completada!');
                        context.push('/tracking/${item.id}');
                      }
                    } catch (e) {
                      if (mounted) {
                        ErrorHandler.showErrorSnackBar(context, e);
                      }
                    }
                  },
                  child: const Text('Aceptar Viaje', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _requireVehicleData(VoidCallback onSuccess) async {
    final appState = ref.read(appStateProvider);
    if (!appState.isVerified) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Identidad no validada'),
          content: const Text('Para llevar pasajeros como conductor, necesitas validar tu identidad por seguridad.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Validar Identidad'),
            ),
          ],
        ),
      );
      if (result == true && mounted) {
        context.push('/verify');
      }
    } else {
      onSuccess();
    }
  }

  Widget _buildOrderBookList({required bool isOfferList, required List<TripBoardItem> items, required bool canTransact, required String currentMode}) {
    final appState = ref.read(appStateProvider);
    var filtered = items.where((i) {
      if (i.isOffer != isOfferList || i.availableSeats <= 0) return false;
      // No mostrar tus propias publicaciones (no puedes reservarte a ti mismo).
      if (i.creatorUid == appState.uid) return false;
      if (i.acceptedByUid == appState.uid) return false;
      if (i.passengers.any((p) => p['uid'] == appState.uid)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(child: Text('No hay resultados en esta categoría.', style: AppTheme.bodyFont(color: Colors.black45, fontSize: 14))),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: filtered.map((item) {
          final isReadOnly = (currentMode == 'conductor' && isOfferList) || (currentMode == 'pasajero' && !isOfferList);
          final isDriverAction = !isOfferList;
          final canDoAction = isDriverAction ? canTransact : true;
          return DynamicTripCard(
            item: item,
            isOfferList: isOfferList,
            isReadOnly: isReadOnly,
            isCensored: !canDoAction && !isReadOnly,
            onActionPressed: () => _confirmDeal(context, item, isOfferList),
          );
        }).toList(),
      ),
    );
  }

  List<Marker> _buildMapMarkers(List<TripBoardItem> trips, String currentMode) {
    final pendingTrips = trips.where((t) => t.status == 'PENDING').toList();
    final isPassengerMode = currentMode == 'pasajero';
    final myUid = ref.read(appStateProvider).uid;

    // Viajes de otros (del lado que te interesa) + tus propias publicaciones,
    // que se pintan con un pin verde distintivo.
    final relevantTrips = pendingTrips
        .where((t) =>
            (t.isOffer == isPassengerMode && t.creatorUid != myUid) ||
            t.creatorUid == myUid)
        .toList();

    return relevantTrips.map((trip) {
      if (trip.originLat == null || trip.originLng == null) return null;

      final isSelected = trip.id == _selectedMarkerTripId;
      final isOwn = trip.creatorUid == myUid;

      return Marker(
        point: LatLng(trip.originLat!, trip.originLng!),
        width: isSelected ? 160 : 40,
        height: isSelected ? 100 : 40,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedMarkerTripId = isSelected ? null : trip.id;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: isSelected ? 0 : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isOwn
                        ? AppTheme.successGreen
                        : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
                  ),
                  child: Icon(
                    isOwn
                        ? Icons.star_rounded
                        : (isPassengerMode ? Icons.directions_car : Icons.person),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 45,
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwn ? 'Tu publicación ⭐' : trip.userName,
                          style: AppTheme.bodyFont(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A: ${trip.destination.split(',').first}',
                          style: AppTheme.bodyFont(fontSize: 11, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.stops.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Vía: ${trip.stops.join(', ')}',
                            style: AppTheme.bodyFont(fontSize: 9, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${trip.price?.toStringAsFixed(2) ?? '0.00'}',
                              style: AppTheme.bodyFont(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                children: [
                                  Icon(trip.isOffer ? Icons.event_seat : Icons.person, size: 10, color: Colors.black54),
                                  const SizedBox(width: 2),
                                  Text(trip.isOffer ? '${trip.availableSeats}' : '${trip.seats}', style: AppTheme.bodyFont(fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  Widget _buildWhereToBlock(BuildContext context, String currentMode) {
    final isPassenger = currentMode == 'pasajero';
    final title = isPassenger ? '¿A dónde vamos?' : '¿Hacia dónde conduces?';
    
    return GestureDetector(
      onTap: () {
        if (isPassenger) {
          context.push('/publish?type=demanda');
        } else {
          _requireVehicleData(() {
            context.push('/publish?type=oferta');
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTheme.bodyFont(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(boardModeProvider);
    final appState = ref.watch(appStateProvider);
    final marketState = ref.watch(marketTripsStreamProvider);
    
    final canTransact = appState.carModel.isNotEmpty && appState.carPlate.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.voycontigo.voycontigo',
              ),
              if (!_isLoadingLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.purpleMedium,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              if (marketState.hasValue)
                MarkerLayer(
                  markers: _buildMapMarkers(marketState.value!, currentMode),
                ),
            ],
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentMode == 'pasajero' ? Icons.person_search_rounded : Icons.directions_car_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentMode == 'pasajero' ? 'Modo Pasajero' : 'Modo Conductor',
                            style: AppTheme.bodyFont(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildWhereToBlock(context, currentMode),
                ],
              ),
            ),
          ),

          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
                if (!_isLoadingMore && !ref.read(marketTripsStreamProvider).isLoading) {
                  final currentItems = ref.read(marketTripsStreamProvider).value?.length ?? 0;
                  final currentLimit = ref.read(marketLimitProvider);
                  if (currentItems >= currentLimit) {
                    _isLoadingMore = true;
                    ref.read(marketLimitProvider.notifier).state += 20;
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) setState(() { _isLoadingMore = false; });
                    });
                  }
                }
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            width: 50,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      marketState.when(
                        data: (trips) => SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tus publicaciones y reservas, visibles en el
                              // mismo tablero (la Agenda sigue teniendo el detalle).
                              const MyActiveTripsSection(),
                              Container(
                                margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        currentMode == 'pasajero' ? Icons.directions_car : Icons.person_search,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currentMode == 'pasajero' ? 'Conductores Disponibles' : 'Pasajeros Buscando',
                                            style: AppTheme.bodyFont(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).colorScheme.primary, letterSpacing: -0.5),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Revisa el mapa y la lista inferior antes de crear tu propia publicación.',
                                            style: AppTheme.bodyFont(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500, height: 1.2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildOrderBookList(
                                isOfferList: currentMode == 'pasajero',
                                items: trips.where((t) => t.status == 'PENDING').toList(),
                                canTransact: canTransact,
                                currentMode: currentMode,
                              ),
                            ],
                          ),
                        ),
                        loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.black)))),
                        error: (e, st) => SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text(ErrorHandler.getFriendlyErrorMessage(e))))),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 50)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
