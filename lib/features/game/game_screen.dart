import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../models/chat_toast.dart';
import '../../models/session_state.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';
import '../chat/chat_panel.dart';
import '../errors/connection_lost_screen.dart';
import '../errors/error_state_screen.dart';
import '../lobby/home_screen.dart';
import '../lobby/waiting_room_view.dart';
import 'action_panel.dart';
import 'game_over_screen.dart';
import 'night_resolution_screen.dart';
import 'phase_timer.dart';
import 'player_eliminated_screen.dart';
import 'player_list.dart';
import 'role_reveal_screen.dart';

/// Night / day background gradients (design doc §21).
const _nightGradient = [Color(0xFF080B18), Color(0xFF17102B)];
const _dayGradient = [Color(0xFF10182A), Color(0xFF263650)];

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  static const double _wideBreakpoint = 700;

  /// Below this viewport height the roster and the action panel sit next to
  /// each other instead of stacked (phone landscape).
  static const double _shortBreakpoint = 420;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final state = controller.state;

    if (state == null) {
      return const Scaffold(
        body: GameLoading(label: 'Oyun durumu yükleniyor...'),
      );
    }

    // One-shot / blocking screens take over the whole viewport (no app bar):
    // they each answer a single question and must not compete with the board.
    final takeover = _takeoverScreen(context, controller, state);
    if (takeover != null) return takeover;

    final isNight = state.status == 'NIGHT';

    // The gradient sits behind the whole Scaffold (including the transparent
    // AppBar) so the night -> day change reads as one atmosphere shift (§21).
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight ? _nightGradient : _dayGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(state.sessionId, style: AppTextStyles.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Oyundan Ayrıl',
              onPressed: () => _leave(context, controller),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              _buildBody(context, controller, state),
              // In-app chat notification (spec §3). Only ever visible while the
              // chat is closed, i.e. in practice on the narrow layout.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                child: _ChatToastHost(onTap: () => _openChatSheet(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-screen states that replace the board entirely, in priority order:
  /// lost connection > role reveal > own elimination. Returns null when the
  /// normal game view should be shown.
  Widget? _takeoverScreen(
    BuildContext context,
    GameController controller,
    SessionState state,
  ) {
    if (controller.connectionLost && state.status != 'WAITING') {
      return Scaffold(
        body: SafeArea(
          child: ConnectionLostScreen(
            onRetry: controller.retryConnection,
            retrying: controller.connectionRetrying,
          ),
        ),
      );
    }

    final inRound = state.status == 'NIGHT' || state.status == 'DAY';
    if (!inRound) return null;

    final role = controller.myRole;
    if (RoleVisuals.isRevealed(role) && !controller.roleRevealSeen) {
      return RoleRevealScreen(
        roleId: role!,
        onContinue: controller.markRoleRevealSeen,
      );
    }

    // What just happened tonight, before anything else about "now". Shown as
    // soon as NIGHT_RESOLUTION arrives, regardless of whether the phase has
    // already flipped to DAY; it never drives the transition itself (spec §1.8).
    final resolution = controller.nightResolution;
    if (resolution != null && controller.hasUnseenNightResolution) {
      return NightResolutionScreen(
        resolution: resolution,
        nicknames: {
          for (final p in state.players) p.playerId: p.nickname,
        },
        onContinue: controller.markNightResolutionSeen,
      );
    }

    final me = state.players.where((p) => p.playerId == controller.playerId);
    final iAmDead = me.isNotEmpty && !me.first.alive;
    if (iAmDead && !controller.eliminationSeen) {
      return PlayerEliminatedScreen(
        roleId: role ?? me.first.role ?? 'UNKNOWN',
        onContinue: controller.markEliminationSeen,
      );
    }

    return null;
  }

  Future<void> _leaveToMenu(BuildContext context) =>
      _leave(context, context.read<GameController>());

  Future<void> _leave(BuildContext context, GameController controller) async {
    final navigator = Navigator.of(context);
    await controller.leaveSession();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (r) => false,
    );
  }

  Widget _buildBody(
    BuildContext context,
    GameController controller,
    SessionState state,
  ) {
    switch (state.status) {
      case 'WAITING':
      case 'STARTING':
        return const WaitingRoomView();
      case 'FINISHED':
        return GameOverScreen(
          state: state,
          onBackToMenu: () => _leaveToMenu(context),
        );
      case 'CLOSED':
        return ErrorStateScreen(
          title: 'OTURUM KAPANDI',
          message: 'Bu oyun oturumu artık aktif değil.',
          icon: Icons.meeting_room_outlined,
          onBackToMenu: () => _leaveToMenu(context),
        );
      case 'NIGHT':
      case 'DAY':
      default:
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > _wideBreakpoint;

            // Phone landscape: there is not enough vertical room to stack the
            // roster on top of the action panel, so they go side by side.
            final short = constraints.maxHeight < _shortBreakpoint;

            final roster = Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: PlayerList(
                players: state.players,
                myPlayerId: controller.playerId,
              ),
            );
            final panel = ActionPanel(
              key: ValueKey('${state.phase}-${state.round}'),
            );

            final mainColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: PhaseTimer(
                    phase: state.phase ?? 'NIGHT',
                    round: state.round,
                    endsAt: state.phaseEndsAt,
                    startedAt: state.phaseStartedAt,
                    instructionTr: _instructionFor(controller, state),
                  ),
                ),
                SizedBox(height: short ? AppSpacing.sm : AppSpacing.lg),
                if (short)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: roster),
                        Expanded(child: panel),
                      ],
                    ),
                  )
                else ...[
                  Expanded(flex: 3, child: roster),
                  Expanded(flex: 2, child: panel),
                ],
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GameSecondaryButton(
                          label: 'Sohbet',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () => _openChatSheet(context),
                        ),
                        // Unread badge (spec §3.1); hidden at zero.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.md,
                                ),
                                child: UnreadChatBadge(
                                  count: controller.unreadCount,
                                  color: controller.unreadVampire
                                      ? AppColors.vampire
                                      : AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );

            if (!wide) return mainColumn;
            return Row(
              children: [
                Expanded(flex: 2, child: mainColumn),
                const VerticalDivider(width: 1),
                const Expanded(flex: 1, child: ChatPanel()),
              ],
            );
          },
        );
    }
  }

  Future<void> _openChatSheet(BuildContext context) async {
    final controller = context.read<GameController>();
    final height = MediaQuery.of(context).size.height * 0.7;
    controller.markChatOpened();
    await showGameBottomSheet(
      context,
      child: SizedBox(height: height, child: const ChatPanel()),
    );
    // Sheet dismissed (tap outside, drag down or back): unread starts counting
    // again. ChatPanel.dispose does the same — the call is idempotent.
    controller.markChatClosed();
  }

  /// Answers "what should I do right now?" (design rule 29).
  String _instructionFor(GameController controller, SessionState state) {
    final me = state.players.where((p) => p.playerId == controller.playerId);
    final iAmAlive = me.isNotEmpty && me.first.alive;
    if (!iAmAlive) return 'Elendin. Oyunu izliyorsun.';

    if (state.status == 'NIGHT') {
      final role = controller.myRole;
      final hasNightAction =
          role == 'VAMPIRE' || role == 'DOCTOR' || role == 'MEDIUM';
      return hasNightAction
          ? 'Kimi hedeflemek istiyorsun?'
          : 'Gece pasifsin, vampirler seçim yapıyor...';
    }
    return 'Köyde tartışma zamanı. Bir oyuncuya oy ver.';
  }
}

