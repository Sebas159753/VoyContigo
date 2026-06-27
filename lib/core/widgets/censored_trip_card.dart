import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

class CensoredTripCard extends ConsumerWidget {
  final TripBoardItem item;

  const CensoredTripCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStateProvider); // Solo para escuchar cambios
    final canSee = ref.read(appStateProvider.notifier).canTransact();

    final displayName = canSee 
        ? item.userName 
        : (item.userName.isNotEmpty ? '${item.userName.substring(0, 1)}***' : '***');

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
              Icon(canSee ? Icons.public : Icons.lock, size: 14, color: canSee ? Colors.green : Colors.black54),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item.origin} ➔ ${item.destination}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${item.scheduleTime.hour}:${item.scheduleTime.minute.toString().padLeft(2, '0')} • \$${item.price?.toStringAsFixed(2) ?? '0.00'}', style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: canSee ? Colors.black : Colors.black12, 
              borderRadius: BorderRadius.circular(6)
            ),
            alignment: Alignment.center,
            child: Text(
              canSee ? 'Contactar' : 'Premium para Ver', 
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: canSee ? Colors.white : Colors.black87)
            ),
          )
        ],
      ),
    );
  }
}
