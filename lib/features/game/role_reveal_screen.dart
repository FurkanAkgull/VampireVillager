import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../widgets/widgets.dart';

/// Role reveal (design doc §10).
///
/// The role itself is assigned server-side; this screen only presents the
/// already-received [roleId]. Tapping the card is a local UI reveal, it does not
/// change any game state. [onContinue] is what tells the controller the player
/// has seen the reveal.
class RoleRevealScreen extends StatefulWidget {
  final String roleId;
  final VoidCallback onContinue;

  const RoleRevealScreen({
    super.key,
    required this.roleId,
    required this.onContinue,
  });

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen>
    with SingleTickerProviderStateMixin {
  /// Card flip duration (design doc §20: stay inside 150-400ms).
  static const _flipDuration = Duration(milliseconds: 360);

  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: _flipDuration,
  );

  bool _revealed = false;

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flip.forward();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = RoleVisuals.of(widget.roleId);

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
          child: Center(
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
                        _revealed ? 'ROLÜN' : 'GECE BAŞLADI',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _revealed
                            ? 'Bu rolü kimseyle paylaşma.'
                            : 'Rolünü öğrenmek için kartına dokun.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _FlipCard(
                        animation: _flip,
                        front: _HiddenCard(onTap: _reveal),
                        back: GameRoleCard(
                          roleVisual: visual,
                          compact: false,
                          selected: true,
                          showSelectionCheck: false,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      GamePrimaryButton(
                        label: 'Devam Et',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _revealed ? widget.onContinue : null,
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

/// 3D card flip around the Y axis.
///
/// [front] is shown for the first half of the animation, [back] for the second
/// half (counter-rotated so it is not mirrored). The swap happens exactly when
/// the card is edge-on, which also hides the size change between the two faces.
class _FlipCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget front;
  final Widget back;

  const _FlipCard({
    required this.animation,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        final showBack = t >= 0.5;
        final angle = t * math.pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(showBack ? angle - math.pi : angle),
          child: showBack ? back : front,
        );
      },
    );
  }
}

/// The face-down card the player taps to reveal their role.
class _HiddenCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HiddenCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl + AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '?',
                    style: AppTextStyles.displayLarge.copyWith(fontSize: 40),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'ROLÜNÜ GÖR',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(letterSpacing: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
