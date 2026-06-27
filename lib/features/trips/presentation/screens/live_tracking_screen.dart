import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/data/trip_repository.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/presentation/widgets/rating_dialog.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;

  const LiveTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  bool _hasShownRating = false;
  double? _targetLat;
  double? _targetLng;
  bool _etaTriggered = false;
  late final Stream<DocumentSnapshot> _tripStream;

  @override
  void initState() {
    super.initState();
    _tripStream = FirebaseFirestore.instance.collection('trips').doc(widget.tripId).snapshots();
    _fetchTargetLocation();
    _checkPermissionsAndStartTracking();
  }

  Future<void> _fetchTargetLocation() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _targetLat = data['originLat'];
        _targetLng = data['originLng'];
        _etaTriggered = data['etaTriggered'] ?? false;
      }
    } catch (e) {
      debugPrint("Error fetching target location: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    // Averiguar si el usuario actual es el conductor de este viaje
    final docSnapshot = await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).get();
    if (!docSnapshot.exists) return;
    
    final tripData = docSnapshot.data()!;
    final trip = TripBoardItem.fromFirestore(docSnapshot.id, tripData);
    // Obtener UID
    final currentUid = ref.read(appStateProvider).uid;
    
    bool isDriverCheck = false;
    if (trip.isOffer) {
      isDriverCheck = trip.creatorUid == currentUid;
    } else {
      isDriverCheck = trip.acceptedByUid == currentUid;
    }

    if (isDriverCheck) {
      // Pedir permisos de ubicación
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // Iniciar el stream de GPS y actualizar Firestore
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Actualizar cada 10 metros
        ),
      ).listen((Position position) {
        Map<String, dynamic> updates = {
          'currentLat': position.latitude,
          'currentLng': position.longitude,
        };

        if (_targetLat != null && _targetLng != null && !_etaTriggered) {
          final distance = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            _targetLat!, _targetLng!
          );
          
          if (distance <= 2500) { // aprox 2.5km (5 min)
            updates['etaTriggered'] = true;
            _etaTriggered = true;
          }
        }

        ref.read(tripRepositoryProvider).updateTripData(widget.tripId, updates);
        
        // Mover la cámara a la nueva posición
        _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
      });
    }
  }

  Future<void> _triggerPanic(double? fallbackLat, double? fallbackLng) async {
    final appState = ref.read(appStateProvider);
    final emergencyPhone = appState.emergencyPhone;

    double? lat = fallbackLat;
    double? lng = fallbackLng;

    // Intentar obtener la ubicación en tiempo real del dispositivo actual del usuario
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (e) {
      debugPrint("Error fetching current device location for SOS: $e");
    }

    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación GPS.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 1. Guardar log silencioso
    try {
      await FirebaseFirestore.instance.collection('panic_alerts').add({
        'tripId': widget.tripId,
        'uid': appState.uid,
        'userName': appState.userName,
        'lat': lat,
        'lng': lng,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error writing panic alert: $e");
    }

    if (emergencyPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configura tu Contacto de Emergencia en Perfil > Contacto de Emergencia', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 2. Formatear número para Ecuador (quitar el 0 inicial si existe y añadir código)
    String cleanPhone = emergencyPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    // WhatsApp prefiere sin el +, solo el código de país. Ej: 593999...
    String waPhone = "593$cleanPhone";
    // SMS prefiere el +
    String smsPhone = "+593$cleanPhone";

    final message = "¡AYUDA! Estoy en un viaje de VoyContigo y me siento en peligro. Mi ubicación: https://maps.google.com/?q=$lat,$lng";
    final url = Uri.parse("sms:$smsPhone?body=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to whatsapp if sms fails
        final waUrl = Uri.parse("https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl);
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir SMS ni WhatsApp')));
           }
        }
      }
    } catch (e) {
      debugPrint("Error launching SOS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _tripStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Seguimiento en Vivo', style: GoogleFonts.inter(letterSpacing: -0.5)),
              backgroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Seguimiento en Vivo', style: GoogleFonts.inter(letterSpacing: -0.5)),
              backgroundColor: Colors.white,
            ),
            body: const Center(child: Text('Viaje no encontrado')),
          );
        }

        final trip = TripBoardItem.fromFirestore(snapshot.data!.id, data);
        final currentLat = trip.currentLat;
        final currentLng = trip.currentLng;

        LatLng initialCenter = const LatLng(-0.510368, -78.568390); // Machachi default
        if (currentLat != null && currentLng != null) {
          initialCenter = LatLng(currentLat, currentLng);
        }

        final currentUid = ref.read(appStateProvider).uid;
        bool isDriver = false;
        if (trip.isOffer) {
          isDriver = trip.creatorUid == currentUid;
        } else {
          isDriver = trip.acceptedByUid == currentUid;
        }

        // Si están probando con la misma cuenta para creador y aceptado:
        if (trip.creatorUid == trip.acceptedByUid) {
           // En pruebas propias, la lógica falla porque eres ambos.
           // Forzaremos el rol basado en si era oferta o no para que veas el ticket original.
           isDriver = trip.isOffer; 
        }

        bool isParticipant = false;
        if (trip.isOffer) {
          isParticipant = trip.creatorUid == currentUid || trip.passengers.any((p) => p['uid'] == currentUid);
        } else {
          isParticipant = trip.creatorUid == currentUid || trip.acceptedByUid == currentUid;
        }

        // Single device testing exception
        if (trip.creatorUid == trip.acceptedByUid) {
          isParticipant = true;
        }

        if (!isParticipant && trip.status != 'CANCELLED' && trip.status != 'COMPLETED') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ya no formas parte de este viaje.')),
              );
              context.go('/tablero');
            }
          });
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        if (trip.status == 'CANCELLED') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('El viaje ha sido cancelado.'), backgroundColor: Colors.red),
              );
              context.go('/tablero');
            }
          });
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        if (trip.status == 'COMPLETED' && !_hasShownRating) {
          _hasShownRating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            List<Map<String, String>> usersToRate = [];
            
            if (trip.isOffer) {
              if (isDriver) {
                // Conductor califica a TODOS los pasajeros secuencialmente
                for (var p in trip.passengers) {
                  final pUid = p['uid']?.toString() ?? '';
                  final pName = p['name']?.toString() ?? 'Pasajero';
                  if (pUid.isNotEmpty) {
                    usersToRate.add({'uid': pUid, 'name': pName});
                  }
                }
              } else {
                // Pasajero califica al conductor
                usersToRate.add({'uid': trip.creatorUid, 'name': trip.userName});
              }
            } else {
              if (isDriver) {
                // Conductor califica al pasajero demandante
                usersToRate.add({'uid': trip.creatorUid, 'name': trip.userName});
              } else {
                // Pasajero califica al conductor
                usersToRate.add({'uid': trip.acceptedByUid ?? '', 'name': trip.acceptedByName ?? 'Conductor'});
              }
            }

            for (var user in usersToRate) {
              if (mounted && user['uid']!.isNotEmpty) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => RatingDialog(
                    targetUserId: user['uid']!,
                    targetUserName: user['name']!,
                  ),
                );
              }
            }
            
            if (mounted) {
              context.go('/tablero');
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Seguimiento en Vivo', style: GoogleFonts.inter(letterSpacing: -0.5)),
            backgroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                tooltip: 'Cancelar Viaje',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancelar Viaje'),
                      content: Text(
                        (trip.isOffer && isDriver) || (!trip.isOffer && !isDriver)
                            ? '¿Estás seguro de que deseas abortar este viaje? Se cancelará para todos.'
                            : '¿Estás seguro de que deseas cancelar tu reserva?'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('No, mantener', style: TextStyle(color: Colors.black54)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            if (trip.isOffer) {
                              if (isDriver) {
                                // Conductor cancela la oferta completa
                                await ref.read(tripRepositoryProvider).updateTripStatus(widget.tripId, 'CANCELLED');
                              } else {
                                // Pasajero cancela su reserva
                                final myData = trip.passengers.firstWhere((p) => p['uid'] == currentUid, orElse: () => <String, dynamic>{});
                                final int seats = myData['seats'] ?? 1;
                                if (myData.isNotEmpty) {
                                  await ref.read(tripRepositoryProvider).cancelPassengerReservation(
                                    tripId: widget.tripId,
                                    uid: currentUid,
                                    passengerData: myData,
                                    seatsToRestore: seats,
                                  );
                                }
                              }
                            } else {
                              if (!isDriver) {
                                // Pasajero creador cancela la demanda completa
                                await ref.read(tripRepositoryProvider).updateTripStatus(widget.tripId, 'CANCELLED');
                              } else {
                                // Conductor cancela su aceptación de la demanda
                                await ref.read(tripRepositoryProvider).updateTripData(widget.tripId, {
                                  'status': 'PENDING',
                                  'acceptedByUid': FieldValue.delete(),
                                  'acceptedByName': FieldValue.delete(),
                                });
                              }
                            }
                          },
                          child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.voycontigo.voycontigo',
                  ),
                  if (currentLat != null && currentLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(currentLat, currentLng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (!isDriver && (currentLat == null || currentLng == null))
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Text(
                      'Esperando ubicación del conductor...',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: trip.status == 'COMPLETED'
            ? const SizedBox.shrink()
            : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isDriver) ...[
                if (trip.status != 'EN_ROUTE')
                  FloatingActionButton.extended(
                    heroTag: 'start_btn',
                    backgroundColor: AppTheme.tommyNavy,
                    onPressed: () async {
                      await ref.read(tripRepositoryProvider).updateTripStatus(widget.tripId, 'EN_ROUTE');
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text('Iniciar Viaje', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else
                  FloatingActionButton.extended(
                    heroTag: 'finish_btn',
                    backgroundColor: AppTheme.tommyRed,
                    onPressed: () async {
                      try {
                        await ref.read(tripRepositoryProvider).completeTrip(widget.tripId);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al finalizar viaje: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.flag, color: Colors.white),
                    label: Text('Finalizar Viaje', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 12),
              ],
              FloatingActionButton.extended(
                heroTag: 'chat_btn',
                backgroundColor: AppTheme.tommyNavy,
                onPressed: () => context.push('/chat/${widget.tripId}'),
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: Text('Abrir Chat', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  elevation: 6,
                ),
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mantén presionado SOS para enviar alerta'))
                   );
                },
                onLongPress: () {
                  _triggerPanic(currentLat, currentLng);
                },
                icon: const Icon(Icons.shield, color: Colors.white),
                label: Text('S.O.S', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
