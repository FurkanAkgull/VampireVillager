import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';

class WaitingRoomView extends StatelessWidget {
  const WaitingRoomView({super.key});

  static const int _minPlayersToStart = 2;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final state = controller.state!;
    final canStart = state.players.length >= _minPlayersToStart;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSessionCode(
                code: state.sessionId,
                onCopy: () => _copy(context, state.sessionId),
              ),
              if (controller.plainPassword != null) ...[
                const SizedBox(height: AppSpacing.md),
                _PasswordRow(
                  password: controller.plainPassword!,
                  onCopy: () => _copy(context, controller.plainPassword!),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('OYUNCULAR', style: AppTextStyles.label),
                  Text(
                    '${state.players.length} / ${state.maxPlayers}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: state.players.length,
                  itemBuilder: (context, i) {
                    final p = state.players[i];
                    return GamePlayerCard(
                      nickname: p.nickname,
                      isMe: p.playerId == controller.playerId,
                      isHost: p.isHost,
                      alive: p.alive,
                      connected: p.connected,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _DetailedNightResultsTile(),
              const SizedBox(height: AppSpacing.sm),
              if (controller.isHost) ...[
                if (!canStart)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Başlatmak için en az $_minPlayersToStart oyuncu gerekli.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                GamePrimaryButton(
                  label: 'OYUNU BAŞLAT',
                  icon: Icons.play_arrow_rounded,
                  onPressed: canStart ? () => _start(context, controller) : null,
                ),
              ] else
                const _WaitingForHost(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, GameController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.startGame();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panoya kopyalandı')),
    );
  }
}

/// Host-only "Detaylı Gece Sonuçları" switch (spec §1.5).
///
/// The value is owned by the server: the host writes it through the API and the
/// UI only re-renders when the next state snapshot arrives. Non-hosts see the
/// current value read-only — the server rejects their writes anyway.
class _DetailedNightResultsTile extends StatefulWidget {
  const _DetailedNightResultsTile();

  @override
  State<_DetailedNightResultsTile> createState() =>
      _DetailedNightResultsTileState();
}

class _DetailedNightResultsTileState extends State<_DetailedNightResultsTile> {
  bool _busy = false;

  Future<void> _toggle(GameController controller, bool value) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await controller.toggleDetailedNightResults(value);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ayar güncellenemedi.')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final value = controller.state?.settings.detailedNightResults ?? false;
    final isHost = controller.isHost;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.nightlight_round,
            size: 20,
            color: value ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Detaylı Gece Sonuçları', style: AppTextStyles.body),
                SizedBox(height: AppSpacing.xs / 2),
                Text(
                  'Açıkken gece sonunda roller ve hedefleri herkes görür.',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isHost)
            Switch(
              value: value,
              onChanged: _busy ? null : (v) => _toggle(controller, v),
            )
          else
            Text(
              value ? 'AÇIK' : 'KAPALI',
              style: AppTextStyles.label.copyWith(
                color: value ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  final String password;
  final VoidCallback onCopy;

  const _PasswordRow({required this.password, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('ŞİFRE', style: AppTextStyles.label),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              password,
              style: AppTextStyles.title.copyWith(letterSpacing: 4),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Şifreyi kopyala',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Pulsing hint shown to non-host players while they wait.
class _WaitingForHost extends StatefulWidget {
  const _WaitingForHost();

  @override
  State<_WaitingForHost> createState() => _WaitingForHostState();
}

class _WaitingForHostState extends State<_WaitingForHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_bottom_rounded,
                size: 16, color: AppColors.textSecondary),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Host oyunu başlatmasını bekliyorsun...',
                style: AppTextStyles.bodySecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
