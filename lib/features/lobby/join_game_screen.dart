import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';
import '../game/game_screen.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final _sessionIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _sessionIdCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final controller = context.read<GameController>();
    try {
      await controller.joinSession(
        sessionId: _sessionIdCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        nickname: _nicknameCtrl.text.trim().isEmpty
            ? 'Oyuncu'
            : _nicknameCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyuna Katıl')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _FieldLabel('OTURUM ID'),
                TextField(
                  controller: _sessionIdCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.code.copyWith(fontSize: 24),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '48321',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _FieldLabel('ŞİFRE'),
                TextField(
                  controller: _passwordCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '••••'),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _FieldLabel('TAKMA AD'),
                TextField(
                  controller: _nicknameCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _join(),
                  decoration: const InputDecoration(hintText: 'Oyuncu'),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_error != null) ...[
                  GameInlineError(_error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                GamePrimaryButton(
                  label: 'OYUNA KATIL',
                  loading: _loading,
                  onPressed: _loading ? null : _join,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.label),
    );
  }
}
