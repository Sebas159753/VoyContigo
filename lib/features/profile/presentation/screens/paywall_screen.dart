import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/features/trips/domain/models/trip.dart';
import 'package:voycontigo/core/widgets/ticker_widget.dart';
import 'package:voycontigo/core/widgets/censored_trip_card.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrips = ref.watch(marketTripsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop())
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acceso VIP\npara Conductores.',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 38,
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Has agotado tus usos gratuitos. Para acceder a la demanda ilimitada de pasajeros, activa tu cuenta Premium.',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              
              // TICKER DE LA BOLSA (VIAJES CENSURADOS)
              asyncTrips.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
                error: (e, st) => const SizedBox(),
                data: (trips) {
                  final pendingOffers = trips.where((t) => t.isOffer).toList();
                  final pendingDemands = trips.where((t) => !t.isOffer).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pendingOffers.isNotEmpty) ...[
                        Text('🚗 Conductores activos AHORA:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: TickerWidget(
                            speed: 30, // px per second
                            children: pendingOffers.map((t) => CensoredTripCard(item: t)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (pendingDemands.isNotEmpty) ...[
                        Text('🧍 Pasajeros esperando AHORA:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: TickerWidget(
                            speed: 20, // slightly different speed for effect
                            children: pendingDemands.map((t) => CensoredTripCard(item: t)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildFeature('Contactos ilimitados cada mes'),
              _buildFeature('Paga tus viajes directo al conductor'),
              _buildFeature('Nosotros NUNCA cobramos comisiones'),
              _buildFeature('Cancela la suscripción cuando quieras'),

              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Acceso Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text('Facturación mensual', style: GoogleFonts.inter(color: Colors.black54, fontSize: 13)),
                      ],
                    ),
                    Text('\$15.00/mes', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: () {
                  ref.read(appStateProvider.notifier).upgradeToPremium();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Compra Exitosa! Ahora eres VIP.'))
                  );
                  context.pop();
                },
                child: Text('Activar Premium AHORA', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.black87, size: 20),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

