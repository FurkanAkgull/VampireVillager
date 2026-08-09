import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import 'game_timer.dart';

/// Top-of-screen phase banner: night/day badge, round number, countdown and a
/// short Turkish instruction line ("what do I do now?" — design rule 3).
///
/// Purely presentational: the phase, round and remaining time all come from the
/// server-driven state; this widget never counts down on its own.
class GamePhaseHeader extends StatelessWidget {
  /// Server phase id. 'NIGHT' / 'DAY' (case-insensitive); anything else is
  /// rendered with neutral colors.
  final String phase;

  final int round;
  final Duration remaining;

  /// Already-localized one-liner, e.g. 'Kurbanını seç.'
  final String? instructionTr;

  /// Optional total phase duration (forwarded to [GameTimer]).
  final Duration? total;

  const GamePhaseHeader({
    super.key,
    required this.phase,
    required this.round,
    required this.remaining,
    this.instructionTr,
    this.total,
  });

  bool get _isNight => phase.toUpperCase() == 'NIGHT';
  bool get _isDay => phase.toUpperCase() == 'DAY';

  String get _phaseLabelTr {
    if (_isNight) return 'GECE';
    if (_isDay) return 'GÜNDÜZ';
    return phase.toUpperCase();
  }

  IconData get _phaseIcon {
    if (_isNight) return Icons.nightlight_round;
    if (_isDay) return Icons.wb_sunny_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  Color get _accent {
    if (_isNight) return AppColors.vampire;
    if (_isDay) return AppColors.warning;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _isNight ? AppColors.bgSecondary : AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.4)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(_phaseIcon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _phaseLabelTr,
                      style: AppTextStyles.title.copyWith(
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$round. Tur',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
              GameTimer(remaining: remaining, total: total, compact: true),
            ],
          ),
          if (instructionTr != null && instructionTr!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    instructionTr!,
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
