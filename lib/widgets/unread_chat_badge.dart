import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Small unread counter pill for chat entry points (spec §3.1).
///
/// Renders nothing when [count] is zero, so call sites can place it
/// unconditionally. Counts above [max] are shown as "9+".
class UnreadChatBadge extends StatelessWidget {
  final int count;

  /// Accent of the pill — pass [AppColors.vampire] for the vampire channel.
  final Color color;

  /// Highest number rendered literally.
  final int max;

  const UnreadChatBadge({
    super.key,
    required this.count,
    this.color = AppColors.accent,
    this.max = 9,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > max ? '$max+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.bgPrimary.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textPrimary,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
