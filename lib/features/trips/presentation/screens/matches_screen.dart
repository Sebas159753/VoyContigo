import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/presentation/widgets/dynamic_trip_card.dart';
import 'package:voycontigo/core/utils/error_handler.dart';
import 'package:voycontigo/features/trips/data/trip_repository.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final currentUid = ref.watch(appStateProvider).uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Coincidencias', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (e, st) => Center(child: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome, size: 64, color: Colors.amber[600]),
                    ),
                    const SizedBox(height: 24),
                    Text('Sin coincidencias aún', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Publica un viaje en el tablero y nuestro sistema te emparejará automáticamente con personas compatibles.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final isOfferSide = match['offerUserId'] == currentUid;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.flash_on, color: Colors.amber[800], size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isOfferSide ? '¡Encontramos un pasajero!' : '¡Encontramos un conductor!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.black87, letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Revisa el perfil de la contraparte y confirma el viaje antes de que se llene o cambien los planes.',
                      style: GoogleFonts.inter(color: Colors.black54, fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () {
                          final targetTripId = isOfferSide ? match['demandTripId'] : match['offerTripId'];
                          if (targetTripId != null) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _MatchDetailBottomSheet(
                                targetTripId: targetTripId,
                                matchId: match['id'],
                                isOfferSide: isOfferSide,
                              ),
                            );
                          } else {
                            ErrorHandler.showErrorSnackBar(context, 'No se pudo encontrar el trato.');
                          }
                        },
                        child: const Text('Ver Detalles'),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MatchDetailBottomSheet extends ConsumerStatefulWidget {
  final String targetTripId;
  final String matchId;
  final bool isOfferSide;

  const _MatchDetailBottomSheet({
    required this.targetTripId,
    required this.matchId,
    required this.isOfferSide,
  });

  @override
  ConsumerState<_MatchDetailBottomSheet> createState() => _MatchDetailBottomSheetState();
}

class _MatchDetailBottomSheetState extends ConsumerState<_MatchDetailBottomSheet> {
  TripBoardItem? trip;
  bool isLoading = true;
  bool isAccepting = false;

  @override
  void initState() {
    super.initState();
    _fetchTrip();
  }

  Future<void> _fetchTrip() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(widget.targetTripId).get();
      if (doc.exists) {
        setState(() {
          trip = TripBoardItem.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _acceptMatch() async {
    if (trip == null) return;
    
    final appState = ref.read(appStateProvider);
    final isDriverAction = !trip!.isOffer;
    final canCreate = ref.read(appStateProvider.notifier).canTransact(isDriverAction: isDriverAction);
    
    if (!canCreate && isDriverAction) {
       context.push('/subscription');
       return;
    }
    
    setState(() => isAccepting = true);
    
    try {
      if (trip!.isOffer) {
        final passengerData = {
          'uid': appState.uid,
          'name': appState.userName,
          'phone': appState.emergencyPhone,
          'seats': 1,
        };
        await ref.read(tripRepositoryProvider).joinTripAsPassenger(
          tripId: trip!.id,
          uid: appState.uid,
          passengerData: passengerData,
          seatsToBook: 1,
          matchId: widget.matchId,
        );
      } else {
        await ref.read(tripRepositoryProvider).acceptTripAsDriver(
          tripId: trip!.id,
          uid: appState.uid,
          userName: appState.userName,
          matchId: widget.matchId,
        );
      }
      
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(context, '¡Viaje Aceptado!');
        context.pop(); 
        context.push('/tracking/${trip!.id}');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
        setState(() => isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDoAction = trip != null ? (trip!.isOffer ? true : ref.watch(appStateProvider.notifier).canTransact(isDriverAction: true)) : true;
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: CircularProgressIndicator(color: Colors.black)),
            )
          else if (trip == null)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text('El viaje ya no está disponible.', style: GoogleFonts.inter(color: Colors.black54)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  DynamicTripCard(
                    item: trip!,
                    isOfferList: trip!.isOffer,
                    isReadOnly: false,
                    isCensored: !canDoAction,
                    onActionPressed: isAccepting ? () {} : _acceptMatch,
                  ),
                  if (isAccepting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
