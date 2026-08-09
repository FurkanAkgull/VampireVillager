import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vampir_koylu/core/constants/app_theme.dart';
import 'package:vampir_koylu/models/chat_toast.dart';
import 'package:vampir_koylu/models/player.dart';
import 'package:vampir_koylu/models/session_state.dart';
import 'package:vampir_koylu/state/game_controller.dart';
import 'package:vampir_koylu/widgets/chat_notification.dart';
import 'package:vampir_koylu/widgets/unread_chat_badge.dart';
import 'package:vampir_koylu/features/game/game_screen.dart';

SessionState _state(String status) => SessionState(
      sessionId: 'ABC123',
      status: status,
      hostPlayerId: 'p0',
      maxPlayers: 6,
      activeRoles: const {},
      phase: status,
      phaseStartedAt: 1000,
      phaseEndsAt: 1090,
      round: 1,
      players: List.generate(
        6,
        (i) => PlayerInfo(
          playerId: 'p$i',
          nickname: 'Oyuncu$i',
          alive: true,
          connected: true,
          isHost: i == 0,
          role: i == 1 ? 'VAMPIRE' : 'UNKNOWN',
        ),
      ),
      winner: null,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(backgroundColor: AppColors.bgPrimary, body: Center(child: child)),
    );

void main() {
  group('UnreadChatBadge (spec 3.1)', () {
    testWidgets('renders nothing at zero', (t) async {
      await t.pumpWidget(_wrap(const UnreadChatBadge(count: 0)));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders the count and caps it', (t) async {
      await t.pumpWidget(_wrap(const UnreadChatBadge(count: 3)));
      expect(find.text('3'), findsOneWidget);
      await t.pumpWidget(_wrap(const UnreadChatBadge(count: 12)));
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('ChatNotification (spec 3, 3.4, 3.5)', () {
    testWidgets('single message shows sender and preview', (t) async {
      await t.pumpWidget(_wrap(const ChatNotification(
        nickname: 'Ahmet',
        message: 'Bence Furkan vampir.',
        count: 1,
      )));
      expect(find.text('Ahmet'), findsOneWidget);
      expect(find.text('Bence Furkan vampir.'), findsOneWidget);
    });

    testWidgets('a burst collapses into one "N yeni mesaj" toast', (t) async {
      await t.pumpWidget(_wrap(const ChatNotification(
        nickname: 'Ahmet',
        message: 'Bence Furkan vampir.',
        count: 5,
      )));
      expect(find.textContaining('5'), findsOneWidget);
      expect(find.text('Bence Furkan vampir.'), findsNothing);
    });

    testWidgets('vampire channel is labelled', (t) async {
      await t.pumpWidget(_wrap(const ChatNotification(
        nickname: 'Ahmet',
        message: 'plan',
        vampireChannel: true,
      )));
      expect(find.textContaining(RegExp('VAMP', caseSensitive: false)), findsWidgets);
    });

    testWidgets('tap opens the chat', (t) async {
      var tapped = false;
      await t.pumpWidget(_wrap(ChatNotification(
        nickname: 'Ahmet',
        message: 'plan',
        onTap: () => tapped = true,
      )));
      await t.tap(find.byType(ChatNotification));
      expect(tapped, isTrue);
    });
  });

  group('GameController chat state (spec 3.1, 3.2)', () {
    test('markChatOpened clears unread count and pending toast', () {
      final c = GameController()
        ..unreadCount = 4
        ..unreadVampire = true
        ..pendingChatToast = const ChatToastInfo(
          count: 4,
          nickname: '',
          message: '',
          vampireChannel: true,
        );
      c.markChatOpened();
      expect(c.unreadCount, 0);
      expect(c.pendingChatToast, isNull);
      expect(c.unreadVampire, isFalse);
      expect(c.chatScreenOpen, isTrue);
    });

    test('markChatClosed re-arms notifications', () {
      final c = GameController()..markChatOpened();
      c.markChatClosed();
      expect(c.chatScreenOpen, isFalse);
    });

    test('clearChatToast only drops the toast, not the unread count', () {
      final c = GameController()
        ..unreadCount = 2
        ..pendingChatToast = const ChatToastInfo(
          count: 2,
          nickname: '',
          message: '',
          vampireChannel: false,
        );
      c.clearChatToast();
      expect(c.pendingChatToast, isNull);
      expect(c.unreadCount, 2);
    });
  });

  group('GameScreen wiring', () {
    testWidgets('unread count reaches the chat badge', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      final c = GameController()
        ..state = _state('DAY')
        ..playerId = 'p2'
        ..myRole = 'VILLAGER'
        ..roleRevealSeen = true
        ..unreadCount = 3;

      await t.pumpWidget(ChangeNotifierProvider<GameController>.value(
        value: c,
        child: const MaterialApp(home: GameScreen()),
      ));
      await t.pump();
      expect(find.byType(UnreadChatBadge), findsWidgets);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('a pending toast is rendered over the board', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      final c = GameController()
        ..state = _state('DAY')
        ..playerId = 'p2'
        ..myRole = 'VILLAGER'
        ..roleRevealSeen = true
        ..unreadCount = 5
        ..pendingChatToast = const ChatToastInfo(
          count: 5,
          nickname: 'Ahmet',
          message: 'x',
          vampireChannel: false,
        );

      await t.pumpWidget(ChangeNotifierProvider<GameController>.value(
        value: c,
        child: const MaterialApp(home: GameScreen()),
      ));
      await t.pump();
      expect(find.byType(ChatNotification), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}
