import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../state/game_controller.dart';
import '../../widgets/widgets.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  /// Kept so [dispose] can flag the chat as closed without a BuildContext.
  GameController? _controller;

  @override
  void initState() {
    super.initState();
    // The chat is on screen from now on: unread count resets, no toasts
    // (spec §3.1 / §3.2). Deferred so we never notify during the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = context.read<GameController>()..markChatOpened();
    });
  }

  @override
  void dispose() {
    _controller?.markChatClosed();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(GameController controller) {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    controller.sendChat(text);
    _msgCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isNight = controller.state?.status == 'NIGHT';
    final isVampire = controller.myRole == 'VAMPIRE';
    final canChat = !isNight || isVampire;
    final vampireChannel = isNight && isVampire;
    final accent = vampireChannel ? AppColors.vampire : AppColors.accent;

    _scrollToBottom();

    return Column(
      children: [
        _ChatHeader(vampireChannel: vampireChannel),
        const Divider(height: 1),
        Expanded(
          child: controller.chat.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz mesaj yok.',
                    style: AppTextStyles.bodySecondary,
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: controller.chat.length,
                  itemBuilder: (context, i) {
                    final m = controller.chat[i];
                    return _AppearingMessage(
                      // Keyed per message so an existing bubble is not replayed
                      // when the list rebuilds; only new entries animate in.
                      key: ValueKey('${m.playerId}-${m.timestamp}-$i'),
                      child: GameChatBubble(
                        nickname: m.nickname,
                        message: m.message,
                        isMe: m.playerId == controller.playerId,
                        accentColor: accent,
                        timestamp: DateTime.fromMillisecondsSinceEpoch(
                          (m.timestamp * 1000).round(),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: canChat,
                  textInputAction: TextInputAction.send,
                  style: AppTextStyles.chatRegular,
                  decoration: InputDecoration(
                    hintText: canChat ? 'Mesaj yaz...' : 'Gece konuşamazsın',
                    isDense: true,
                  ),
                  onSubmitted: canChat ? (_) => _send(controller) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(
                color: accent,
                onPressed: canChat ? () => _send(controller) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fade + slight slide-up for a chat bubble the first time it is built (220ms,
/// design doc §20). Stateless on purpose: [TweenAnimationBuilder] runs once per
/// element, so nothing has to be disposed.
class _AppearingMessage extends StatelessWidget {
  final Widget child;

  const _AppearingMessage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, t, inner) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

/// Slim channel label. The vampire channel only changes the accent — no full
/// red surface (design rule 28).
class _ChatHeader extends StatelessWidget {
  final bool vampireChannel;

  const _ChatHeader({required this.vampireChannel});

  @override
  Widget build(BuildContext context) {
    final accent = vampireChannel ? AppColors.vampire : AppColors.textSecondary;
    final label = vampireChannel ? 'VAMPİR SOHBETİ' : 'SOHBET';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            vampireChannel
                ? Icons.nightlight_round
                : Icons.chat_bubble_outline_rounded,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onPressed;

  const _SendButton({required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? color : AppColors.cardElevated,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Icon(
            Icons.send_rounded,
            size: 20,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
