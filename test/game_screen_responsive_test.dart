import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:vampir_koylu/core/constants/app_theme.dart';
import 'package:vampir_koylu/features/game/game_screen.dart';
import 'package:vampir_koylu/features/game/role_reveal_screen.dart';
import 'package:vampir_koylu/models/night_resolution.dart';
import 'package:vampir_koylu/models/player.dart';
import 'package:vampir_koylu/models/session_state.dart';
import 'package:vampir_koylu/state/game_controller.dart';

SessionState _state(String status) => SessionState(
      sessionId: 'ABC123',
      status: status,
      hostPlayerId: 'p0',
      maxPlayers: 12,
      activeRoles: const {},
      phase: status,
      phaseStartedAt: 1000,
      phaseEndsAt: 1090,
      round: 2,
      players: List.generate(
        12,
        (i) => PlayerInfo(
          playerId: 'p$i',
          nickname: 'OyuncuUzunIsim$i',
          alive: i % 4 != 0,
          connected: true,
          isHost: i == 0,
          role: i == 1 ? 'VAMPIRE' : 'UNKNOWN',
        ),
      ),
      winner: null,
    );

const _sizes = [
  Size(320, 568), // smallest phone we support
  Size(360, 640),
  Size(390, 844),
  Size(640, 360), // phone landscape
  Size(700, 1000), // exactly on the wide breakpoint
  Size(820, 1180), // tablet
  Size(1000, 800),
];

void main() {
  for (final size in _sizes) {
    for (final status in const ['NIGHT', 'DAY']) {
      testWidgets('no overflow at $size / $status', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final c = GameController()
          ..state = _state(status)
          ..playerId = 'p1'
          ..myRole = 'VAMPIRE'
          ..roleRevealSeen = true;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameController>.value(
            value: c,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const GameScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow for an eliminated spectator at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = GameController()
        ..state = _state('DAY')
        ..playerId = 'p0' // p0 is dead in the fixture
        ..myRole = 'VILLAGER'
        ..roleRevealSeen = true
        ..eliminationSeen = true;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameController>.value(
          value: c,
          child: MaterialApp(theme: AppTheme.dark, home: const GameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('night resolution takeover has no overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = GameController()
        ..state = _state('DAY')
        ..playerId = 'p1'
        ..myRole = 'VAMPIRE'
        ..roleRevealSeen = true
        ..nightResolution = NightResolutionInfo.fromJson(const {
          'round': 2,
          'summary': {
            'playersDied': ['p3'],
            'playersSaved': ['p5'],
          },
          'actions': [
            {
              'actionType': 'KILL',
              'scope': 'PUBLIC',
              'actorRole': 'VAMPIRE',
              'message': 'Vampirler bir oyuncuyu hedefledi.',
            },
            {
              'actionType': 'PROTECT',
              'scope': 'PRIVATE',
              'actorRole': 'DOCTOR',
              'message': 'Bu gece OyuncuUzunIsim5 korudun.',
            },
          ],
        });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameController>.value(
          value: c,
          child: MaterialApp(theme: AppTheme.dark, home: const GameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('GECE 2 SONUCU'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // On short viewports the button sits below the fold of the scroll view.
      await tester.ensureVisible(find.text('GÜNDÜZE GEÇ'));
      await tester.pump();
      await tester.tap(find.text('GÜNDÜZE GEÇ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('GECE 2 SONUCU'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('role reveal flips without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: RoleRevealScreen(roleId: 'VAMPIRE', onContinue: () {}),
        ),
      );
      await tester.tap(find.text('ROLÜNÜ GÖR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180)); // mid-flip
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 200)); // flipped
      expect(find.text('VAMPIR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
