import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Closing "SONUÇ" block of the night resolution (spec §1.3 / §5).
///
/// [deathLines] / [savedLines] are already-localized one-liners such as
/// "Ahmet öldü." / "Ahmet hayatta kaldı."; when both are empty the card falls
/// back to "Kimse ölmedi.".
class ActionResultCard extends StatelessWidget {
  final List<String> deathLines;
  final List<String> savedLines;

  const ActionResultCard({
    super.key,
    this.deathLines = const [],
    this.savedLines = const [],
  });

  bool get _nobodyDied => deathLines.isEmpty;

  @override
  Widget build(BuildContext context) {
    final accent = _nobodyDied ? AppColors.success : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.5)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SONUÇ', style: AppTextStyles.label.copyWith(color: accent)),
          const SizedBox(height: AppSpacing.sm),
          for (final line in deathLines)
            _ResultLine(
              icon: Icons.close_rounded,
              color: AppColors.danger,
              text: line,
            ),
          for (final line in savedLines)
            _ResultLine(
              icon: Icons.check_rounded,
              color: AppColors.success,
              text: line,
            ),
          if (deathLines.isEmpty && savedLines.isEmpty)
            const _ResultLine(
              icon: Icons.check_rounded,
              color: AppColors.success,
              text: 'Kimse ölmedi.',
            ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ResultLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
