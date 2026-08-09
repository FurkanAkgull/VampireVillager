import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vampir_koylu/core/constants/app_config.dart';
import 'package:vampir_koylu/state/game_controller.dart';

/// End-to-end checks for the chat notification pipeline (spec §3.2 - §3.4).
///
/// The unread/batching logic lives in a private handler fed by the websocket,
/// so it can only be exercised against a real server. Start the backend first:
///
///   cd backend && venv/Scripts/python -m uvicorn main:app --port 8011
///   flutter test test/chat_notification_live_test.dart --dart-define=VK_TEST_PORT=8011
///
/// If no server answers, the whole group is skipped instead of failing.
const _host = String.fromEnvironment('VK_TEST_HOST', defaultValue: '127.0.0.1');
const _port = int.fromEnvironment('VK_TEST_PORT', defaultValue: 8000);

Future<bool> _serverUp() async {
  try {
    final s = await Socket.connect(_host, _port, timeout: const Duration(seconds: 1));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // let the http package reach the real server
  SharedPreferences.setMockInitialValues({});

  late bool up;
  setUpAll(() async {
    up = await _serverUp();
    await AppConfig.setOverride(host: _host, port: _port);
  });

  Future<List<GameController>> pair() async {
    final host = GameController();
    await host.createSession(
      nickname: 'Host',
      maxPlayers: 4,
      activeRoles: const {'VAMPIRE': 1},
    );
    final guest = GameController();
    await guest.joinSession(
      sessionId: host.sessionId!,
      password: host.plainPassword!,
      nickname: 'Konuk',
    );
    // WsClient.connect() returns before the socket handshake finishes, so give
    // both sockets a moment to register server-side before chatting.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return [host, guest];
  }

  test('chat closed -> unread count grows and one toast appears', () async {
    if (!up) return;
    final [host, guest] = await pair();
    addTearDown(guest.leaveSession);
    addTearDown(host.leaveSession);

    guest.markChatClosed();
    await host.sendChat('merhaba');
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(guest.chat.length, 1);
    expect(guest.unreadCount, 1);
    expect(guest.pendingChatToast, isNotNull);
    expect(guest.pendingChatToast!.count, 1);
    expect(guest.pendingChatToast!.nickname, 'Host');
    expect(guest.pendingChatToast!.message, 'merhaba');

    // The sender never notifies itself.
    expect(host.unreadCount, 0);
    expect(host.pendingChatToast, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('chat open -> message is stored but no notification (spec 3.2)', () async {
    if (!up) return;
    final [host, guest] = await pair();
    addTearDown(guest.leaveSession);
    addTearDown(host.leaveSession);

    guest.markChatOpened();
    await host.sendChat('görüyorum');
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(guest.chat.length, 1);
    expect(guest.unreadCount, 0);
    expect(guest.pendingChatToast, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a burst of 5 messages produces one batched toast (spec 3.4)', () async {
    if (!up) return;
    final [host, guest] = await pair();
    addTearDown(guest.leaveSession);
    addTearDown(host.leaveSession);

    var toasts = 0;
    guest.addListener(() {
      if (guest.pendingChatToast != null) toasts++;
    });

    guest.markChatClosed();
    for (var i = 0; i < 5; i++) {
      await host.sendChat('mesaj $i');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(guest.chat.length, 5);
    expect(guest.unreadCount, 5); // badge shows 5
    expect(guest.pendingChatToast, isNotNull);
    expect(guest.pendingChatToast!.count, 5); // one "5 yeni mesaj" toast
    expect(guest.pendingChatToast!.isBatch, isTrue);
    expect(toasts, 1, reason: 'a burst must not raise one toast per message');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('opening the chat resets the unread counter (spec 3.1)', () async {
    if (!up) return;
    final [host, guest] = await pair();
    addTearDown(guest.leaveSession);
    addTearDown(host.leaveSession);

    guest.markChatClosed();
    await host.sendChat('bir');
    await host.sendChat('iki');
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    expect(guest.unreadCount, 2);

    guest.markChatOpened();
    expect(guest.unreadCount, 0);
    expect(guest.pendingChatToast, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
