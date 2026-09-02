import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

class CouponsCarousel extends ConsumerWidget {
  const CouponsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final completedTrips = appState.completedTrips;

    final coupons = [
      {
        'title': '10% Dcto en Oculto Café',
        'icon': Icons.coffee,
        'color': const Color(0xFF6F4E37),
        'requiredTrips': 5,
        'code': 'VOYOCULTO10',
      },
      {
        'title': '50% Dcto en Hogar & Hogar (Edredón)',
        'icon': Icons.bed_outlined,
        'color': const Color(0xFF3B5998),
        'requiredTrips': 15,
        'code': 'HOGAR50VOY',
      },
    ];

    return SizedBox(
      height: 140,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          final coupon = coupons[index];
          final requiredTrips = coupon['requiredTrips'] as int;
          final isUnlocked = completedTrips >= requiredTrips;
          final remaining = requiredTrips - completedTrips;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16, bottom: 8),
            decoration: BoxDecoration(
              color: isUnlocked ? (coupon['color'] as Color) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      coupon['icon'] as IconData, 
                      color: isUnlocked ? Colors.white : Colors.grey.shade500,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coupon['title'] as String,
                        style: AppTheme.bodyFont(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isUnlocked)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: coupon['color'] as Color,
                      minimumSize: const Size(double.infinity, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¡Felicidades! 🎉'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Presenta este código en el local:'),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  coupon['code'] as String,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar', style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Ver Código', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.black54, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Te faltan $remaining viajes',
                        style: AppTheme.bodyFont(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
