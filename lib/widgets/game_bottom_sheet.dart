import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Themed modal bottom sheet (settings, role list, player details).
///
/// Handles safe-area + keyboard insets so callers can pass plain content.
/// Returns the value passed to `Navigator.pop`.
Future<T?> showGameBottomSheet<T>(
  BuildContext context, {
  required Widget child,

  /// Optional heading rendered above [child].
  String? title,

  /// Let the sheet grow past half the screen (long lists).
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: AppColors.bgSecondary,
    barrierColor: const Color(0xB3000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) => _GameBottomSheet(title: title, child: child),
  );
}

class _GameBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;

  const _GameBottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.sm,
            bottom: AppSpacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.md),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
