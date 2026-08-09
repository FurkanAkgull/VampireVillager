import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';
import 'create_game_screen.dart';
import 'join_game_screen.dart';
import '../game/game_screen.dart';
import '../onboarding/how_to_play_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tryResume();
  }

  Future<void> _tryResume() async {
    final controller = context.read<GameController>();
    final resumed = await controller.tryResumeSession();
    if (!mounted) return;
    if (resumed) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()));
    } else {
      setState(() => _checking = false);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: GameLoading(label: 'Önceki oyun aranıyor...'),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildMenu(context),
            // The only icon-only button in the app: settings has no natural
            // place in the vertical menu stack (design rule 28).
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Ayarlar',
                onPressed: () => _open(const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _MoonLogo(),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'VAMPİR KÖYLÜ',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Herkes masum görünüyor...',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
                      GamePrimaryButton(
                        label: 'OYUN OLUŞTUR',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () => _open(const CreateGameScreen()),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GameSecondaryButton(
                        label: 'OYUNA KATIL',
                        icon: Icons.login_rounded,
                        onPressed: () => _open(const JoinGameScreen()),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextButton(
                        onPressed: () => _open(const HowToPlayScreen()),
                        child: const Text('Nasıl oynanır?'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Moon disc with a subtle halo — the only decorative element on the menu.
class _MoonLogo extends StatelessWidget {
  const _MoonLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 116,
        height: 116,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgSecondary,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.accentGlow(AppColors.medium),
        ),
        child: const Text('🧛', style: TextStyle(fontSize: 52)),
      ),
    );
  }
}
