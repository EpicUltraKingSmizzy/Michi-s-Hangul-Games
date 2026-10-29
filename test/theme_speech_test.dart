import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setUp(WidgetTester tester, {bool spoken = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: spoken,
    AppState.kVibration: false,
  });
  await tester.runAsync(appState.load);
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

/// Taps the tiles that spell [r.answer1], in order; returns the syllables.
Future<List<String>> _spell(WidgetTester tester, TypingRound r) async {
  final used = <int>{};
  final placed = <String>[];
  for (final ch in r.answer1.split('').where((c) => c.trim().isNotEmpty)) {
    final i = [for (var k = 0; k < r.charButtons.length; k++) k]
        .firstWhere((k) => !used.contains(k) && r.charButtons[k] == ch);
    used.add(i);
    placed.add(ch);
    await tester.tap(find.byKey(ValueKey('tile_$i')));
    await tester.pump();
  }
  return placed;
}

void main() {
  tearDown(() => Speaker.debugSpoken = null);

  test('syllable speech rule', () {
    expect(shouldSpeakSyllable('가', winsNow: false, spokenAnswer: true), isTrue);
    expect(shouldSpeakSyllable('가', winsNow: false, spokenAnswer: false), isFalse);
    // Winning tap: the win readout says the whole word instead.
    expect(shouldSpeakSyllable('가', winsNow: true, spokenAnswer: true), isFalse);
    // Spoken Answer off: syllables stay silent too.
    expect(shouldSpeakSyllable('가', winsNow: true, spokenAnswer: false), isFalse);
    expect(shouldSpeakSyllable('a', winsNow: false, spokenAnswer: true), isFalse);
  });

  test('9️⃣ theme is the rainbow; no amber left', () {
    final info = gameInfos[8];
    expect(info.gradient, rainbowGradient);
    expect(info.color, isNot(const Color(0xFFF2A000)));
    expect(info.fill().gradient, isNotNull);
    expect(gameInfos[1].fill().gradient, isNull);
    expect(gameInfos[1].fill().color, gameInfos[1].color);
  });

  testWidgets('3️⃣: no stars, x / 5 sits centred inside the green bar', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 3)));
    await tester.pump();
    final r = _state(tester).currentRound as TypingRound;
    expect(find.text('0 / ${r.repetitions}'), findsOneWidget);
    for (var i = 1; i <= 2; i++) {
      await tester.enterText(find.byType(TextField), r.answer1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
    final label = find.byKey(const ValueKey('reps_label'));
    expect(tester.widget<Text>(label).data, '2 / ${r.repetitions}');
    // The word itself may be ⭐ (별 Star): only look for stars elsewhere.
    Finder stars(String star) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(star) && w.data != r.prompt,
    );
    expect(stars('⭐'), findsNothing);
    expect(stars('☆'), findsNothing);
    final bar = tester.getRect(find.byKey(const ValueKey('reps_bar')));
    final text = tester.getRect(label);
    expect(bar.contains(text.topLeft) && bar.contains(text.bottomRight), isTrue);
    expect((bar.center - text.center).distance, lessThan(1.5));
    expect(bar.height, greaterThanOrEqualTo(30));
    await _tearDown(tester);
  });

  testWidgets('3️⃣–6️⃣: no 🔊 for the player\'s own input', (tester) async {
    await _setUp(tester);
    for (final game in [3, 4, 5, 6]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: game),
        ),
      );
      await tester.pump();
      final r = _state(tester).currentRound as TypingRound;
      // English prompt and hidden hint (4️⃣–6️⃣): no 🔊 at all. 3️⃣ shows the
      // hint (the answer) from the start, with its 🔊.
      expect(r.promptIsKorean, isFalse);
      expect(find.byType(SpeakButton), findsNWidgets(game == 3 ? 1 : 0), reason: 'game $game');
      if (game <= 4) {
        expect(
          find.descendant(of: find.byType(TextField), matching: find.byType(SpeakButton)),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    await _tearDown(tester);
  });

  testWidgets('5️⃣/6️⃣: placing a syllable reads it; removing does not', (tester) async {
    await _setUp(tester, spoken: true);
    for (final game in [5, 6]) {
      Speaker.debugSpoken = [];
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: game),
        ),
      );
      await tester.pump();
      final r = _state(tester).currentRound as TypingRound;
      await tester.tap(find.byKey(const ValueKey('tile_0')));
      await tester.pump();
      expect(Speaker.debugSpoken, [r.charButtons[0]]);
      await tester.tap(find.byKey(const ValueKey('slot_0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tile_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tile_backspace')));
      await tester.pump();
      expect(Speaker.debugSpoken, [r.charButtons[0], r.charButtons[1]]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    await _tearDown(tester);
  });

  testWidgets('5️⃣ win with Spoken Answer on: last tap goes straight to the word', (tester) async {
    await _setUp(tester, spoken: true);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 5)));
    await tester.pump();
    final r = _state(tester).currentRound as TypingRound;
    Speaker.debugSpoken = [];
    final placed = await _spell(tester, r);
    expect(appState.sessionWins[5], 1);
    expect(Speaker.debugSpoken, [...placed.take(placed.length - 1), r.answer1]);
    await tester.pump(const Duration(seconds: 2));
    expect(Speaker.debugSpoken!.where((t) => t == r.answer1).length, 1, reason: 'said once');
    await _tearDown(tester);
  });

  testWidgets('5️⃣ win with Spoken Answer off: no syllables, no word', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 5)));
    await tester.pump();
    final r = _state(tester).currentRound as TypingRound;
    Speaker.debugSpoken = [];
    await _spell(tester, r);
    expect(Speaker.debugSpoken, isEmpty);
    await _tearDown(tester);
  });

  testWidgets('9️⃣ screen and tile use the rainbow theme', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
    await tester.pump();
    final bg = tester.widget<FunBackground>(find.byType(FunBackground));
    expect(bg.colors, gameInfos[8].shades(Colors.white, 0.84));
    final r = _state(tester).currentRound as ColorRound;
    if (!r.colorInBox) {
      final card = tester.widget<ThemedBorderBox>(find.byKey(const ValueKey('prompt_card')));
      expect(card.info.gradient, rainbowGradient);
    }
    // Win a round, then the home tile's 🏆 badge is rainbow text.
    final i = r.options.indexWhere((o) => o.id == r.target.id);
    await tester.tap(find.byKey(ValueKey('color_option_$i')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('rainbow_badge')), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _tearDown(tester);
  });
}