/// Shows [GameController.pendingChatToast] for [_visibleFor] and then removes
/// it (spec §3: "2-4 saniye görünmeli"). Tapping opens the chat.
class _ChatToastHost extends StatefulWidget {
  final VoidCallback onTap;

  const _ChatToastHost({required this.onTap});

  @override
  State<_ChatToastHost> createState() => _ChatToastHostState();
}

class _ChatToastHostState extends State<_ChatToastHost> {
  static const Duration _visibleFor = Duration(seconds: 3);

  ChatToastInfo? _visible;
  ChatToastInfo? _lastHandled;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss({bool notifyController = true}) {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _visible = null);
    if (notifyController) context.read<GameController>().clearChatToast();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final pending = controller.pendingChatToast;

    if (controller.chatScreenOpen) {
      // Chat got opened meanwhile — nothing to announce (spec §3.2).
      _timer?.cancel();
      _timer = null;
      _visible = null;
    } else if (pending != null && !identical(pending, _lastHandled)) {
      _lastHandled = pending;
      _visible = pending;
      _timer?.cancel();
      _timer = Timer(_visibleFor, _dismiss);
    }

    final toast = _visible;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: toast == null
          ? const SizedBox.shrink()
          : ChatNotification(
              key: ValueKey(toast),
              nickname: toast.nickname,
              message: toast.message,
              count: toast.count,
              vampireChannel: toast.vampireChannel,
              onTap: () {
                _dismiss();
                widget.onTap();
              },
            ),
    );
  }
}
