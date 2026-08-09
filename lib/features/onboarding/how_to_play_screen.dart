import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../widgets/widgets.dart';

/// Static rules reference (design doc §6 "Nasıl oynanır?").
///
/// Pure content: it explains the flow the server runs, it never starts,
/// simulates or predicts a game.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const List<_Step> _steps = [
    _Step(
      icon: Icons.groups_rounded,
      title: 'Oyuncular toplanır',
      body: 'Kurucu bir oturum açar, diğerleri oturum kodu ve şifreyle katılır. '
          'Yeterli oyuncu olunca kurucu oyunu başlatır.',
    ),
    _Step(
      icon: Icons.style_rounded,
      title: 'Roller dağıtılır',
      body: 'Roller sunucu tarafından gizlice dağıtılır. Kendi rolünü '
          'kartına dokunarak görürsün; kimse başkasının rolünü göremez.',
    ),
    _Step(
      icon: Icons.nightlight_round,
      title: 'Gece',
      body: 'Vampirler bir kurban seçer. Doktor birini korur, medyum bilgi '
          'toplar. Rolü olmayanlar gecede pasiftir.',
    ),
    _Step(
      icon: Icons.wb_sunny_rounded,
      title: 'Gündüz',
      body: 'Köy gece olanları konuşur. Herkes şüphelendiği oyuncuya oy verir.',
    ),
    _Step(
      icon: Icons.how_to_vote_rounded,
      title: 'Oylama',
      body: 'En çok oyu alan oyuncu elenir ve rolü açığa çıkar. '
          'Süre dolduğunda oylama sunucu tarafından kapatılır.',
    ),
    _Step(
      icon: Icons.emoji_events_rounded,
      title: 'Kazanma koşulu',
      body: 'Tüm vampirler elenirse köy kazanır. Vampirler sayıca üstün hale '
          'gelirse vampirler kazanır.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nasıl Oynanır?')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text('OYUN AKIŞI', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.md),
                for (final step in _steps) ...[
                  step,
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('ROLLER', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.md),
                for (final roleId in RoleVisuals.selectableRoleIds) ...[
                  GameRoleCard(
                    roleId: roleId,
                    showSelectionCheck: false,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Hangi rollerin oyunda olacağını oyun kurucusu belirler.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Step({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.14),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
