import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(
          Uri.parse('${AppConfig.httpBase}$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('${AppConfig.httpBase}$path').replace(queryParameters: query);
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = resp.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, body['detail']?.toString() ?? 'Bir hata olustu');
    }
    return body;
  }

  Future<Map<String, dynamic>> createSession({
    required String nickname,
    required int maxPlayers,
    String? password,
    required Map<String, int> activeRoles,
  }) {
    return _post('/api/v1/sessions', {
      'nickname': nickname,
      'maxPlayers': maxPlayers,
      if (password != null) 'password': password,
      'activeRoles': activeRoles,
    });
  }

  Future<Map<String, dynamic>> joinSession({
    required String sessionId,
    required String password,
    required String nickname,
  }) {
    return _post('/api/v1/sessions/join', {
      'sessionId': sessionId,
      'password': password,
      'nickname': nickname,
    });
  }

  Future<Map<String, dynamic>> getState({
    required String sessionId,
    required String playerId,
    required String token,
  }) {
    return _get('/api/v1/sessions/$sessionId/state', {'playerId': playerId, 'token': token});
  }

  Future<void> startGame({required String sessionId, required String playerId, required String token}) {
    return _post('/api/v1/sessions/$sessionId/start', {'playerId': playerId, 'token': token});
  }

  Future<void> leaveSession({required String sessionId, required String playerId, required String token}) {
    return _post('/api/v1/sessions/$sessionId/leave', {'playerId': playerId, 'token': token});
  }

  Future<void> vote({
    required String sessionId,
    required String playerId,
    required String token,
    required String targetId,
  }) {
    return _post('/api/v1/sessions/$sessionId/vote', {
      'playerId': playerId,
      'token': token,
      'targetId': targetId,
    });
  }

  Future<Map<String, dynamic>> action({
    required String sessionId,
    required String playerId,
    required String token,
    required String action,
    String? targetId,
  }) {
    return _post('/api/v1/sessions/$sessionId/action', {
      'playerId': playerId,
      'token': token,
      'action': action,
      if (targetId != null) 'targetId': targetId,
    });
  }

  /// Host-only session settings update (spec §1.5). The server validates that
  /// the caller is the host and returns the stored settings.
  Future<Map<String, dynamic>> updateSettings({
    required String sessionId,
    required String playerId,
    required String token,
    required bool detailedNightResults,
  }) {
    return _post('/api/v1/sessions/$sessionId/settings', {
      'playerId': playerId,
      'token': token,
      'detailedNightResults': detailedNightResults,
    });
  }

  Future<void> chat({
    required String sessionId,
    required String playerId,
    required String token,
    required String message,
  }) {
    return _post('/api/v1/sessions/$sessionId/chat', {
      'playerId': playerId,
      'token': token,
      'message': message,
    });
  }
}
