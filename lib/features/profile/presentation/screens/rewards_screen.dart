import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/profile/domain/rewards_catalog.dart';
import 'package:voycontigo/features/profile/presentation/widgets/scratch_card.dart';
import 'package:voycontigo/features/profile/presentation/widgets/stamp_card.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

/// Club de Beneficios: tarjeta de sellos (papeleta) + álbum de cromos +
/// cupones raspa y gana.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final completedTrips = appState.completedTrips;
    final redeemedRewards = appState.redeemedRewards;

    // Premios listos para raspar (desbloqueados y sin canjear).
    final readyRewards = rewardsCatalog
        .where((r) =>
            completedTrips >= r.requiredTrips &&
            !redeemedRewards.contains(r.id))
        .toList();
    final nextReward = nextRewardFor(completedTrips);

    return Scaffold(
      backgroundColor: AppTheme.subtleGray,
      appBar: AppBar(
        title: const Text('Club de Beneficios'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // ------------------------------------------------ Cabecera
          Text(
            'Junta sellos, gana premios',
            textAlign: TextAlign.center,
            style: AppTheme.titleFont(fontSize: 24, color: AppTheme.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada viaje completado, como conductor o pasajero, estampa un sello en tu tarjeta.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyFont(
              fontSize: 13,
              color: AppTheme.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_rounded,
                      size: 18, color: AppTheme.purpleDark),
                  const SizedBox(width: 6),
                  Text(
                    completedTrips == 1
                        ? '1 viaje completado'
                        : '$completedTrips viajes completados',
                    style: AppTheme.subtitleFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ------------------------------------------ Cupones listos
          if (readyRewards.isNotEmpty) ...[
            _ReadyBanner(
              count: readyRewards.length,
              onTap: () => _openScratchSheet(context, ref, readyRewards.first),
            ),
            const SizedBox(height: 16),
          ],

          // ------------------------------------------ Tarjeta de sellos
          if (nextReward != null)
            StampCard(
              reward: nextReward,
              completedTrips: completedTrips,
              milestoneStart: previousMilestone(nextReward),
            )
          else
            _CollectionCompleteCard(),
          const SizedBox(height: 28),

          // ------------------------------------------ Álbum de cromos
          Text(
            'MI COLECCIÓN',
            style: AppTheme.subtitleFont(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca un cromo desbloqueado para raspar tu cupón ✨',
            style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemCount: rewardsCatalog.length,
            itemBuilder: (context, index) {
              final reward = rewardsCatalog[index];
              final isUnlocked = completedTrips >= reward.requiredTrips;
              final isRedeemed = redeemedRewards.contains(reward.id);
              return _CollectibleCard(
                reward: reward,
                completedTrips: completedTrips,
                isUnlocked: isUnlocked,
                isRedeemed: isRedeemed,
                onTap: () {
                  if (isRedeemed) {
                    _showCodeDialog(context, reward);
                  } else if (isUnlocked) {
                    _openScratchSheet(context, ref, reward);
                  } else {
                    final remaining = reward.requiredTrips - completedTrips;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(
                          remaining == 1
                              ? '¡Solo te falta 1 viaje para este premio! 🚗'
                              : 'Te faltan $remaining viajes para este premio 🚗',
                        ),
                      ));
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Raspa y gana
  // ---------------------------------------------------------------------------

  void _openScratchSheet(
      BuildContext context, WidgetRef ref, RewardModel reward) {
    bool revealed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '¡Raspa y gana!',
                      style: AppTheme.titleFont(fontSize: 24, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Frota la tarjeta con tu dedo y descubre tu cupón:\n${reward.title}',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont(
                        fontSize: 13,
                        color: AppTheme.inkMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ScratchCard(
                      height: 215,
                      coverGradient: reward.gradientColors,
                      onRevealed: () => setSheetState(() => revealed = true),
                      child: _CouponContent(reward: reward),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: revealed
                          ? Column(
                              key: const ValueKey('actions'),
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Marcar como canjeado'),
                                    onPressed: () async {
                                      await ref
                                          .read(appStateProvider.notifier)
                                          .redeemReward(reward.id);
                                      if (sheetCtx.mounted) {
                                        Navigator.pop(sheetCtx);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(const SnackBar(
                                            content: Text(
                                                '¡Cupón canjeado! Preséntalo en el local 🎉'),
                                          ));
                                      }
                                    },
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  child: const Text('Guardar para después'),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('hint'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app_rounded,
                                    color: AppTheme.inkMuted, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Usa tu dedo para raspar la tarjeta',
                                  style: AppTheme.bodyFont(
                                    fontSize: 13,
                                    color: AppTheme.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Cupón ya canjeado: permite volver a ver el código.
  void _showCodeDialog(BuildContext context, RewardModel reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: reward.gradientColors.first.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(reward.icon,
                  color: reward.gradientColors.first, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              reward.title,
              textAlign: TextAlign.center,
              style: AppTheme.titleFont(fontSize: 20, color: AppTheme.ink),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Este cupón ya fue canjeado. Tu código era:',
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont(fontSize: 13, color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 16),
            _CodeBox(code: reward.code),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets internos
// -----------------------------------------------------------------------------

/// Aviso destacado cuando hay cupones desbloqueados sin raspar.
class _ReadyBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ReadyBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.purpleDark, AppTheme.purpleMedium],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.purpleDark.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '¡Tienes 1 cupón listo!'
                          : '¡Tienes $count cupones listos!',
                      style: AppTheme.subtitleFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toca aquí para raspar y descubrir tu premio',
                      style: AppTheme.bodyFont(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta final cuando el usuario ya superó todos los niveles.
class _CollectionCompleteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.purpleDarkest, AppTheme.purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            '¡Colección completa!',
            style: AppTheme.titleFont(fontSize: 22, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Desbloqueaste todos los premios del club. Muy pronto habrá nuevas recompensas.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyFont(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cromo del álbum: silueta gris si está bloqueado, brillante si está listo
/// para raspar y con sello "CANJEADO" si ya se usó.
class _CollectibleCard extends StatelessWidget {
  final RewardModel reward;
  final int completedTrips;
  final bool isUnlocked;
  final bool isRedeemed;
  final VoidCallback onTap;

  const _CollectibleCard({
    required this.reward,
    required this.completedTrips,
    required this.isUnlocked,
    required this.isRedeemed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShiny = isUnlocked && !isRedeemed;

    final Decoration decoration;
    if (isShiny) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: reward.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: reward.gradientColors.first.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );
    } else if (isRedeemed) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      );
    } else {
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      );
    }

    final Color titleColor =
        isShiny || isRedeemed ? Colors.white : AppTheme.ink;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isShiny || isRedeemed
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.subtleGray,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    reward.icon,
                    size: 30,
                    color: isShiny || isRedeemed
                        ? Colors.white
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reward.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                if (isShiny)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✨ Raspa y gana',
                      style: AppTheme.subtitleFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: reward.gradientColors.last,
                      ),
                    ),
                  )
                else if (isRedeemed)
                  const SizedBox(height: 26)
                else
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (completedTrips / reward.requiredTrips)
                              .clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppTheme.subtleGray,
                          color: AppTheme.purpleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '$completedTrips/${reward.requiredTrips} viajes',
                            style: AppTheme.bodyFont(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            // Sello CANJEADO cruzado sobre el cromo usado.
            if (isRedeemed)
              Positioned.fill(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CANJEADO',
                        style: AppTheme.subtitleFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contenido del cupón que queda oculto bajo la capa de raspado.
class _CouponContent extends StatelessWidget {
  final RewardModel reward;

  const _CouponContent({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBFF),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TU CÓDIGO',
            style: AppTheme.subtitleFont(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          _CodeBox(code: reward.code),
          const SizedBox(height: 14),
          _Barcode(code: reward.code),
          const SizedBox(height: 8),
          Text(
            'Presenta este código en el local adherido',
            style: AppTheme.bodyFont(fontSize: 11, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String code;

  const _CodeBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: GoogleFonts.sourceCodePro(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}

/// Simulación visual de código de barras.
class _Barcode extends StatelessWidget {
  final String code;

  const _Barcode({required this.code});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          width: 170,
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
          '*${code.hashCode.abs()}*',
          style: GoogleFonts.sourceCodePro(
            fontSize: 10,
            color: Colors.black45,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
