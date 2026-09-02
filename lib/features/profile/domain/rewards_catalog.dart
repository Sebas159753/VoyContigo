import 'package:flutter/material.dart';

/// Catálogo de recompensas del Club de Beneficios.
/// Fuente única de verdad: la pantalla de recompensas, el álbum de cromos
/// y las notificaciones de desbloqueo leen de aquí.
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

const List<RewardModel> rewardsCatalog = [
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

/// Próxima recompensa aún no alcanzada, o null si ya superó todas.
RewardModel? nextRewardFor(int completedTrips) {
  for (final reward in rewardsCatalog) {
    if (completedTrips < reward.requiredTrips) return reward;
  }
  return null;
}

/// Hito inmediatamente anterior a [reward] (0 si es la primera recompensa).
/// Sirve para dibujar la tarjeta de sellos por tramos: del hito anterior
/// al siguiente premio.
int previousMilestone(RewardModel reward) {
  int prev = 0;
  for (final r in rewardsCatalog) {
    if (r.requiredTrips < reward.requiredTrips && r.requiredTrips > prev) {
      prev = r.requiredTrips;
    }
  }
  return prev;
}

/// Recompensas que se desbloquean al pasar de [oldTrips] a [newTrips] viajes.
List<RewardModel> newlyUnlockedRewards(int oldTrips, int newTrips) {
  return rewardsCatalog
      .where((r) => oldTrips < r.requiredTrips && newTrips >= r.requiredTrips)
      .toList();
}
