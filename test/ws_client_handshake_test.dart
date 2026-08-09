import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vampir_koylu/core/constants/app_config.dart';
import 'package:vampir_koylu/core/websocket/ws_client.dart';

/// Handshake regression tests for [WsClient.connect] (spec §26.10/§26.14).
///
/// A tiny in-process websocket server stands in for the backend so the tests
/// can control the exact moment the first frame is written: right after the
/// upgrade completes, which is the window where events used to be dropped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  late HttpServer server;
  late List<WebSocket> sockets;

  setUp(() async {
    sockets = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await AppConfig.setOverride(host: '127.0.0.1', port: server.port);
    server.listen((req) async {
      final token = req.uri.queryParameters['token'];
      if (token != 'good') {
        // Reject the upgrade the way an auth-failing backend would.
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      sockets.add(ws);
      // First frame written the instant the socket is open.
      ws.add(jsonEncode({
        'event': 'GAME_STARTED',
        'data': {'round': 1}
      }));
    });
  });

  tearDown(() async {
    for (final s in sockets) {
      await s.close();
    }
    await server.close(force: true);
    await AppConfig.setOverride(host: null, port: null);
  });

  test('first frame sent at open reaches a listener attached after connect() resolves', () async {
    final ws = WsClient();
    addTearDown(ws.disconnect);

    await ws.connect(sessionId: '12345', playerId: 'p1', token: 'good');
    // Exactly the caller pattern of GameController._connectAndSync: listen
    // immediately after the awaited connect() returns.
    final first = ws.events.first;

    final got = await first.timeout(const Duration(seconds: 5));
    expect(got.event, 'GAME_STARTED');
    expect(got.data['round'], 1);
  });

  // Characterization: `events` is a broadcast stream with no buffering, so a
  // caller that awaits anything between connect() and its listen() still loses
  // the frames that arrived in between. GameController._connectAndSync listens
  // synchronously after the await, so it is safe today - this test exists to
  // catch a future caller that stops doing so.
  test('frames are dropped if the caller yields before listening (known limitation)', () async {
    final ws = WsClient();
    addTearDown(ws.disconnect);

    await ws.connect(sessionId: '12345', playerId: 'p1', token: 'good');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    var received = 0;
    ws.events.listen((_) => received++);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(received, 0, reason: 'broadcast stream does not replay; listen right after connect()');
  });

  test('rejected handshake makes connect() throw instead of reporting success', () async {
    final ws = WsClient();
    var disconnectedCalls = 0;
    ws.onDisconnected = () => disconnectedCalls++;

    await expectLater(
      ws.connect(sessionId: '12345', playerId: 'p1', token: 'bad'),
      throwsA(isA<Object>()),
    );
    // The failed attempt must not leave a half-open socket behind.
    expect(disconnectedCalls, 0, reason: 'a never-opened socket must not report a drop');
    await ws.disconnect();
  });

  test('connect() completing means the socket is really open (send works immediately)', () async {
    final ws = WsClient();
    addTearDown(ws.disconnect);
    final serverGot = Completer<String>();

    await ws.connect(sessionId: '12345', playerId: 'p1', token: 'good');
    while (sockets.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    sockets.first.listen((m) {
      if (!serverGot.isCompleted) serverGot.complete(m as String);
    });
    ws.send('CHAT', {'text': 'ping'});

    final raw = await serverGot.future.timeout(const Duration(seconds: 5));
    expect(jsonDecode(raw)['type'], 'CHAT');
  });
}
