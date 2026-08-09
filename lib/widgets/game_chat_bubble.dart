import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// Single chat message bubble.
///
/// Own messages are accent-tinted and right aligned; other players' messages
/// are card-colored, left aligned and show the sender nickname.
class GameChatBubble extends StatelessWidget {
  final String nickname;
  final String message;
  final bool isMe;

  /// Optional send time. Null hides the timestamp line.
  final DateTime? timestamp;

  /// Optional accent override (e.g. vampire red inside the night chat).
  final Color? accentColor;

  /// System/announcement style: centered, muted, no nickname.
  final bool isSystem;

  const GameChatBubble({
    super.key,
    required this.nickname,
    required this.message,
    this.isMe = false,
    this.timestamp,
    this.accentColor,
    this.isSystem = false,
  });

  static String formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (isSystem) return _buildSystem();

    final accent = accentColor ?? AppColors.accent;
    final bg = isMe ? accent.withOpacity(0.18) : AppColors.card;
    final borderColor = isMe ? accent.withOpacity(0.45) : AppColors.border;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.md),
      topRight: const Radius.circular(AppRadius.md),
      bottomLeft: Radius.circular(isMe ? AppRadius.md : AppRadius.sm / 2),
      bottomRight: Radius.circular(isMe ? AppRadius.sm / 2 : AppRadius.md),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Text(
                      nickname,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: accent,
                        fontSize: 11,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 2),
                  Text(message, style: AppTextStyles.chatRegular),
                  if (timestamp != null) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatTime(timestamp!),
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
