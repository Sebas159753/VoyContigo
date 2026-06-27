import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/core/widgets/ticker_widget.dart';
import 'package:voycontigo/core/widgets/censored_trip_card.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrips = ref.watch(marketTripsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MINI TICKER SIMPLIFICADO ELIMINADO
              Text(
                'Elige tu rol\npara hoy.',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 32,
                  letterSpacing: -1.0,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 32),
              _buildRoleCard(
                context,
                title: 'Pasajero',
                subtitle: 'Quiero buscar o solicitar un viaje',
                icon: Icons.person_search_rounded,
                isPassenger: true,
                onTap: () {
                  ref.read(boardModeProvider.notifier).state = 'pasajero';
                  context.push('/tablero');
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: 'Conductor',
                subtitle: 'Quiero publicar o llevar a alguien',
                icon: Icons.directions_car_rounded,
                isPassenger: false,
                onTap: () {
                  final appState = ref.read(appStateProvider);
                  if (!appState.isVerified) {
                    context.push('/verify');
                  } else {
                    ref.read(boardModeProvider.notifier).state = 'conductor';
                    context.push('/tablero');
                  }
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required bool isPassenger,
    required VoidCallback onTap
  }) {
    final gradient = isPassenger 
        ? LinearGradient(colors: [AppTheme.electricBlue, AppTheme.electricBlue.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : LinearGradient(colors: [AppTheme.driverNavy, AppTheme.driverNavy.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    
    final shadowColor = isPassenger ? AppTheme.electricBlue.withOpacity(0.3) : AppTheme.driverNavy.withOpacity(0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
