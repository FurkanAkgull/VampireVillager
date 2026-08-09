import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Full-area loading state with an optional Turkish label
/// (e.g. 'Sunucuya bağlanılıyor...'). The user should never see a bare spinner
/// without knowing what is being waited on.
class GameLoading extends StatelessWidget {
  final String? label;

  /// Center in all available space (default) vs. shrink-wrap inline.
  final bool expand;
  final double size;

  const GameLoading({
    super.key,
    this.label,
    this.expand = true,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.accent,
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
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
