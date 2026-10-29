import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en) =>
    VocabEntry(sectionName: '$ko|$en', packId: 't', korean1: ko, english1: en, emoji: '');

final _words = [
  _w('사과나무', 'Apple tree'),
  _w('냉장고', 'Fridge'),
  _w('텔레비전', 'TV'),
  _w('고양이', 'Cat'),
  _w('강아지', 'Puppy'),
  _w('도서관', 'Library'),
];

dynamic _state(WidgetTester t) => t.state(find.byType(GameScreen));

Future<void> _open(WidgetTester tester, int game, {int seed = 1}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kVibration: false,
    AppState.kSpokenAnswer: false,
  });
  await tester.runAsync(appState.load);
  Speaker.debugSpoken = [];
  appState.engine = GameEngine(_words, random: Random(seed));
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(key: UniqueKey(), game: game),
    ),
  );
  await tester.pump();
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

List<String> _answer(Object r) => r is TimeRound
    ? r.syllables
    : (r as TypingRound).answer1.split('').where((c) => c.trim().isNotEmpty).toList();

String _full(Object r) => r is TimeRound ? r.korean : (r as TypingRound).answer1;

void main() {
  for (final game in [GameEngine.timeGame, 5, 6]) {
    testWidgets('game $game: ? ghosts the answer in the slots and shows 🔊', (tester) async {
      await _open(tester, game);
      final r = _state(tester).currentRound as Object;
      final chars = _answer(r);
      expect(find.byKey(const ValueKey('ghost_0')), findsNothing);
      expect(find.byKey(const ValueKey('hint_speak')), findsNothing);

      await tester.tap(find.text('?'));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < chars.length; i++) {
        final g = tester.widget<Text>(find.byKey(ValueKey('ghost_$i')));
        expect(g.data, chars[i]);
        expect(g.style!.color!.a, lessThan(0.5));
      }
      // No answer text above/below the game.
      expect(find.text(_full(r)), findsNothing);
      expect(find.byKey(const ValueKey('time_hint')), findsNothing);

      // A tile covers the ghost; ⌫ brings it back.
      final tiles = r is TimeRound ? r.tiles : (r as TypingRound).charButtons;
      await tester.tap(find.byKey(ValueKey('tile_${tiles.indexOf(chars[0])}')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('ghost_0')), findsNothing);
      expect(find.byKey(const ValueKey('ghost_1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tile_backspace')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('ghost_0')), findsOneWidget);

      // 🔊 reads the full answer, even with Spoken Answer off.
      await tester.tap(find.byKey(const ValueKey('hint_speak')));
      await tester.pump();
      expect(Speaker.debugSpoken, contains(_full(r)));

      // Next round: hidden again.
      await tester.tap(find.text('➡️'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('hint_speak')), findsNothing);
      expect(find.byKey(const ValueKey('ghost_0')), findsNothing);
      await _done(tester);
    });
  }

  testWidgets('🕒 sky rounds: hint marks the right 오전/오후 and 🔊 says it', (tester) async {
    var seed = 0;
    while (!(GameEngine([], random: Random(seed)).newRound(2) as TimeRound).showSky) {
      seed++;
    }
    await _open(tester, GameEngine.timeGame, seed: seed);
    final r = _state(tester).currentRound as TimeRound;
    BouncyButton btn(String p) => tester.widget<BouncyButton>(find.byKey(ValueKey('period_$p')));
    final other = r.period == '오전' ? '오후' : '오전';
    expect(btn(r.period).borderColor, isNull);
    await tester.tap(find.text('?'));
    await tester.pump();
    expect(btn(r.period).borderColor, isNotNull);
    expect(btn(other).borderColor, isNull);
    await tester.tap(find.byKey(const ValueKey('hint_speak')));
    await tester.pump();
    expect(Speaker.debugSpoken!.last, startsWith(r.period));
    expect(Speaker.debugSpoken!.last, r.korean);
    await _done(tester);
  });
}
