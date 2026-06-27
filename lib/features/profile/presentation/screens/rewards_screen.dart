import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class RewardModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int requiredTrips;
  final String code;
  final List<Color> gradientColors;

  const RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredTrips,
    required this.code,
    required this.gradientColors,
  });
}

const List<RewardModel> rewardsList = [
  RewardModel(
    id: 'cafe_gratis',
    title: 'Café Oculto Gratis',
    description: 'Disfruta de un café caliente de cortesía en Oculto Café.',
    icon: Icons.coffee_rounded,
    requiredTrips: 3,
    code: 'CAFEVOY3',
    gradientColors: [Color(0xFF8B5E3C), Color(0xFF6F4E37)],
  ),
  RewardModel(
    id: 'lavado_50',
    title: 'Lavado de Auto al 50%',
    description: 'Lavado completo interior y exterior a mitad de precio.',
    icon: Icons.local_car_wash_rounded,
    requiredTrips: 5,
    code: 'LAVADOVOY5',
    gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
  ),
  RewardModel(
    id: 'dcto_cafe_10',
    title: '10% Dcto en Oculto Café',
    description: '10% de descuento en tu consumo total.',
    icon: Icons.local_cafe_outlined,
    requiredTrips: 8,
    code: 'VOYOCULTO10',
    gradientColors: [Color(0xFFF3A152), Color(0xFFE67E22)],
  ),
  RewardModel(
    id: 'gasolina_5',
    title: 'Voucher de Gasolina \$5',
    description: 'Canjeable en estaciones de servicio afiliadas.',
    icon: Icons.local_gas_station_rounded,
    requiredTrips: 12,
    code: 'GASVOY12',
    gradientColors: [Color(0xFFF05F57), Color(0xFF3E0A28)],
  ),
  RewardModel(
    id: 'hogar_50',
    title: '50% Dcto en Hogar & Hogar',
    description: 'Descuento especial en tu próximo edredón o manta.',
    icon: Icons.bed_rounded,
    requiredTrips: 15,
    code: 'HOGAR50VOY',
    gradientColors: [Color(0xFF3A7BD5), Color(0xFF3A6073)],
  ),
  RewardModel(
    id: 'cine_gratis',
    title: 'Entrada de Cine Gratis',
    description: 'Entrada individual para cualquier función regular.',
    icon: Icons.movie_creation_rounded,
    requiredTrips: 20,
    code: 'CINEVOY20',
    gradientColors: [Color(0xFF834D9B), Color(0xFFD04ED6)],
  ),
  RewardModel(
    id: 'almuerzo_gratis',
    title: 'Combo de Almuerzo Gratis',
    description: 'Menú ejecutivo completo en restaurantes afiliados.',
    icon: Icons.lunch_dining_rounded,
    requiredTrips: 30,
    code: 'LUNCHVOY30',
    gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ),
];

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final completedTrips = appState.completedTrips;
    final redeemedRewards = appState.redeemedRewards;

    // Calcular progreso
    const int maxTarget = 30; // Objetivo máximo visible
    final double progressPercent = (completedTrips / maxTarget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          'Club de Beneficios',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabecera de Progreso Premium
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '¡Suma viajes y gana regalos!',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cada viaje completado como conductor o pasajero te acerca a tu próxima recompensa.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: CircularProgressIndicator(
                          value: progressPercent,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.shade100,
                          color: AppTheme.electricBlue,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completedTrips',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            completedTrips == 1 ? 'viaje' : 'viajes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (completedTrips < maxTarget)
                    Text(
                      'Te faltan ${maxTarget - completedTrips} viajes para el premio máximo 🎁',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    )
                  else
                    Text(
                      '🏆 ¡Has completado todos los niveles de recompensa!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Lista de Premios
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premios Disponibles',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...rewardsList.map((reward) {
                    final bool isUnlocked = completedTrips >= reward.requiredTrips;
                    final bool isRedeemed = redeemedRewards.contains(reward.id);

                    return _buildRewardCard(context, ref, reward, isUnlocked, isRedeemed, completedTrips);
                  }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCard(
    BuildContext context,
    WidgetRef ref,
    RewardModel reward,
    bool isUnlocked,
    bool isRedeemed,
    int completedTrips,
  ) {
    final remaining = reward.requiredTrips - completedTrips;
    
    // Configuración visual según estado
    List<Color> cardGradient;
    Color iconColor;
    Color textColor;
    Color descColor;
    
    if (isRedeemed) {
      cardGradient = [Colors.grey.shade300, Colors.grey.shade400];
      iconColor = Colors.grey.shade600;
      textColor = Colors.grey.shade700;
      descColor = Colors.grey.shade600;
    } else if (isUnlocked) {
      cardGradient = reward.gradientColors;
      iconColor = Colors.white;
      textColor = Colors.white;
      descColor = Colors.white.withOpacity(0.9);
    } else {
      cardGradient = [Colors.white, Colors.white];
      iconColor = Colors.grey.shade400;
      textColor = Colors.black87;
      descColor = Colors.black54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? Colors.transparent : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono del Premio
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              reward.icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Detalles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontSize: 16,
                    decoration: isRedeemed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: descColor,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Acción inferior
                if (isRedeemed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 14, color: Colors.black87),
                        const SizedBox(width: 4),
                        Text(
                          'Canjeado',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isUnlocked)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: reward.gradientColors.last,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(100, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showRedeemDialog(context, ref, reward),
                    child: Text(
                      'Canjear Recompensa',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Faltan $remaining viajes (Nivel: ${reward.requiredTrips})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context, WidgetRef ref, RewardModel reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: reward.gradientColors.first.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(reward.icon, color: reward.gradientColors.first, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Canje Exitoso! 🎉',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.black87),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Presenta este cupón en el local adherido para reclamar tu beneficio:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.black54, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 24),
              
              // Código de cupón
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Text(
                  reward.code,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Simulación realista de Código de Barras para UI espectacular
              Column(
                children: [
                  Container(
                    height: 50,
                    width: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        22,
                        (index) => Container(
                          width: (index % 3 == 0) ? 4.0 : ((index % 5 == 0) ? 1.5 : 2.5),
                          color: index % 7 == 0 ? Colors.transparent : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '*${reward.code.hashCode.abs()}*',
                    style: GoogleFonts.sourceCodePro(fontSize: 10, color: Colors.black45, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Registrar canje en Firestore
                await ref.read(appStateProvider.notifier).redeemReward(reward.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text(
                'Cerrar y Marcar Canjeado',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
