import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setUp(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

Future<void> _typeRight(WidgetTester tester, TypingRound r) async {
  await tester.enterText(find.byType(TextField), r.answer1);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  group('3️⃣✍️ repetitions setting', () {
    test('defaults to 3, is saved, loads back and is clamped to 1-5', () async {
      SharedPreferences.setMockInitialValues({});
      await appState.load();
      expect(appState.game3Repetitions, 3);
      expect(appState.engine.game3Repetitions, 3);
      expect((appState.engine.newRound(3) as TypingRound).repetitions, 3);

      await appState.setGame3Repetitions(5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppState.kGame3Repetitions), 5);
      expect((appState.engine.newRound(3) as TypingRound).repetitions, 5);
      await appState.load();
      expect(appState.game3Repetitions, 5, reason: 'saved between sessions');
      expect((appState.engine.newRound(3) as TypingRound).repetitions, 5);

      await appState.setGame3Repetitions(9);
      expect(appState.game3Repetitions, 5);
      await appState.setGame3Repetitions(0);
      expect(appState.game3Repetitions, 1);
      SharedPreferences.setMockInitialValues({AppState.kGame3Repetitions: 42});
      await appState.load();
      expect(appState.game3Repetitions, 5);
      // Other games are unaffected.
      expect((appState.engine.newRound(4) as TypingRound).repetitions, 1);
    });

    testWidgets('Options: labelled slider shows the value and saves it', (tester) async {
      await _setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      final card = find.byKey(const ValueKey('opt_game3_repetitions'));
      await tester.scrollUntilVisible(card, 200);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('Typing repetitions'), findsOneWidget);
      final value = find.byKey(const ValueKey('opt_game3_repetitions_value'));
      expect(tester.widget<Text>(value).data, '3');
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('opt_game3_repetitions_slider')),
      );
      expect([slider.min, slider.max, slider.divisions], [1, 5, 4]);
      // Right below the 🔀 Shuffle games row.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 150));
      await tester.pumpAndSettle();
      final toggle = tester.getRect(find.byKey(const ValueKey('opt_shuffle_games')));
      expect(tester.getRect(card).top - toggle.bottom, lessThan(30));

      final s = find.byKey(const ValueKey('opt_game3_repetitions_slider'));
      await tester.drag(s, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(appState.game3Repetitions, 5);
      expect(tester.widget<Text>(value).data, '5');
      await tester.drag(s, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(appState.game3Repetitions, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppState.kGame3Repetitions), 1);
      expect(tester.takeException(), isNull);
      await _tearDown(tester);
    });

    testWidgets('3️⃣ wins after N typings; a change applies from the next word', (tester) async {
      await _setUp(tester, {AppState.kGame3Repetitions: 2});
      final before = appState.sessionWins[3] ?? 0;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 3)));
      await tester.pump();
      var r = _state(tester).currentRound as TypingRound;
      expect(r.repetitions, 2);
      expect(find.text('0 / 2'), findsOneWidget);
      await _typeRight(tester, r);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(appState.sessionWins[3], before);

      // Changed mid-word: this word still needs 2.
      await appState.setGame3Repetitions(4);
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
      await _typeRight(tester, r);
      expect(appState.sessionWins[3], before + 1);

      // The next word uses 4.
      expect(identical(_state(tester).currentRound, r), isFalse);
      r = _state(tester).currentRound as TypingRound;
      expect(r.repetitions, 4);
      expect(find.text('0 / 4'), findsOneWidget);
      for (var i = 1; i < 4; i++) {
        await _typeRight(tester, r);
        expect(find.text('$i / 4'), findsOneWidget);
      }
      await _typeRight(tester, r);
      expect(appState.sessionWins[3], before + 2);
      await _tearDown(tester);
    });

    testWidgets('N = 1: one right typing wins, no progress bar', (tester) async {
      await _setUp(tester, {AppState.kGame3Repetitions: 1});
      final before = appState.sessionWins[3] ?? 0;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 3)));
      await tester.pump();
      final r = _state(tester).currentRound as TypingRound;
      expect(r.repetitions, 1);
      expect(find.byKey(const ValueKey('reps_bar')), findsNothing);
      await _typeRight(tester, r);
      expect(appState.sessionWins[3], before + 1);
      await _tearDown(tester);
    });

    testWidgets('🔀 Shuffle uses the setting for 3️⃣', (tester) async {
      await _setUp(tester, {AppState.kGame3Repetitions: 4});
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      var tries = 0;
      while (_state(tester).currentGame != 3 && tries++ < 300) {
        await tester.tap(find.text('➡️'));
        await tester.pump();
      }
      expect(_state(tester).currentGame, 3);
      final r = _state(tester).currentRound as TypingRound;
      expect(r.repetitions, 4);
      expect(find.text('0 / 4'), findsOneWidget);
      await _tearDown(tester);
    });
  });
}
