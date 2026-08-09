import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../models/night_resolution.dart';
import '../../widgets/widgets.dart';

/// "GECE N SONUCU" screen (spec §1.3, §5).
///
/// Shows what the server decided the previous night. It is a pure report: the
/// payload is already filtered per player by the backend and nothing here moves
/// the game forward — the DAY phase starts when the server says so
/// (PHASE_CHANGED after its own delay), not when this screen is dismissed.
///
/// Animation order (spec §5): fade in -> action cards appear one by one ->
/// result -> continue button. Tapping the background skips the stagger.
class NightResolutionScreen extends StatefulWidget {
  final NightResolutionInfo resolution;

  /// playerId -> nickname, used for the closing result lines.
  final Map<String, String> nicknames;

  /// Dismisses the screen locally (see [GameController.markNightResolutionSeen]).
  final VoidCallback onContinue;

  const NightResolutionScreen({
    super.key,
    required this.resolution,
    required this.nicknames,
    required this.onContinue,
  });

  @override
  State<NightResolutionScreen> createState() => _NightResolutionScreenState();
}

class _NightResolutionScreenState extends State<NightResolutionScreen>
    with SingleTickerProviderStateMixin {
  /// Per-item entry animation (design doc §20: 150-400ms).
  static const Duration _itemDuration = Duration(milliseconds: 340);

  /// Delay between two consecutive items.
  static const Duration _stagger = Duration(milliseconds: 300);

  late final int _itemCount = widget.resolution.actions.length + 1; // + result

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _stagger * _itemCount + _itemDuration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Interval for item [index] inside the shared controller timeline.
  Animation<double> _itemAnimation(int index) {
    final total = _controller.duration!.inMilliseconds;
    final start = (_stagger.inMilliseconds * index) / total;
    final end = start + _itemDuration.inMilliseconds / total;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
  }

  void _skipAnimation() {
    if (!_controller.isCompleted) _controller.value = 1;
  }

  String _nicknameOf(String playerId) =>
      widget.nicknames[playerId] ?? 'Bir oyuncu';

  @override
  Widget build(BuildContext context) {
    final res = widget.resolution;
    final actions = res.actions;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF080B18), Color(0xFF17102B)],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skipAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: _itemAnimation(0),
                        child: Column(
                          children: [
                            Text(
                              'GECE ${res.round} SONUCU',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headline,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Gece sona erdi. Olanlar şunlar:',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      for (var i = 0; i < actions.length; i++) ...[
                        _Reveal(
                          animation: _itemAnimation(i),
                          child: NightActionCard(
                            message: actions[i].message,
                            actorRole: actions[i].actorRole,
                            actionType: actions[i].actionType,
                            isPrivate: actions[i].isPrivate,
                            revealedRole: actions[i].revealedRole,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _Reveal(
                        animation: _itemAnimation(actions.length),
                        child: ActionResultCard(
                          deathLines: [
                            for (final id in res.playersDied)
                              '${_nicknameOf(id)} öldü.',
                          ],
                          savedLines: [
                            for (final id in res.playersSaved)
                              '${_nicknameOf(id)} hayatta kaldı.',
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // The button only becomes tappable once it is actually
                      // visible, so a stray tap cannot skip the reveal.
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = _itemAnimation(_itemCount).value;
                          return Opacity(
                            opacity: t,
                            child: IgnorePointer(
                              ignoring: t < 0.99,
                              child: child,
                            ),
                          );
                        },
                        child: GamePrimaryButton(
                          label: 'GÜNDÜZE GEÇ',
                          icon: Icons.wb_sunny_rounded,
                          onPressed: widget.onContinue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + small upward slide used for every sequentially revealed block.
class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _Reveal({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
