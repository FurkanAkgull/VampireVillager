import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Countdown display.
///
/// When [total] is provided the digits are wrapped in a thin circular progress
/// ring (remaining / total). When it is null only the digits are rendered, so
/// older call sites keep working unchanged.
class GameTimer extends StatelessWidget {
  final Duration remaining;
  final Duration? total;

  /// Smaller variant for tight headers.
  final bool compact;

  /// Below this many seconds the digits turn to the warning color.
  final int warnBelowSeconds;

  const GameTimer({
    super.key,
    required this.remaining,
    this.total,
    this.compact = false,
    this.warnBelowSeconds = 10,
  });

  static String format(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final m = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final warning = seconds <= warnBelowSeconds;
    final color = warning ? AppColors.warning : AppColors.textPrimary;

    final text = Text(
      format(remaining),
      style: AppTextStyles.timerExtraBold.copyWith(
        color: color,
        fontSize: compact ? 22 : null,
      ),
    );

    final totalMs = total?.inMilliseconds ?? 0;
    if (totalMs <= 0) return text;

    // Ring shrinks as the phase runs out. Deliberately thin and un-glowing
    // (design rule 28); the ring is secondary to the digits, which must stay
    // full size (design rule 4).
    final progress =
        (remaining.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();
    final ringColor = warning ? AppColors.warning : AppColors.accent;

    final ring = TweenAnimationBuilder<double>(
      // Smooths each 1-second step instead of snapping (§20).
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: progress, end: progress),
      builder: (context, value, _) => CircularProgressIndicator(
        value: value,
        strokeWidth: compact ? 2.5 : 4,
        backgroundColor: AppColors.cardElevated,
        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
      ),
    );

    // Compact headers have no vertical room for a ring around the digits, so
    // the ring sits next to them and the header height stays unchanged.
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, height: 18, child: ring),
          const SizedBox(width: AppSpacing.sm),
          text,
        ],
      );
    }

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [SizedBox.expand(child: ring), text],
      ),
    );
  }
}
