import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import 'game_primary_button.dart';

/// Error / empty state panel with an optional retry action.
///
/// Messages are expected to be already-localized Turkish text coming from the
/// error mapping layer, never a raw backend exception string.
class GameError extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  /// Label of the retry button.
  final String retryLabelTr;

  final IconData icon;

  /// Center in all available space (default) vs. shrink-wrap inline.
  final bool expand;

  const GameError({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabelTr = 'Tekrar dene',
    this.icon = Icons.error_outline_rounded,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: AppColors.danger),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.title),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.xl),
          GamePrimaryButton(
            label: retryLabelTr,
            onPressed: onRetry,
            icon: Icons.refresh_rounded,
            expand: false,
          ),
        ],
      ],
    );

    if (!expand) return content;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      ),
    );
  }
}
