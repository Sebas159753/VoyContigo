import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/presentation/widgets/dynamic_trip_card.dart';
import 'package:voycontigo/core/utils/error_handler.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrips = ref.watch(myTripsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text('Mis Viajes', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: asyncTrips.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (e, st) => Center(child: Text(ErrorHandler.getFriendlyErrorMessage(e), style: const TextStyle(color: Colors.black54))),
        data: (allTrips) {
          final currentUserUid = ref.read(appStateProvider).uid;

          // Filtrar todos los viajes del usuario (incluyendo los activos que quitamos del tablero)
          final historyTrips = allTrips.where((t) => 
              t.creatorUid == currentUserUid || 
              t.acceptedByUid == currentUserUid ||
              t.passengers.any((p) => p['uid'] == currentUserUid)
          ).toList();

          // Filtrar las publicaciones pendientes si ya están en el tablero para no duplicar (opcional)
          // Pero para un historial real, está bien mostrarlos todos.
          // Solo ordenamos por fecha, más recientes primero
          historyTrips.sort((a, b) => b.scheduleTime.compareTo(a.scheduleTime));

          if (historyTrips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 24),
                    Text('Tu historial está vacío', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Tus próximos viajes o los que ya completaste aparecerán aquí.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyTrips.length,
            itemBuilder: (context, index) {
              final item = historyTrips[index];
              return DynamicTripCard(
                item: item,
                isOfferList: item.isOffer,
                isReadOnly: true,
                isCensored: false,
                onActionPressed: () {},
                onCancelPressed: (item.status == 'PENDING' && item.creatorUid == currentUserUid && item.acceptedByUid == null && item.passengers.isEmpty) 
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancelar Publicación'),
                          content: const Text('¿Estás seguro de que quieres cancelar este viaje? Se eliminará permanentemente.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: const Text('Sí, cancelar')
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance.collection('trips').doc(item.id).delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación cancelada exitosamente'), backgroundColor: Colors.black));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: \$e'), backgroundColor: Colors.red));
                          }
                        }
                      }
                    }
                  : null,
              );
            },
          );
        },
      ),
    );
  }
}

