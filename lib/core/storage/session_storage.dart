import 'package:shared_preferences/shared_preferences.dart';

/// Persists the current player's credentials locally so the app can rejoin
/// the same session after a connection drop or app restart (spec §16).
class SessionStorage {
  static const _kSessionId = 'vk_session_id';
  static const _kPlayerId = 'vk_player_id';
  static const _kToken = 'vk_token';

  Future<void> save({required String sessionId, required String playerId, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionId, sessionId);
    await prefs.setString(_kPlayerId, playerId);
    await prefs.setString(_kToken, token);
  }

  Future<Map<String, String>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_kSessionId);
    final playerId = prefs.getString(_kPlayerId);
    final token = prefs.getString(_kToken);
    if (sessionId == null || playerId == null || token == null) return null;
    return {'sessionId': sessionId, 'playerId': playerId, 'token': token};
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionId);
    await prefs.remove(_kPlayerId);
    await prefs.remove(_kToken);
  }
}
