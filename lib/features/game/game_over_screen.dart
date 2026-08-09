import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../models/session_state.dart';
import '../../widgets/widgets.dart';

/// End-of-game result screen (design doc §18).
///
/// The winner is decided server-side and read from [SessionState.winner]; this
/// screen never derives a result on its own. Roles are shown only for the
/// players whose role the server already revealed in the final snapshot.
class GameOverScreen extends StatelessWidget {
  final SessionState state;
  final VoidCallback onBackToMenu;

  const GameOverScreen({
    super.key,
    required this.state,
    required this.onBackToMenu,
  });

  String get _winnerKey => (state.winner ?? '').toUpperCase();

  bool get _vampiresWon => _winnerKey == 'VAMPIRES' || _winnerKey == 'VAMPIRE';
  bool get _villagersWon =>
      _winnerKey == 'VILLAGERS' || _winnerKey == 'VILLAGER';

  String get _titleTr {
    if (_vampiresWon) return 'VAMPİRLER KAZANDI';
    if (_villagersWon) return 'KÖY KAZANDI';
    if (_winnerKey.isEmpty) return 'OYUN BİTTİ';
    final visual = RoleVisuals.byRoleId[_winnerKey];
    if (visual != null) return '${visual.displayNameTr.toUpperCase()} KAZANDI';
    return 'OYUN BİTTİ: $_winnerKey';
  }

  String get _subtitleTr {
    if (_vampiresWon) return 'Köy artık bizim.';
    if (_villagersWon) return 'Tüm vampirler ortadan kaldırıldı.';
    return 'Oyun sona erdi.';
  }

  String get _glyph {
    if (_vampiresWon) return '🌙';
    if (_villagersWon) return '☀';
    final visual = RoleVisuals.byRoleId[_winnerKey];
    return visual?.emoji ?? '🏁';
  }

  Color get _accent {
    if (_vampiresWon) return AppColors.vampire;
    if (_villagersWon) return AppColors.villager;
    return RoleVisuals.byRoleId[_winnerKey]?.color ?? AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final players = state.players;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _glyph,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _titleTr,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(color: _accent),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitleTr,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                if (players.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const Text('OYUNCULAR', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        for (final p in players)
                          _ResultRow(
                            nickname: p.nickname,
                            alive: p.alive,
                            roleId: p.role,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                GamePrimaryButton(
                  label: 'Ana Menüye Dön',
                  icon: Icons.home_rounded,
                  onPressed: onBackToMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String nickname;
  final bool alive;
  final String? roleId;

  const _ResultRow({
    required this.nickname,
    required this.alive,
    required this.roleId,
  });

  @override
  Widget build(BuildContext context) {
    final revealed = RoleVisuals.isRevealed(roleId);
    final visual = RoleVisuals.of(roleId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          GameAvatar(
            nickname: nickname,
            alive: alive,
            size: 32,
            accentColor: revealed ? visual.color : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              nickname,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: alive ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (revealed)
            Text(
              '${visual.emoji} ${visual.displayNameTr}',
              style: AppTextStyles.bodySecondary.copyWith(color: visual.color),
            ),
        ],
      ),
    );
  }
}
