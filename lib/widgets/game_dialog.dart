import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Themed modal dialog used for confirmations, role reveals and results.
///
/// [actions] are usually GamePrimaryButton / GameSecondaryButton widgets; they
/// are stacked full-width so the touch targets stay large on phones.
/// Returns the value passed to `Navigator.pop` by the chosen action.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  List<Widget> actions = const [],

  /// Extra content between the message and the actions (e.g. a role card).
  Widget? content,

  /// Optional icon shown above the title.
  IconData? icon,

  /// Accent for the icon / title underline. Defaults to accent.
  Color? accentColor,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0xB3000000),
    builder: (context) => _GameDialog(
      title: title,
      message: message,
      actions: actions,
      content: content,
      icon: icon,
      accentColor: accentColor,
    ),
  );
}

class _GameDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<Widget> actions;
  final Widget? content;
  final IconData? icon;
  final Color? accentColor;

  const _GameDialog({
    required this.title,
    required this.message,
    required this.actions,
    required this.content,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;

    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: accent.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: accent),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: AppSpacing.lg),
              content!,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                actions[i],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
