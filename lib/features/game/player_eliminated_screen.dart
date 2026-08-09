import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/role_visuals.dart';
import '../../widgets/widgets.dart';

/// Shown once, right after the server marks the local player as dead
/// (design doc §17).
///
/// The elimination itself is decided server-side; this screen only reports it.
/// The cause text is deliberately generic because the state snapshot does not
/// carry "who accused whom".
class PlayerEliminatedScreen extends StatefulWidget {
  final String roleId;
  final VoidCallback onContinue;

  const PlayerEliminatedScreen({
    super.key,
    required this.roleId,
    required this.onContinue,
  });

  @override
  State<PlayerEliminatedScreen> createState() => _PlayerEliminatedScreenState();
}

class _PlayerEliminatedScreenState extends State<PlayerEliminatedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Kept inside the 150-400ms band from design doc §20.
    duration: const Duration(milliseconds: 350),
  )..forward();

  late final Animation<double> _anim =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = RoleVisuals.of(widget.roleId);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: FadeTransition(
                  opacity: _anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1).animate(_anim),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.heart_broken_rounded,
                              size: 34,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'OYUNDAN ELENDİN',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headline
                              .copyWith(color: AppColors.danger),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Köy seni eledi.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'SENİN ROLÜN',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GameRoleCard(
                          roleVisual: visual,
                          compact: false,
                          selected: true,
                          showSelectionCheck: false,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'Artık oyunu izleyebilirsin.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        GamePrimaryButton(
                          label: 'İzlemeye Devam Et',
                          icon: Icons.visibility_outlined,
                          onPressed: widget.onContinue,
                        ),
                      ],
                    ),
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
