import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';

/// In-app chat toast shown when a message arrives while the chat is closed
/// (spec §3, §3.3, §3.4).
///
/// Single message  -> sender nickname + message preview.
/// Message burst   -> "N yeni mesaj".
/// Vampire channel -> "VAMPİR SOHBETİ" label + vampire accent (§3.5).
class ChatNotification extends StatelessWidget {
  /// Sender of the single message. Ignored when [count] > 1.
  final String nickname;

  /// Message preview. Ignored when [count] > 1.
  final String message;

  /// How many messages this notification stands for.
  final int count;

  final bool vampireChannel;

  /// Tapping opens the chat (spec §3.3).
  final VoidCallback? onTap;

  const ChatNotification({
    super.key,
    this.nickname = '',
    this.message = '',
    this.count = 1,
    this.vampireChannel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = vampireChannel ? AppColors.vampire : AppColors.accent;
    final batched = count > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: accent.withOpacity(0.55)),
            boxShadow: AppShadows.elevated,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                vampireChannel
                    ? Icons.nightlight_round
                    : Icons.chat_bubble_outline_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vampireChannel) ...[
                      Text(
                        'VAMPİR SOHBETİ',
                        style: AppTextStyles.label.copyWith(color: accent),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      batched ? '$count yeni mesaj' : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!batched && message.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.chatRegular.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
