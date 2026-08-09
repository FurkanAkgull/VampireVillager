import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import 'game_avatar.dart';

/// Compact player row used in the lobby and in the in-game player list.
/// Replaces the plain ListTile layout. Kept short so 10-15 players scroll well.
class GamePlayerCard extends StatelessWidget {
  final String nickname;
  final bool isMe;
  final bool isHost;
  final bool alive;
  final bool connected;

  /// Selection state, only meaningful when [selectable] is true.
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;

  /// Already-localized role label (e.g. 'Vampir'). Null hides the badge.
  final String? roleLabel;

  /// Accent used for the role badge / selection highlight.
  final Color? accentColor;

  /// Optional trailing widget (e.g. vote count).
  final Widget? trailing;

  const GamePlayerCard({
    super.key,
    required this.nickname,
    this.isMe = false,
    this.isHost = false,
    this.alive = true,
    this.connected = true,
    this.selected = false,
    this.selectable = false,
    this.onTap,
    this.roleLabel,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;
    final highlighted = selectable && selected;

    // Alive -> dead is a state change pushed by the server; fade the whole row
    // down instead of letting it snap (250ms, design doc §20). TweenAnimation-
    // Builder is enough here: the list rebuilds, the element is reused, so the
    // tween animates from the previous value to the new one.
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      tween: Tween<double>(end: alive ? 1.0 : 0.55),
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: child,
      ),
      child: _buildCard(accent, highlighted),
    );
  }

  Widget _buildCard(Color accent, bool highlighted) {
    return AnimatedScale(
      scale: highlighted ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.cardElevated : AppColors.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: highlighted ? accent : AppColors.border,
            width: highlighted ? 1.8 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  GameAvatar(
                    nickname: nickname,
                    alive: alive,
                    size: 36,
                    accentColor: highlighted ? accent : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nickname,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.copyWith(
                                  color: alive
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  decoration: alive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: AppSpacing.sm),
                              const _Badge(
                                text: 'SEN',
                                color: AppColors.accent,
                              ),
                            ],
                            if (isHost) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const _Badge(
                                text: 'HOST',
                                color: AppColors.warning,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusText(),
                          style: AppTextStyles.bodySecondary
                              .copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (roleLabel != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _Badge(text: roleLabel!.toUpperCase(), color: accent),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                  if (highlighted) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.check_circle_rounded, size: 20, color: accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusText() {
    if (!alive) return 'Elendi';
    if (!connected) return 'Bağlantı yok';
    return 'Hayatta';
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}
