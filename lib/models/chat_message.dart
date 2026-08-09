class ChatMessageInfo {
  final String playerId;
  final String nickname;
  final String message;
  final double timestamp;
  final String channel;

  ChatMessageInfo({
    required this.playerId,
    required this.nickname,
    required this.message,
    required this.timestamp,
    required this.channel,
  });

  factory ChatMessageInfo.fromJson(Map<String, dynamic> json) {
    return ChatMessageInfo(
      playerId: json['playerId'] as String,
      nickname: json['nickname'] as String,
      message: json['message'] as String,
      timestamp: (json['timestamp'] as num).toDouble(),
      channel: json['channel'] as String? ?? 'PUBLIC',
    );
  }
}
