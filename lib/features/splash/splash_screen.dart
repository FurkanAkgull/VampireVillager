import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../lobby/home_screen.dart';

/// First screen of the app (design doc §5).
///
/// Purely decorative + a short fade-in, then hands over to [HomeScreen] which
/// owns the real "resume previous session" logic. No game state is touched here.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// How long the logo stays on screen before navigating away.
  static const Duration holdDuration = Duration(milliseconds: 1400);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(SplashScreen.holdDuration, _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgPrimary, AppColors.bgSecondary],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MoonAndVillage(),
                      SizedBox(height: AppSpacing.xxl),
                      Text(
                        'VAMPİR',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayLarge,
                      ),
                      Text(
                        'KÖYLÜ',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayLarge,
                      ),
                      SizedBox(height: AppSpacing.xl),
                      Text(
                        'Bir gece...\nHerkesin bir sırrı var.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
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

/// Moon disc with a small village silhouette underneath. Kept intentionally
/// minimal (design rule 28: no over-decoration).
class _MoonAndVillage extends StatelessWidget {
  const _MoonAndVillage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgSecondary,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.accentGlow(AppColors.medium),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.nightlight_round,
                size: 44,
                color: AppColors.medium,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: const Size(180, 46),
              painter: _VillagePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat silhouette of a few village houses.
class _VillagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.border;
    final ground = size.height;

    void house(double left, double width, double height) {
      final top = ground - height;
      final body = Rect.fromLTRB(left, top, left + width, ground);
      canvas.drawRect(body, paint);
      final roof = Path()
        ..moveTo(left - 4, top)
        ..lineTo(left + width / 2, top - width * 0.42)
        ..lineTo(left + width + 4, top)
        ..close();
      canvas.drawPath(roof, paint);
    }

    house(size.width * 0.08, 34, 24);
    house(size.width * 0.36, 44, 32);
    house(size.width * 0.70, 30, 20);

    canvas.drawRect(
      Rect.fromLTWH(0, ground - 2, size.width, 2),
      Paint()..color = AppColors.border,
    );
  }

  @override
  bool shouldRepaint(covariant _VillagePainter oldDelegate) => false;
}
