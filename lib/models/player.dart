class PlayerInfo {
  final String playerId;
  final String nickname;
  final bool alive;
  final bool connected;
  final bool isHost;
  final String? role; // "UNKNOWN" for others while alive, actual role for self/dead

  PlayerInfo({
    required this.playerId,
    required this.nickname,
    required this.alive,
    required this.connected,
    required this.isHost,
    required this.role,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      playerId: json['playerId'] as String,
      nickname: json['nickname'] as String,
      alive: json['alive'] as bool,
      connected: json['connected'] as bool,
      isHost: json['isHost'] as bool,
      role: json['role'] as String?,
    );
  }
}
