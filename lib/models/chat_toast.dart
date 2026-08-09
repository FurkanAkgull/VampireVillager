/// Payload for the in-app chat notification (spec §3, §3.4).
///
/// Built by [GameController] from the chat messages that arrived while the
/// chat screen was closed. A burst of messages collapses into a single toast
/// with [count] > 1 instead of one toast per message.
class ChatToastInfo {
  /// How many messages this toast stands for (always >= 1).
  final int count;

  /// Sender of the single message — empty when [isBatch].
  final String nickname;

  /// Message preview — empty when [isBatch].
  final String message;

  /// True when the batch contains at least one VAMPIRE-channel message, so the
  /// toast can label itself "VAMPİR SOHBETİ" (spec §3.5). Presentation only:
  /// non-vampires never receive those events in the first place.
  final bool vampireChannel;

  const ChatToastInfo({
    required this.count,
    required this.nickname,
    required this.message,
    required this.vampireChannel,
  });

  bool get isBatch => count > 1;
}
