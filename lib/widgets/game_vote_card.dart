import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import 'game_avatar.dart';

/// Selectable target card used in voting / night-action target lists.
///
/// Selection is local UI state only — the server decides whether the vote is
/// actually accepted; [selected] must be driven by the state the server sent
/// back once confirmed.
class GameVoteCard extends StatelessWidget {
  final String nickname;
  final bool selected;
  final VoidCallback? onTap;

  /// Number of votes currently on this player. 0 hides the counter.
  final int voteCount;

  /// Dead / non-targetable players are dimmed and non-tappable.
  final bool enabled;

  /// Accent color for the selected state (defaults to accent; night actions can
  /// pass the role color).
  final Color? accentColor;

  const GameVoteCard({
    super.key,
    required this.nickname,
    this.selected = false,
    this.onTap,
    this.voteCount = 0,
    this.enabled = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;
    final tappable = enabled && onTap != null;

    // Selection = short scale pop (150ms) on top of the border/color change,
    // so the tap is felt as well as seen (design doc §20).
    return AnimatedScale(
      scale: selected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardElevated : AppColors.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.accentGlow(accent) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: tappable ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    GameAvatar(
                      nickname: nickname,
                      size: 40,
                      accentColor: selected ? accent : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        nickname,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (voteCount > 0)
                      _VoteCounter(count: voteCount, color: accent),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: selected ? accent : AppColors.border,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoteCounter extends StatelessWidget {
  final int count;
  final Color color;

  const _VoteCounter({required this.count, required this.color});

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_vote_rounded, size: 13, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count',
            style: AppTextStyles.label.copyWith(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
