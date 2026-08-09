import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Outlined, lower-emphasis action button.
class GameSecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// Optional text/icon tint. Border stays neutral by default.
  final Color? foregroundColor;
  final bool expand;

  const GameSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.foregroundColor,
    this.expand = true,
  });

  @override
  State<GameSecondaryButton> createState() => _GameSecondaryButtonState();
}

class _GameSecondaryButtonState extends State<GameSecondaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final fg = _enabled
        ? (widget.foregroundColor ?? AppColors.textPrimary)
        : AppColors.textSecondary;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: _enabled ? widget.onPressed : null,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md + 2,
              horizontal: AppSpacing.xl,
            ),
            child: Row(
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
            ),
          ),
        ),
      ),
    );
  }
}
