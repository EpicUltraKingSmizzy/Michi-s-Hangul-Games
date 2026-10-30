import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic _state(WidgetTester t) => t.state(find.byType(GameScreen));
final _prompt = find.byKey(const ValueKey('native_prompt'));

Future<void> _setUp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kVibration: false,
    AppState.kSpokenAnswer: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
  Speaker.debugSpoken = [];
  appState.engine = GameEngine(appState.activeVocab(), random: Random(5))
    ..nativeMax = appState.nativeMax;
}

/// Solves the current 🖐️ round and lets the win pause run.
Future<void> _winRound(WidgetTester tester) async {
  final r = _state(tester).currentRound;
  switch (r) {
    case ChoiceRound c:
      await tester.tap(find.text(c.correctAnswer).last);
    case TypingRound t when isKeypadRound(t):
      for (final d in t.answer1.split('')) {
        await tester.tap(find.byKey(ValueKey('key_$d')));
        await tester.pump();
      }
    case TypingRound t:
      for (var i = 0; i < t.repetitions; i++) {
        await tester.enterText(find.byType(TextField), t.answer1);
        await tester.pump(const Duration(milliseconds: 600));
      }
  }
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _open(WidgetTester tester, {bool shuffle = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: shuffle ? GameScreen.shuffle(key: UniqueKey()) : GameScreen(key: UniqueKey(), game: 8),
    ),
  );
  await tester.pump();
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _closePrompt(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('native_prompt_done')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('default 10, persists, snaps to stops, 99 sets the flag', (tester) async {
    await _setUp(tester);
    expect(appState.nativeMax, 10);
    expect(appState.native99Reached, isFalse);
    await appState.setNativeMax(50);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppState.kNativeMax), 50);
    await tester.runAsync(appState.load);
    expect(appState.nativeMax, 50);
    expect(appState.engine.nativeMax, 50);
    await appState.setNativeMax(99);
    await appState.setNativeMax(30);
    await tester.runAsync(appState.load);
    expect(appState.nativeMax, 30);
    expect(appState.native99Reached, isTrue);
  });

  test('numbers stay within 1..limit at every stop', () {
    for (final max in GameEngine.nativeMaxStops) {
      final e = GameEngine([], random: Random(max))..nativeMax = max;
      final seen = <int>{};
      for (var i = 0; i < 400; i++) {
        e.newRound(8);
        final n = int.parse(e.gameHistory[8]!.last);
        expect(n, inInclusiveRange(1, max), reason: 'limit $max');
        seen.add(n);
      }
      expect(seen.contains(max), isTrue, reason: 'limit $max is reachable');
      if (max > 10) expect(seen.any((n) => n > 10), isTrue);
    }
  });

  testWidgets('Options: slider sits right below the Sino option and saves', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    final card = find.byKey(const ValueKey('opt_native_max'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    final sino = tester.getRect(find.byKey(const ValueKey('opt_game7_max_digits')));
    expect(tester.getRect(card).top - sino.bottom, inInclusiveRange(0, 30));
    expect(find.text('Number range'), findsOneWidget);
    final slider = find.descendant(of: card, matching: find.byType(Slider));
    await tester.drag(slider, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(appState.nativeMax, 99);
    expect(appState.native99Reached, isTrue);
  });

  testWidgets('Shuffle respects the limit', (tester) async {
    await _setUp(tester);
    for (var g = 1; g <= GameEngine.gameCount; g++) {
      if (g != 8) await appState.setShuffleGame(g, false);
    }
    await _open(tester, shuffle: true);
    for (var i = 0; i < 6; i++) {
      final n = int.parse(appState.engine.gameHistory[8]!.last);
      expect(n, inInclusiveRange(1, 10));
      await _winRound(tester);
    }
    expect(_state(tester).streakCount, greaterThanOrEqualTo(5));
    expect(_prompt, findsNothing);
    await _done(tester);
  });

  testWidgets('prompt at 5 and 10 in a row; dialog slider changes the setting', (tester) async {
    await _setUp(tester);
    await _open(tester);
    for (var i = 0; i < 4; i++) {
      await _winRound(tester);
      expect(_prompt, findsNothing, reason: 'win ${i + 1}');
    }
    await _winRound(tester);
    expect(_prompt, findsOneWidget);
    expect(find.text('🔥 5 in a row! Ready for bigger numbers?'), findsOneWidget);
    expect(find.text('Raise the top number and keep counting!'), findsOneWidget);
    final card = find.descendant(
      of: _prompt,
      matching: find.byKey(const ValueKey('opt_native_max')),
    );
    expect(card, findsOneWidget);
    // One stop to the right: 10 → 30.
    final slider = find.descendant(of: card, matching: find.byType(Slider));
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + 24 + (rect.width - 48) / 3, rect.center.dy));
    await tester.pump();
    expect(appState.nativeMax, 30);
    expect(appState.engine.nativeMax, 30);
    await _closePrompt(tester);
    expect(_prompt, findsNothing);
    for (var i = 0; i < 5; i++) {
      await _winRound(tester);
      if (i < 4) expect(_prompt, findsNothing);
    }
    expect(find.text('🔥 10 in a row! Ready for bigger numbers?'), findsOneWidget);
    await _closePrompt(tester);
    await _done(tester);
  });

  testWidgets('no prompt at 99, nor ever again once 99 was reached', (tester) async {
    await _setUp(tester, prefs: {AppState.kNativeMax: 99});
    await _open(tester);
    for (var i = 0; i < 5; i++) {
      await _winRound(tester);
    }
    expect(_prompt, findsNothing);
    await _done(tester);

    await appState.setNativeMax(10);
    expect(appState.native99Reached, isTrue);
    appState.engine.nativeMax = 10;
    await _open(tester);
    for (var i = 0; i < 5; i++) {
      await _winRound(tester);
    }
    expect(_state(tester).streakCount, 5);
    expect(_prompt, findsNothing);
    await _done(tester);
  });
}
