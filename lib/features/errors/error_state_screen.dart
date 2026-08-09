import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../widgets/widgets.dart';

/// Reusable full-area error state (design doc §23): session not found, session
/// closed, unexpected server refusal, ...
///
/// [title] and [message] must already be localized Turkish text — never a raw
/// backend exception string.
class ErrorStateScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBackToMenu;
  final IconData icon;

  const ErrorStateScreen({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onBackToMenu,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameError(
                  icon: icon,
                  title: title,
                  message: message,
                  onRetry: onRetry,
                  expand: false,
                ),
                if (onBackToMenu != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  GameSecondaryButton(
                    label: 'Ana Menüye Dön',
                    icon: Icons.home_rounded,
                    onPressed: onBackToMenu,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
