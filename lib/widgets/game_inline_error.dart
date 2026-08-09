import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Compact inline error strip for forms and action panels.
///
/// Use [GameError] for full-area failure states; this one sits directly above
/// the action button and keeps the layout intact.
class GameInlineError extends StatelessWidget {
  /// Already-localized Turkish message coming from the server / error mapping.
  final String message;

  const GameInlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.danger.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
