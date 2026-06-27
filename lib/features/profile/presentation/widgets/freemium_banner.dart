import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:go_router/go_router.dart';

class FreemiumBanner extends ConsumerWidget {
  const FreemiumBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final currentMode = ref.watch(boardModeProvider);
    
    // Si es pasajero o ya está suscrito, no mostrar
    if (appState.isSubscribed || appState.isPremium || currentMode == 'pasajero') {
      return const SizedBox.shrink(); 
    }

    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7), // amber-100
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conviértete en Conductor Premium', style: GoogleFonts.inter(color: const Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Por \$9.99/mes podrás ofrecer viajes ilimitados', style: GoogleFonts.inter(color: const Color(0xFFB45309), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFD97706), size: 16),
          ],
        ),
      ),
    );
  }
}
