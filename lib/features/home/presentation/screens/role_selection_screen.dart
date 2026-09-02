import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                'ELIGE TU ROL\nPARA HOY',
                style: AppTheme.titleFont(
                  color: AppTheme.ink,
                  fontSize: 30,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 32),
              _buildRoleCard(
                context,
                title: 'PASAJERO',
                subtitle: 'Quiero buscar o solicitar\nun viaje',
                iconPath: 'assets/passenger_icon.png', // Fallback to icon if not using images
                icon: Icons.person_outline_rounded,
                isPassenger: true,
                onTap: () {
                  ref.read(boardModeProvider.notifier).state = 'pasajero';
                  context.push('/tablero');
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: 'CONDUCTOR',
                subtitle: 'Quiero publicar o llevar a\nalguien',
                iconPath: 'assets/driver_icon.png', // Fallback to icon
                icon: Icons.directions_car_outlined,
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
    String? iconPath,
    required bool isPassenger,
    required VoidCallback onTap
  }) {
    final backgroundColor = isPassenger ? AppTheme.purpleDarkest : AppTheme.purpleMedium;
    final iconBgColor = isPassenger ? AppTheme.purpleDark : AppTheme.purpleLightest;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyFont(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodyFont(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ],
        ),
      ),
    );
  }
}
