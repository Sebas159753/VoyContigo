import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/core/services/stripe_service.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _subscribe() async {
    setState(() => _isLoading = true);
    
    final success = await StripeService.subscribeDriver(context);
    
    if (success && mounted) {
      ref.read(appStateProvider.notifier).upgradeToSubscribed();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Suscripción exitosa! Ahora eres un Conductor Premium.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(); // Regresar a la pantalla anterior
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Suscripción de Conductor',
          style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.stars_rounded, size: 80, color: AppTheme.tommyNavy),
              const SizedBox(height: 24),
              Text(
                'Conviértete en Conductor Premium',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Publica tus viajes y comparte gastos con otros pasajeros. Por solo \$9.99 al mes, tendrás acceso ilimitado para ofrecer viajes en VoyContigo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.tommyNavy.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      '\$9.99',
                      style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'por mes',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tommyNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _subscribe,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Suscribirse Ahora',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'Puedes cancelar en cualquier momento.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
