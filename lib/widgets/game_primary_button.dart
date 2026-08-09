import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Primary call-to-action button.
///
/// Single accent color (villager blue) — vampire red is reserved for
/// vampire-themed surfaces. Slight scale-down on press (150ms).
class GamePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// Optional override, e.g. destructive actions (AppColors.danger) or
  /// vampire-flavoured actions (AppColors.vampire). Defaults to accent.
  final Color? color;

  /// Stretch to the parent width. Defaults to true.
  final bool expand;

  const GamePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
    this.expand = true,
  });

  @override
  State<GamePrimaryButton> createState() => _GamePrimaryButtonState();
}

class _GamePrimaryButtonState extends State<GamePrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    final bg = _enabled ? color : AppColors.cardElevated;
    final fg = _enabled ? AppColors.textPrimary : AppColors.textSecondary;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: fg),
        if (widget.loading || widget.icon != null)
          const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button.copyWith(color: fg),
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Material(
        color: bg,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: _enabled ? widget.onPressed : null,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md + 2,
              horizontal: AppSpacing.xl,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
