import 'player.dart';

class SessionState {
  final String sessionId;
  final String status; // WAITING/STARTING/NIGHT/DAY/FINISHED/CLOSED
  final String hostPlayerId;
  final int maxPlayers;
  final Map<String, dynamic> activeRoles;
  final String? phase;
  final double? phaseStartedAt;
  final double? phaseEndsAt;
  final int round;
  final List<PlayerInfo> players;
  final String? winner;

  /// Server-owned session settings (spec §1.5). Never changed locally: the
  /// host writes them through the API and the next snapshot carries the truth.
  final SessionSettings settings;

  SessionState({
    required this.sessionId,
    required this.status,
    required this.hostPlayerId,
    required this.maxPlayers,
    required this.activeRoles,
    required this.phase,
    required this.phaseStartedAt,
    required this.phaseEndsAt,
    required this.round,
    required this.players,
    required this.winner,
    this.settings = const SessionSettings(),
  });

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      sessionId: json['sessionId'] as String,
      status: json['status'] as String,
      hostPlayerId: json['hostPlayerId'] as String,
      maxPlayers: json['maxPlayers'] as int,
      activeRoles: Map<String, dynamic>.from(json['activeRoles'] as Map? ?? {}),
      phase: json['phase'] as String?,
      phaseStartedAt: (json['phaseStartedAt'] as num?)?.toDouble(),
      phaseEndsAt: (json['phaseEndsAt'] as num?)?.toDouble(),
      round: json['round'] as int? ?? 0,
      players: (json['players'] as List<dynamic>? ?? [])
          .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      winner: json['winner'] as String?,
      settings: SessionSettings.fromJson(json['settings'] as Map?),
    );
  }
}

/// Session-level, host-controlled options that live on the server (spec §1.5).
class SessionSettings {
  /// When true the night resolution shows role-labelled action lines to
  /// everyone; when false only a generic summary is public.
  final bool detailedNightResults;

  const SessionSettings({this.detailedNightResults = false});

  /// Tolerates a missing / malformed `settings` object (older servers).
  factory SessionSettings.fromJson(Map? json) {
    if (json == null) return const SessionSettings();
    return SessionSettings(
      detailedNightResults: json['detailedNightResults'] as bool? ?? false,
    );
  }
}
