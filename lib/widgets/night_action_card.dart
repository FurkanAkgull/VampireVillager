import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import '../core/constants/role_visuals.dart';

/// One night-resolution action line (spec §1.3).
///
/// Presentational only: [message] is the fully formed Turkish sentence built by
/// the server and is rendered as-is. [actorRole] / [actionType] are used purely
/// for the icon, the accent color and the heading ("🧛 Vampirler").
class NightActionCard extends StatelessWidget {
  /// Backend role id of the actor ('VAMPIRE', 'DOCTOR', 'MEDIUM', ...) or null
  /// for generic public lines.
  final String? actorRole;

  /// 'GENERIC' | 'KILL' | 'PROTECT' | 'INSPECT'.
  final String actionType;

  /// Ready-to-display Turkish sentence from the server.
  final String message;

  /// True for lines only this player can see (spec §1.6).
  final bool isPrivate;

  /// Role revealed to the actor (medium / seer), if any.
  final String? revealedRole;

  const NightActionCard({
    super.key,
    required this.message,
    this.actorRole,
    this.actionType = 'GENERIC',
    this.isPrivate = false,
    this.revealedRole,
  });

  /// Heading for the card. Vampires act as a team, hence the plural.
  String get _titleTr {
    final role = actorRole?.toUpperCase();
    if (role == null || role.isEmpty) return 'Bu Gece';
    if (role == 'VAMPIRE') return 'Vampirler';
    return RoleVisuals.of(role).displayNameTr;
  }

  String get _emoji {
    if (actorRole != null) return RoleVisuals.of(actorRole).emoji;
    switch (actionType.toUpperCase()) {
      case 'KILL':
        return '🩸';
      case 'PROTECT':
        return '🛡';
      case 'INSPECT':
        return '🔎';
      default:
        return '🌙';
    }
  }

  Color get _accent =>
      actorRole != null ? RoleVisuals.of(actorRole).color : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: accent.withOpacity(0.4)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(_emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wrap (not Row): on narrow phones the private tag drops to its
                // own line instead of overflowing.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _titleTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(color: accent),
                    ),
                    if (isPrivate) const _PrivateTag(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: AppTextStyles.body),
                if (revealedRole != null && revealedRole!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    RoleVisuals.of(revealedRole).displayNameTr.toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                      color: RoleVisuals.of(revealedRole).color,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Only you see this" marker for PRIVATE scope lines.
class _PrivateTag extends StatelessWidget {
  const _PrivateTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'SADECE SANA ÖZEL',
        style: AppTextStyles.label.copyWith(fontSize: 10, letterSpacing: 0.6),
      ),
    );
  }
}
