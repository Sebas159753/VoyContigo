import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/core/utils/date_format.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

/// Sección del tablero con los viajes activos del usuario: sus publicaciones
/// (oferta o demanda) y los viajes donde reservó asiento o aceptó llevar a
/// alguien. Da la confirmación visual de "tu viaje está en el mercado" sin
/// tener que ir a la Agenda.
class MyActiveTripsSection extends ConsumerWidget {
  const MyActiveTripsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(appStateProvider.select((s) => s.uid));
    final trips = ref.watch(upcomingScheduledTripsProvider);

    if (uid.isEmpty || trips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  size: 16, color: AppTheme.purpleDark),
              const SizedBox(width: 6),
              Text(
                'TUS VIAJES ACTIVOS',
                style: AppTheme.subtitleFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purpleDark,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.purpleLightest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${trips.length}',
                  style: AppTheme.subtitleFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.purpleDarkest,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...trips.map((t) => _MyTripCard(trip: t, myUid: uid)),
      ],
    );
  }
}

class _MyTripCard extends StatelessWidget {
  final TripBoardItem trip;
  final String myUid;

  const _MyTripCard({required this.trip, required this.myUid});

  bool get _isMine => trip.creatorUid == myUid;

  /// Etiqueta corta del rol del usuario en este viaje.
  String get _roleLabel {
    if (_isMine) return 'TU PUBLICACIÓN';
    if (trip.acceptedByUid == myUid) return 'ACEPTASTE';
    return 'RESERVADO';
  }

  /// Estado legible del viaje según quién lo mire.
  String get _statusText {
    final booked = trip.seats - trip.availableSeats;

    if (trip.status == 'EN_ROUTE') return 'En ruta 🚗';

    if (_isMine) {
      if (trip.isOffer) {
        return booked > 0
            ? '$booked/${trip.seats} asientos reservados'
            : 'Esperando pasajeros…';
      }
      if (trip.status == 'ACCEPTED' && trip.acceptedByName != null) {
        return 'Conductor: ${trip.acceptedByName}';
      }
      return 'Esperando conductor…';
    }

    if (trip.acceptedByUid == myUid) {
      return 'Llevarás a ${trip.userName}';
    }
    return 'Viajas con ${trip.userName}';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent =
        _isMine ? AppTheme.purpleDark : AppTheme.successGreen;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () => context.push('/tracking/${trip.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMine
                      ? (trip.isOffer
                          ? Icons.campaign_rounded
                          : Icons.hail_rounded)
                      : Icons.event_seat_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleLabel,
                      style: AppTheme.subtitleFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.origin.split(',').first} ➔ ${trip.destination.split(',').first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${VoyDate.shortDateTime(trip.scheduleTime)} · $_statusText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.inkMuted),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
