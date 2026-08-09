import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Large, unmistakable session code display for the lobby (design rule 2).
///
/// Copy-to-clipboard is handled by the caller via [onCopy] so this widget stays
/// free of platform services.
class GameSessionCode extends StatelessWidget {
  final String code;
  final VoidCallback? onCopy;

  /// Small caption above the code.
  final String labelTr;

  const GameSessionCode({
    super.key,
    required this.code,
    this.onCopy,
    this.labelTr = 'OYUN KODU',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labelTr, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              code.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTextStyles.code,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.cardElevated,
              borderRadius: AppRadius.mdAll,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: onCopy,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('Kopyala', style: AppTextStyles.button),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
