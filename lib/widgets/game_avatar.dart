import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Player avatar: initial letter on a neutral surface.
/// Dead players get a muted surface and a skull glyph instead of the initial.
class GameAvatar extends StatelessWidget {
  final String nickname;
  final bool alive;
  final double size;

  /// Optional accent ring (e.g. the player's revealed role color).
  final Color? accentColor;

  const GameAvatar({
    super.key,
    required this.nickname,
    this.alive = true,
    this.size = 40,
    this.accentColor,
  });

  String get _initial {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ring = alive ? (accentColor ?? AppColors.border) : AppColors.border;
    final fg = alive ? AppColors.textPrimary : AppColors.textSecondary;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: alive ? AppColors.cardElevated : AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: alive ? 1.5 : 1),
      ),
      child: alive
          ? Text(
              _initial,
              style: AppTextStyles.title.copyWith(
                color: fg,
                fontSize: size * 0.42,
              ),
            )
          : Opacity(
              opacity: 0.55,
              child: Text('☠', style: TextStyle(fontSize: size * 0.44)),
            ),
    );
  }
}
