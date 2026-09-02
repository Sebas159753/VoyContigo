import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/profile/domain/rewards_catalog.dart';

/// Tarjeta de sellos estilo cafetería/supermercado: muestra el tramo hacia el
/// próximo premio. Cada viaje completado estampa un sello; el último cupo es
/// el premio (🎁).
class StampCard extends StatelessWidget {
  final RewardModel reward;
  final int completedTrips;

  /// Hito del premio anterior (0 si es el primero). El tramo de sellos va de
  /// [milestoneStart] a `reward.requiredTrips`.
  final int milestoneStart;

  const StampCard({
    super.key,
    required this.reward,
    required this.completedTrips,
    required this.milestoneStart,
  });

  @override
  Widget build(BuildContext context) {
    final int slots = reward.requiredTrips - milestoneStart;
    final int filled = (completedTrips - milestoneStart).clamp(0, slots);
    final int remaining = reward.requiredTrips - completedTrips;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.purpleDarkest, AppTheme.purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purpleDarkest.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(reward.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRÓXIMO PREMIO',
                      style: AppTheme.subtitleFont(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.purpleLightest,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reward.title,
                      style: AppTheme.titleFont(fontSize: 19, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Sellos del tramo actual.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(slots, (i) {
              final bool isPrize = i == slots - 1;
              final bool isFilled = i < filled;
              return _StampSlot(
                index: i,
                isFilled: isFilled,
                isPrize: isPrize,
                label: '${milestoneStart + i + 1}',
              );
            }),
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: slots == 0 ? 0 : filled / slots,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.18),
              color: AppTheme.purpleLightest,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remaining == 1
                ? '¡Solo 1 viaje más y es tuyo! 🎉'
                : 'Llevas $filled de $slots sellos · te faltan $remaining viajes',
            style: AppTheme.bodyFont(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _StampSlot extends StatelessWidget {
  final int index;
  final bool isFilled;
  final bool isPrize;
  final String label;

  const _StampSlot({
    required this.index,
    required this.isFilled,
    required this.isPrize,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 46;

    if (isFilled) {
      // Sello estampado, con leve rotación para que parezca tinta real.
      final angle = (((index * 37) % 24) - 12) * math.pi / 180;
      return Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car_rounded,
            color: AppTheme.purpleDarkest,
            size: 26,
          ),
        ),
      );
    }

    // Cupo vacío: círculo punteado con el número de viaje (o 🎁 si es el premio).
    return CustomPaint(
      painter: _DashedCirclePainter(color: Colors.white.withOpacity(0.45)),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: isPrize
              ? const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 24)
              : Text(
                  label,
                  style: AppTheme.subtitleFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashCount = 14;
    const gapRatio = 0.45;
    final dashAngle = 2 * math.pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        dashAngle * (1 - gapRatio),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
