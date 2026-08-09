import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../core/network/api_client.dart';
import '../../models/player.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';

/// Night role actions (vampire kill / doctor protect / medium inspect) and
/// day voting share the same "pick a target from the player list" shape.
///
/// The server validates every submission; this panel only collects the choice
/// and reflects the server's answer (error / accepted).
class ActionPanel extends StatefulWidget {
  const ActionPanel({super.key});

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<ActionPanel> {
  String? _selectedTarget;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final state = controller.state!;
    final isNight = state.status == 'NIGHT';
    final role = controller.myRole;

    final me = state.players.where((p) => p.playerId == controller.playerId);
    final iAmAlive = me.isNotEmpty && me.first.alive;
    if (!iAmAlive) {
      return const _PanelNotice(
        icon: Icons.visibility_outlined,
        text: 'Elendin. Oyunu izlemeye devam edebilirsin.',
      );
    }

    if (isNight) {
      final hasNightAction =
          role == 'VAMPIRE' || role == 'DOCTOR' || role == 'MEDIUM';
      if (!hasNightAction) {
        return const _PanelNotice(
          icon: Icons.nightlight_round,
          text: 'Gece pasifsin. Vampirler seçim yapıyor...',
        );
      }
      final targets = role == 'MEDIUM'
          ? state.players.where((p) => !p.alive).toList()
          : state.players
              .where((p) => p.alive && p.playerId != controller.playerId)
              .toList();
      final actionLabel = switch (role) {
        'VAMPIRE' => 'Öldür',
        'DOCTOR' => 'Koru',
        'MEDIUM' => 'Sorgula',
        _ => 'Seç',
      };
      return _buildPanel(
        context,
        controller,
        title: switch (role) {
          'VAMPIRE' => 'Bir kurban seç',
          'DOCTOR' => 'Koruyacağın kişiyi seç',
          'MEDIUM' => 'Sorgulanacak ölü oyuncuyu seç',
          _ => '',
        },
        targets: targets,
        actionLabel: actionLabel,
        accent: RoleVisuals.of(role).color,
        onSubmit: () async {
          final action = switch (role) {
            'VAMPIRE' => 'KILL',
            'DOCTOR' => 'PROTECT',
            'MEDIUM' => 'INSPECT',
            _ => '',
          };
          await controller.submitNightAction(action, _selectedTarget);
        },
        extra: controller.lastNightActionResult != null
            ? _RevealResult(roleId: controller.lastNightActionResult!)
            : null,
      );
    }

    // DAY -> voting
    final targets = state.players
        .where((p) => p.alive && p.playerId != controller.playerId)
        .toList();
    return _buildPanel(
      context,
      controller,
      title: 'Şüphelendiğin kişiyi oyla',
      targets: targets,
      actionLabel: 'Oy Ver',
      accent: AppColors.accent,
      onSubmit: () => controller.castVote(_selectedTarget!),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    GameController controller, {
    required String title,
    required List<PlayerInfo> targets,
    required String actionLabel,
    required Color accent,
    required Future<void> Function() onSubmit,
    Widget? extra,
  }) {
    final canSubmit =
        _selectedTarget != null && !_submitting && !_submitted;

    return LayoutBuilder(builder: (context, constraints) {
      // Very short viewports (small phones in landscape-ish heights, ~320x568):
      // drop the panel title and tighten the paddings. The same instruction is
      // already visible in the phase header, so nothing is lost.
      final tight = constraints.maxHeight < 170;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          tight ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.lg,
          tight ? AppSpacing.sm : AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!tight) ...[
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
            ],
            Expanded(
              child: targets.isEmpty
                  ? const Center(
                      child: Text(
                        'Seçilebilecek oyuncu yok.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: targets.length,
                      itemBuilder: (context, i) {
                        final p = targets[i];
                        return GameVoteCard(
                          nickname: p.nickname,
                          selected: p.playerId == _selectedTarget,
                          accentColor: accent,
                          enabled: !_submitted && !_submitting,
                          onTap: () =>
                              setState(() => _selectedTarget = p.playerId),
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              GameInlineError(_error!),
            ],
            if (extra != null) ...[
              const SizedBox(height: AppSpacing.sm),
              extra,
            ],
            SizedBox(height: tight ? AppSpacing.sm : AppSpacing.md),
            GamePrimaryButton(
              label: _submitted ? 'Gönderildi' : actionLabel,
              color: accent,
              loading: _submitting,
              icon: _submitted ? Icons.check_rounded : null,
              onPressed: canSubmit ? () => _submit(onSubmit) : null,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _submit(Future<void> Function() onSubmit) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await onSubmit();
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Neutral, centered message for the "you have nothing to do" states.
class _PanelNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PanelNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medium inspection result returned by the server.
class _RevealResult extends StatelessWidget {
  final String roleId;

  const _RevealResult({required this.roleId});

  @override
  Widget build(BuildContext context) {
    final visual = RoleVisuals.of(roleId);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: visual.color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(visual.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm),
          const Text('Rol: ', style: AppTextStyles.bodySecondary),
          Text(
            visual.displayNameTr,
            style: AppTextStyles.body.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
