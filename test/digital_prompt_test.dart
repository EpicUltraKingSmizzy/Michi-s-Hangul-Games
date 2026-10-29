import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic _state(WidgetTester t) => t.state(find.byType(GameScreen));
final _prompt = find.byKey(const ValueKey('digital_prompt'));

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
  appState.engine = GameEngine([], random: Random(3));
}

/// Solves the current 🕒 round and lets the win pause run.
Future<void> _winRound(WidgetTester tester) async {
  final r = _state(tester).currentRound as TimeRound;
  final used = <int>{};
  for (final c in r.syllables) {
    final i = [for (var i = 0; i < r.tiles.length; i++) i]
        .firstWhere((i) => r.tiles[i] == c && !used.contains(i));
    used.add(i);
    await tester.tap(find.byKey(ValueKey('tile_$i')));
    await tester.pump();
  }
  if (r.showSky) await tester.tap(find.byKey(ValueKey('period_${r.period}')));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _openTime(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(key: UniqueKey(), game: GameEngine.timeGame),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows after the 5th win in a row, once ever; toggle works', (tester) async {
    await _setUp(tester);
    await _openTime(tester);
    for (var i = 0; i < 4; i++) {
      await _winRound(tester);
      expect(_prompt, findsNothing, reason: 'win ${i + 1}');
    }
    await _winRound(tester);
    expect(_prompt, findsOneWidget);
    expect(find.text('🔥 5 in a row! Ready for a bigger challenge?'), findsOneWidget);
    expect(appState.digitalPromptShown, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppState.kDigitalPromptShown), isTrue);

    // Same ⌚ tile as Options, bound to the setting.
    final tile = find.descendant(
      of: _prompt,
      matching: find.byKey(const ValueKey('opt_show_digital_time')),
    );
    expect(tile, findsOneWidget);
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pump();
    expect(appState.showDigitalTime, isFalse);
    expect(prefs.getBool(AppState.kShowDigitalTime), isFalse);
    await tester.tap(find.byKey(const ValueKey('digital_prompt_done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_prompt, findsNothing);
    expect(find.byKey(const ValueKey('time_digital')), findsNothing);

    // Never again, even after a reload and another 5 in a row.
    await appState.setShowDigitalTime(true);
    await tester.runAsync(appState.load);
    await _openTime(tester);
    for (var i = 0; i < 6; i++) {
      await _winRound(tester);
    }
    expect(_prompt, findsNothing);
    await _done(tester);
  });

  testWidgets('not in 🔀 Shuffle', (tester) async {
    await _setUp(tester);
    for (var g = 1; g <= GameEngine.gameCount; g++) {
      if (g != GameEngine.timeGame) await appState.setShuffleGame(g, false);
    }
    await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await _winRound(tester);
    }
    expect(_state(tester).streakCount, greaterThanOrEqualTo(5));
    expect(_prompt, findsNothing);
    expect(appState.digitalPromptShown, isFalse);
    await _done(tester);
  });

  testWidgets('not shown when ⌚ is already off (flag still set)', (tester) async {
    await _setUp(tester, prefs: {AppState.kShowDigitalTime: false});
    await _openTime(tester);
    for (var i = 0; i < 5; i++) {
      await _winRound(tester);
    }
    expect(_prompt, findsNothing);
    expect(appState.digitalPromptShown, isTrue);
    await _done(tester);
  });
}
