import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_config.dart';

class WsEvent {
  final String event;
  final Map<String, dynamic> data;
  WsEvent(this.event, this.data);
}

class WsClient {
  WebSocketChannel? _channel;
  StreamController<WsEvent>? _controller;
  StreamSubscription? _sub;

  /// True while an intentional [disconnect] is running, so the socket closing
  /// does not look like a dropped connection.
  bool _manualDisconnect = false;

  /// True only between a successfully completed handshake and the first
  /// disconnect report. It is the guard for two distinct cases:
  ///  * a handshake that never opened (rejected upgrade) surfaces as a thrown
  ///    error from [connect]; it must not also look like a dropped connection.
  ///  * a single close event reaches both `onError` and `onDone`; clearing the
  ///    flag on the first report keeps [onDisconnected] a one-shot per socket.
  bool _openReported = false;

  /// Called when the socket closes or errors out unexpectedly.
  void Function()? onDisconnected;

  Stream<WsEvent> get events => _controller!.stream;

  Future<void> connect({required String sessionId, required String playerId, required String token}) async {
    await disconnect();
    _manualDisconnect = false;
    _openReported = false;
    _controller = StreamController<WsEvent>.broadcast();
    final uri = Uri.parse('${AppConfig.wsBase}/ws/$sessionId?playerId=$playerId&token=$token');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    // Subscribe before awaiting the handshake: the underlying stream is live
    // from this point on, so no frame delivered right after the socket opens
    // can slip through unheard.
    _sub = channel.stream.listen(
      (raw) {
        final map = jsonDecode(raw as String) as Map<String, dynamic>;
        _controller?.add(WsEvent(map['event'] as String, Map<String, dynamic>.from(map['data'] as Map? ?? {})));
      },
      onError: (_) => _notifyDisconnected(),
      onDone: _notifyDisconnected,
    );
    try {
      // `WebSocketChannel.connect` returns synchronously while the handshake is
      // still in flight. Without awaiting `.ready` the caller resumes on a socket
      // that is not open yet and can attach its `events` listener after the first
      // server messages (CHAT_MESSAGE / GAME_STARTED / ROLE_ASSIGNED) arrived.
      await channel.ready;
      // From here on a close is a real drop of an established connection.
      _openReported = true;
    } catch (_) {
      // Handshake failed (bad token, server down): tear everything down so the
      // caller's `await connect(...)` throws instead of handing back a dead socket.
      await disconnect();
      rethrow;
    }
  }

  void _notifyDisconnected() {
    if (_manualDisconnect || !_openReported) return;
    // One report per opened socket: a close reaches onError *and* onDone.
    _openReported = false;
    onDisconnected?.call();
  }

  void send(String type, Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _openReported = false;
    await _sub?.cancel();
    await _channel?.sink.close();
    await _controller?.close();
    _sub = null;
    _channel = null;
    _controller = null;
  }
}
