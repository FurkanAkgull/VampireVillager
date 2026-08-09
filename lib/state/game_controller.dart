import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_storage.dart';
import '../core/websocket/ws_client.dart';
import '../models/chat_message.dart';
import '../models/chat_toast.dart';
import '../models/night_resolution.dart';
import '../models/session_state.dart';

class GameController extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final WsClient _ws = WsClient();
  final SessionStorage _storage = SessionStorage();

  String? sessionId;
  String? playerId;
  String? token;
  String? nickname;
  String? plainPassword; // shown to host once, right after creation
  String? myRole;

  SessionState? state;
  final List<ChatMessageInfo> chat = [];
  String? lastError;
  String? lastNightActionResult; // e.g. medium's revealed role
  bool connected = false;

  /// UI-only flags: which one-shot screens the local player already dismissed.
  /// They never influence game rules — the server stays authoritative.
  bool roleRevealSeen = false;
  bool eliminationSeen = false;

  // --- Night resolution (spec §1.3 / §1.7) ----------------------------------

  /// Latest `NIGHT_RESOLUTION` payload received for this player, already
  /// filtered server-side. Null when there is nothing to show.
  NightResolutionInfo? nightResolution;

  /// Round of the last night resolution the player dismissed. Mirrors
  /// [roleRevealSeen]; per round because a new resolution arrives every night.
  int? nightResolutionSeenForRound;

  /// True while an unseen resolution is waiting to be shown. Purely a UI gate —
  /// the actual DAY transition is server-timed and independent of this flag.
  bool get hasUnseenNightResolution =>
      nightResolution != null &&
      nightResolutionSeenForRound != nightResolution!.round;

  /// True after an unexpected websocket drop, until a reconnect succeeds.
  bool connectionLost = false;

  /// True while [retryConnection] is in flight.
  bool connectionRetrying = false;

  // --- Chat notifications (spec §3) -----------------------------------------

  /// Messages received while the chat screen was closed (spec §3.1).
  int unreadCount = 0;

  /// True while the player is actually looking at the chat (side panel mounted
  /// or bottom sheet open). While true, no notification is produced (§3.2).
  bool chatScreenOpen = false;

  /// True when at least one unread message came from the vampire channel, so
  /// the badge can use the vampire accent (§3.5).
  bool unreadVampire = false;

  /// Latest toast to show, or null when there is nothing pending. Replaced by
  /// a new instance for every burst; the UI compares by identity.
  ChatToastInfo? pendingChatToast;

  /// Messages collected for the current notification batch.
  final List<ChatMessageInfo> _toastBatch = [];
  Timer? _toastBatchTimer;

  /// How long incoming messages are collected before one toast is emitted
  /// (spec §3.4 — "mesaj spam'i oluşturma").
  static const Duration chatToastBatchWindow = Duration(milliseconds: 1200);

  bool get isHost => state != null && playerId != null && state!.hostPlayerId == playerId;

  Future<void> createSession({
    required String nickname,
    required int maxPlayers,
    String? password,
    required Map<String, int> activeRoles,
  }) async {
    final resp = await _api.createSession(
      nickname: nickname,
      maxPlayers: maxPlayers,
      password: password,
      activeRoles: activeRoles,
    );
    sessionId = resp['sessionId'] as String;
    playerId = resp['hostPlayerId'] as String;
    token = resp['token'] as String;
    plainPassword = resp['password'] as String;
    this.nickname = nickname;
    await _storage.save(sessionId: sessionId!, playerId: playerId!, token: token!);
    await _connectAndSync();
  }

  Future<void> joinSession({required String sessionId, required String password, required String nickname}) async {
    final resp = await _api.joinSession(sessionId: sessionId, password: password, nickname: nickname);
    this.sessionId = resp['sessionId'] as String;
    playerId = resp['playerId'] as String;
    token = resp['token'] as String;
    this.nickname = nickname;
    await _storage.save(sessionId: this.sessionId!, playerId: playerId!, token: token!);
    await _connectAndSync();
  }

  Future<bool> tryResumeSession() async {
    final saved = await _storage.load();
    if (saved == null) return false;
    sessionId = saved['sessionId'];
    playerId = saved['playerId'];
    token = saved['token'];
    try {
      await _connectAndSync();
      return true;
    } catch (_) {
      await _storage.clear();
      sessionId = playerId = token = null;
      return false;
    }
  }

  Future<void> _connectAndSync() async {
    final snapshot = await _api.getState(sessionId: sessionId!, playerId: playerId!, token: token!);
    state = SessionState.fromJson(snapshot);
    _syncMyRole();
    _expireStaleNightResolution();
    _ws.onDisconnected = _onWsDisconnected;
    await _ws.connect(sessionId: sessionId!, playerId: playerId!, token: token!);
    connected = true;
    connectionLost = false;
    _ws.events.listen(_onWsEvent);
    notifyListeners();
  }

  void _onWsDisconnected() {
    connected = false;
    connectionLost = true;
    notifyListeners();
  }

  /// Re-runs the snapshot fetch + websocket handshake after a drop.
  Future<void> retryConnection() async {
    if (sessionId == null || playerId == null || token == null) return;
    connectionRetrying = true;
    notifyListeners();
    try {
      await _connectAndSync();
    } catch (_) {
      connectionLost = true;
    }
    connectionRetrying = false;
    notifyListeners();
  }

  /// The player has dismissed the role reveal screen (design doc §10).
  void markRoleRevealSeen() {
    roleRevealSeen = true;
    notifyListeners();
  }

  /// The player has dismissed the elimination screen (design doc §17).
  void markEliminationSeen() {
    eliminationSeen = true;
    notifyListeners();
  }

  /// The player has dismissed the night resolution screen (spec §1.3).
  /// This only stops covering the board — the game moves on when the server
  /// says so (PHASE_CHANGED), never because of this call.
  void markNightResolutionSeen() {
    final round = nightResolution?.round;
    if (round == null || nightResolutionSeenForRound == round) return;
    nightResolutionSeenForRound = round;
    notifyListeners();
  }

  /// Drops a resolution that the player never dismissed but that the game has
  /// already moved past (a newer round started). State-driven, no timers.
  void _expireStaleNightResolution() {
    final res = nightResolution;
    if (res == null || state == null) return;
    if (state!.round > res.round || state!.status == 'FINISHED' || state!.status == 'CLOSED') {
      nightResolution = null;
    }
  }

  /// The chat became visible (side panel mounted / bottom sheet opened).
  /// Clears the unread counter and any pending toast (spec §3.1).
  void markChatOpened() {
    _toastBatchTimer?.cancel();
    _toastBatchTimer = null;
    _toastBatch.clear();
    final changed = !chatScreenOpen || unreadCount != 0 || pendingChatToast != null;
    chatScreenOpen = true;
    unreadCount = 0;
    unreadVampire = false;
    pendingChatToast = null;
    if (changed) notifyListeners();
  }

  /// The chat is no longer visible; new messages start counting again.
  ///
  /// Deliberately does not notifyListeners(). Two call sites reach here:
  /// ChatPanel.dispose() (widget tear-down, i.e. during build, where notifying
  /// would mark listeners dirty mid-build) and GameScreen._openChat() after the
  /// bottom sheet future resolves (a plain async continuation where notifying
  /// would be safe). Notifying is skipped because it is not needed either way:
  /// nothing visible reads [chatScreenOpen] on its own — the toast host only
  /// acts when a new message arrives, and that path notifies via
  /// [_trackUnread] / [_flushToastBatch].
  void markChatClosed() {
    chatScreenOpen = false;
  }

  /// The UI finished showing [pendingChatToast].
  void clearChatToast() {
    if (pendingChatToast == null) return;
    pendingChatToast = null;
    notifyListeners();
  }

  /// Unread counting + batched notification for one incoming message (§3.3).
  /// Own messages never count as unread.
  void _trackUnread(ChatMessageInfo msg) {
    if (chatScreenOpen) return;
    if (msg.playerId == playerId) return;

    unreadCount++;
    if (msg.channel == 'VAMPIRE') unreadVampire = true;

    _toastBatch.add(msg);
    // Fixed window from the first message of the burst, so the toast is never
    // delayed indefinitely by a continuous stream of messages.
    _toastBatchTimer ??= Timer(chatToastBatchWindow, _flushToastBatch);
  }

  void _flushToastBatch() {
    _toastBatchTimer = null;
    if (_toastBatch.isEmpty) return;
    final batch = List<ChatMessageInfo>.from(_toastBatch);
    _toastBatch.clear();
    if (chatScreenOpen) return;

    final single = batch.length == 1 ? batch.first : null;
    pendingChatToast = ChatToastInfo(
      count: batch.length,
      nickname: single?.nickname ?? '',
      message: single?.message ?? '',
      vampireChannel: batch.any((m) => m.channel == 'VAMPIRE'),
    );
    notifyListeners();
  }

  void _resetChatNotifications() {
    _toastBatchTimer?.cancel();
    _toastBatchTimer = null;
    _toastBatch.clear();
    pendingChatToast = null;
    unreadCount = 0;
    unreadVampire = false;
    chatScreenOpen = false;
  }

  @override
  void dispose() {
    _toastBatchTimer?.cancel();
    super.dispose();
  }

  void _syncMyRole() {
    final matches = state?.players.where((p) => p.playerId == playerId) ?? const [];
    final me = matches.isEmpty ? null : matches.first;
    if (me?.role != null && me!.role != 'UNKNOWN') myRole = me.role;
  }

  void _onWsEvent(WsEvent ev) {
    switch (ev.event) {
      case 'GAME_STATE_UPDATED':
        state = SessionState.fromJson(ev.data);
        _syncMyRole();
        _expireStaleNightResolution();
        break;
      case 'NIGHT_RESOLUTION':
        // Already filtered for this player by the server (§1.4 / §1.6).
        nightResolution = NightResolutionInfo.fromJson(ev.data);
        break;
      case 'ROLE_ASSIGNED':
        myRole = ev.data['role'] as String?;
        break;
      case 'CHAT_MESSAGE':
        final msg = ChatMessageInfo.fromJson(ev.data);
        chat.add(msg);
        _trackUnread(msg);
        break;
      case 'PHASE_CHANGED':
      case 'PLAYER_JOINED':
      case 'PLAYER_LEFT':
      case 'HOST_CHANGED':
      case 'GAME_STARTED':
      case 'VOTE_STARTED':
      case 'VOTE_CAST':
      case 'PLAYER_ELIMINATED':
      case 'PLAYER_DIED':
      case 'PLAYER_SAVED':
      case 'GAME_FINISHED':
        break; // state refresh (GAME_STATE_UPDATED) carries the actual data
      case 'ERROR':
        lastError = ev.data['message'] as String?;
        break;
    }
    notifyListeners();
  }

  Future<void> startGame() async {
    await _api.startGame(sessionId: sessionId!, playerId: playerId!, token: token!);
  }

  Future<void> castVote(String targetId) async {
    await _api.vote(sessionId: sessionId!, playerId: playerId!, token: token!, targetId: targetId);
  }

  Future<void> submitNightAction(String action, String? targetId) async {
    lastNightActionResult = null;
    final result = await _api.action(
      sessionId: sessionId!,
      playerId: playerId!,
      token: token!,
      action: action,
      targetId: targetId,
    );
    if (result.containsKey('revealedRole')) {
      lastNightActionResult = result['revealedRole'] as String?;
      notifyListeners();
    }
  }

  /// Host-only: flip the "Detaylı Gece Sonuçları" option (spec §1.5).
  ///
  /// The value lives on the server; nothing is applied locally. The authoritative
  /// value arrives with the next GAME_STATE_UPDATED snapshot.
  Future<void> toggleDetailedNightResults(bool value) async {
    if (sessionId == null || playerId == null || token == null) return;
    await _api.updateSettings(
      sessionId: sessionId!,
      playerId: playerId!,
      token: token!,
      detailedNightResults: value,
    );
  }

  Future<void> sendChat(String message) async {
    _ws.send('CHAT_MESSAGE', {'message': message});
  }

  Future<void> leaveSession() async {
    if (sessionId != null && playerId != null && token != null) {
      try {
        await _api.leaveSession(sessionId: sessionId!, playerId: playerId!, token: token!);
      } catch (_) {}
    }
    await _ws.disconnect();
    await _storage.clear();
    sessionId = playerId = token = nickname = myRole = plainPassword = null;
    state = null;
    chat.clear();
    _resetChatNotifications();
    connected = false;
    roleRevealSeen = false;
    eliminationSeen = false;
    nightResolution = null;
    nightResolutionSeenForRound = null;
    connectionLost = false;
    connectionRetrying = false;
    notifyListeners();
  }

  bool hasSubmittedNightAction() => false; // per-round tracking is server-side; UI infers from state/errors
}
