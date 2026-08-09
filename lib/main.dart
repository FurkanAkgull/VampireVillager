import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_config.dart';
import 'core/constants/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'state/game_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const VampirKoyluApp());
}

class VampirKoyluApp extends StatelessWidget {
  const VampirKoyluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController(),
      child: MaterialApp(
        title: 'Vampir Köylü',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
