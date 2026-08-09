import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/app_theme.dart';

/// Sound/notification toggles are local-only (no backend, nothing to
/// synchronise). The server address is persisted via [AppConfig] so a
/// physical device can be pointed at a LAN server instead of the emulator
/// default.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sound = true;
  bool _notifications = true;

  late final _hostController = TextEditingController(text: AppConfig.hostOverride ?? '');
  late final _portController = TextEditingController(text: (AppConfig.portOverride ?? 8000).toString());
  String? _savedMessage;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    await AppConfig.setOverride(host: host.isEmpty ? null : host, port: port);
    if (!mounted) return;
    setState(() => _savedMessage = host.isEmpty ? 'Varsayılana dönüldü.' : 'Kaydedildi: $host:${port ?? 8000}');
  }

  Future<void> _resetServer() async {
    await AppConfig.setOverride(host: null, port: null);
    if (!mounted) return;
    setState(() {
      _hostController.text = '';
      _portController.text = '8000';
      _savedMessage = 'Varsayılana dönüldü.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _SectionLabel('GENEL'),
                _SettingTile(
                  icon: Icons.volume_up_rounded,
                  title: 'Ses efektleri',
                  subtitle: 'Oyun içi sesleri aç veya kapat.',
                  value: _sound,
                  onChanged: (v) => setState(() => _sound = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Bildirimler',
                  subtitle: 'Faz değişimlerinde uyarı al.',
                  value: _notifications,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('SUNUCU'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Farklı bir cihazdaki sunucuya bağlanmak için adres '
                        'gir (örn. bilgisayarının LAN IP\'si). Boş bırakırsan '
                        'varsayılan kullanılır.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _hostController,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(
                          labelText: 'Sunucu adresi (IP)',
                          hintText: '192.168.1.26',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _portController,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(labelText: 'Port'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetServer,
                              child: const Text('Varsayılana dön'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveServer,
                              child: const Text('Kaydet'),
                            ),
                          ),
                        ],
                      ),
                      if (_savedMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_savedMessage!, style: AppTextStyles.bodySecondary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('HAKKINDA'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vampir Köylü', style: AppTextStyles.title),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Sürüm ${SettingsScreen.appVersion}',
                        style: AppTextStyles.bodySecondary,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Arkadaşlarınla oynanan, gece-gündüz döngülü sosyal '
                        'çıkarım oyunu.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(text, style: AppTextStyles.label),
    );
  }
}

/// Themed switch row (Material's SwitchListTile does not match the card style).
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

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
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: value ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.body),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(subtitle, style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
