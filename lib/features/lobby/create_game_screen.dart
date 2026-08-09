import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';
import '../game/game_screen.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  static const int _minPlayers = 3;
  static const int _maxPlayersLimit = 16;

  final _nicknameCtrl = TextEditingController(text: 'Host');
  final _passwordCtrl = TextEditingController();
  int _maxPlayers = 8;
  bool _loading = false;
  String? _error;

  /// Optional roles the host can toggle. Mandatory roles are not listed here.
  final Map<String, bool> _roles = {
    'DOCTOR': true,
    'MEDIUM': true,
  };

  /// Always-on roles, rendered as locked cards.
  static const _mandatoryRoleIds = ['VAMPIRE', 'VILLAGER'];

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _stepPlayers(int delta) {
    final next = (_maxPlayers + delta).clamp(_minPlayers, _maxPlayersLimit);
    if (next != _maxPlayers) setState(() => _maxPlayers = next);
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final controller = context.read<GameController>();
    final activeRoles = <String, int>{
      'VAMPIRE': 1,
      if (_roles['DOCTOR']!) 'DOCTOR': 1,
      if (_roles['MEDIUM']!) 'MEDIUM': 1,
    };
    try {
      await controller.createSession(
        nickname:
            _nicknameCtrl.text.trim().isEmpty ? 'Host' : _nicknameCtrl.text.trim(),
        maxPlayers: _maxPlayers,
        password:
            _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
        activeRoles: activeRoles,
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
      appBar: AppBar(title: const Text('Oyun Oluştur')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _SectionLabel('TAKMA AD'),
                TextField(
                  controller: _nicknameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Host'),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('OYUNCU SAYISI'),
                _PlayerCountStepper(
                  value: _maxPlayers,
                  min: _minPlayers,
                  max: _maxPlayersLimit,
                  onChanged: (v) => setState(() => _maxPlayers = v),
                  onStep: _stepPlayers,
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('ODA ŞİFRESİ'),
                TextField(
                  controller: _passwordCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Boş bırakılırsa otomatik oluşturulur',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('ROLLER'),
                for (final roleId in _mandatoryRoleIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GameRoleCard(
                      roleId: roleId,
                      selected: true,
                      onTap: null,
                      trailing: const _LockedBadge(),
                    ),
                  ),
                for (final roleId in _roles.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GameRoleCard(
                      roleId: roleId,
                      selected: _roles[roleId]!,
                      onTap: () =>
                          setState(() => _roles[roleId] = !_roles[roleId]!),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  GameInlineError(_error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                GamePrimaryButton(
                  label: 'OYUNU OLUŞTUR',
                  loading: _loading,
                  onPressed: _loading ? null : _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.label),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Text('ZORUNLU', style: AppTextStyles.label.copyWith(fontSize: 10)),
    );
  }
}

/// Stepper + slider combo for the max player count (design doc §7).
class _PlayerCountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onStep;

  const _PlayerCountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: value > min ? () => onStep(-1) : null,
              ),
              Text(
                '$value',
                style: AppTextStyles.headline.copyWith(fontSize: 28),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: value < max ? () => onStep(1) : null,
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.cardElevated,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
