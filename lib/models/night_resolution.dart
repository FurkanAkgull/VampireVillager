/// Client-side model of the server's `NIGHT_RESOLUTION` websocket event
/// (spec §1.7).
///
/// The payload is already filtered per player by the backend: whatever arrives
/// here is exactly what this player is allowed to see (spec §1.4 / §1.6). The
/// client performs no filtering of its own and never derives game truth from
/// it — it only renders it.
class NightResolutionInfo {
  /// Round the resolution belongs to (the night that just ended).
  final int round;

  /// Player ids that died / were saved this night.
  final List<String> playersDied;
  final List<String> playersSaved;

  /// Action lines in server submission order (PUBLIC + this player's PRIVATE).
  final List<NightActionInfo> actions;

  const NightResolutionInfo({
    required this.round,
    required this.playersDied,
    required this.playersSaved,
    required this.actions,
  });

  factory NightResolutionInfo.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(
      json['summary'] as Map? ?? const {},
    );
    return NightResolutionInfo(
      round: (json['round'] as num?)?.toInt() ?? 0,
      playersDied: _ids(summary['playersDied']),
      playersSaved: _ids(summary['playersSaved']),
      actions: (json['actions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((a) => NightActionInfo.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }

  static List<String> _ids(dynamic raw) =>
      (raw as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}

/// One line of the night resolution.
///
/// [message] is already a fully formed Turkish sentence built by the server;
/// the UI displays it as-is and only uses the other fields for iconography.
class NightActionInfo {
  /// 'GENERIC' | 'KILL' | 'PROTECT' | 'INSPECT'.
  final String actionType;

  /// 'PUBLIC' (everyone sees it) | 'PRIVATE' (only this viewer).
  final String scope;

  final String? actorRole;
  final String? actorPlayerId;
  final String? targetPlayerId;
  final String? targetNickname;

  /// 'KILLED' | 'SAVED' | 'TARGETED' | 'PROTECTED' | a revealed role | null.
  final String? result;

  final String? revealedRole;

  /// Ready-to-display Turkish sentence.
  final String message;

  const NightActionInfo({
    required this.actionType,
    required this.scope,
    required this.actorRole,
    required this.actorPlayerId,
    required this.targetPlayerId,
    required this.targetNickname,
    required this.result,
    required this.revealedRole,
    required this.message,
  });

  factory NightActionInfo.fromJson(Map<String, dynamic> json) {
    return NightActionInfo(
      actionType: json['actionType'] as String? ?? 'GENERIC',
      scope: json['scope'] as String? ?? 'PUBLIC',
      actorRole: json['actorRole'] as String?,
      actorPlayerId: json['actorPlayerId'] as String?,
      targetPlayerId: json['targetPlayerId'] as String?,
      targetNickname: json['targetNickname'] as String?,
      result: json['result'] as String?,
      revealedRole: json['revealedRole'] as String?,
      message: json['message'] as String? ?? '',
    );
  }

  bool get isPrivate => scope.toUpperCase() == 'PRIVATE';
}
