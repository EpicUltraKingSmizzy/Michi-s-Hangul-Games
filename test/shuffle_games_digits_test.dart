import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/number_translation.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/screens/shuffle_games_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Independent reference: Sino-Korean in 만-groups of four digits, dropping
/// a lone 일 before 십/백/천/만 (the app's convention: 만, 천만, 십육).
String referenceSino(int n) {
  const d = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  String group(int g) {
    final out = StringBuffer();
    for (final (v, u) in [(1000, '천'), (100, '백'), (10, '십')]) {
      final k = g ~/ v % 10;
      if (k > 0) out.write('${k == 1 ? '' : d[k]}$u');
    }
    out.write(d[g % 10]);
    return out.toString();
  }

  final man = n ~/ 10000, rest = n % 10000;
  final high = man == 0 ? '' : '${man == 1 ? '' : group(man)}만';
  return high + group(rest);
}

/// The number the engine just picked for 7️⃣ (its target).
int lastNumber(GameEngine e) => int.parse(e.gameHistory[7]!.last);

enum Kind { digitsToKorean, koreanToDigits, typeKorean, keypad }

Kind kindOf(Object r) => switch (r) {
  ChoiceRound c => c.optionsAreKorean ? Kind.digitsToKorean : Kind.koreanToDigits,
  TypingRound t => isKeypadRound(t) ? Kind.keypad : Kind.typeKorean,
  _ => throw StateError('$r'),
};

Future<void> setUp(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  double dpr = 2.5,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
}

Future<void> tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

dynamic stateOf(WidgetTester tester) => tester.state(find.byType(GameScreen));

void main() {
  group('7️⃣ Sino converter up to 8 digits', () {
    test('known examples', () {
      const cases = {
        99999999: '구천구백구십구만구천구백구십구',
        12345678: '천이백삼십사만오천육백칠십팔',
        10000000: '천만',
        10000001: '천만일',
        10010000: '천일만',
        11111111: '천백십일만천백십일',
        20050300: '이천오만삼백',
        30000016: '삼천만십육',
        16000000: '천육백만',
        1000000: '백만',
        100000: '십만',
        10000: '만',
        10001: '만일',
        21000: '이만천',
        1600: '천육백',
        16: '십육',
        1: '일',
      };
      cases.forEach((n, ko) => expect(numberTranslation(n), ko, reason: '$n'));
    });

    test('matches an independent reference for 1..99,999,999', () {
      final rand = Random(7);
      final samples = [
        for (var i = 0; i < 30000; i++) 1 + rand.nextInt(99999999),
        for (var p = 1; p <= 10000000; p *= 10) ...[p, p - 1 == 0 ? 1 : p - 1, p + 1, 2 * p],
        99999999,
      ];
      for (final n in samples) {
        expect(numberTranslation(n, random: rand), referenceSino(n), reason: '$n');
      }
    });

    test('every 7️⃣ format checks 8-digit answers correctly', () {
      final seen = <Kind>{};
      for (var s = 0; s < 400; s++) {
        final e = GameEngine([], random: Random(s))..game7MaxDigits = 8;
        final r = e.newRound(7);
        final n = lastNumber(e);
        final ko = numberTranslation(n);
        seen.add(kindOf(r));
        switch (r) {
          case ChoiceRound c:
            expect(c.correctAnswer, c.optionsAreKorean ? ko : '$n');
            expect(c.prompt, c.optionsAreKorean ? '$n' : ko);
            expect(c.options.toSet().length, 3);
          case TypingRound t when isKeypadRound(t):
            expect(t.prompt, ko);
            expect(isHelperAnswerComplete('$n', t), isTrue);
            expect(isTypedAnswerCorrect('$n', t), isTrue);
            expect(isTypedAnswerCorrect('${n + 1}', t), isFalse);
          case TypingRound t:
            expect(t.prompt, '$n');
            expect(isTypedAnswerCorrect(ko, t), isTrue);
            // Spaces between 만-groups are fine (phone keyboards add them).
            if (n >= 10000 && n % 10000 != 0) {
              final split = ko.indexOf('만') + 1;
              expect(
                isTypedAnswerCorrect('${ko.substring(0, split)} ${ko.substring(split)}', t),
                isTrue,
              );
            }
            expect(isTypedAnswerCorrect('$n', t), isFalse);
        }
      }
      expect(seen, Kind.values.toSet());
    });
  });

  group('7️⃣ number length', () {
    test('digits are spread evenly over 1..N; N = 1 is always one digit', () {
      for (final maxDigits in [1, 3, 6, 8]) {
        final e = GameEngine([], random: Random(maxDigits))..game7MaxDigits = maxDigits;
        final counts = <int, int>{};
        const rounds = 4000;
        for (var i = 0; i < rounds; i++) {
          e.newRound(7);
          final len = '${lastNumber(e)}'.length;
          counts[len] = (counts[len] ?? 0) + 1;
        }
        expect(counts.keys.toSet(), {
          for (var d = 1; d <= maxDigits; d++) d,
        }, reason: 'N=$maxDigits');
        for (final c in counts.values) {
          expect(
            c,
            closeTo(rounds / maxDigits, rounds / maxDigits * 0.2),
            reason: 'N=$maxDigits $counts',
          );
        }
      }
    });

    test('8️⃣ native numbers are unchanged (1-2 digits)', () {
      final e = GameEngine([], random: Random(3))..game7MaxDigits = 8;
      final lens = <int>{};
      for (var i = 0; i < 500; i++) {
        e.newRound(8);
        lens.add(e.gameHistory[8]!.last.length);
      }
      expect(lens, {1, 2});
    });

    test('setting: default 6, saved, clamped 1-8, passed to the engine', () async {
      SharedPreferences.setMockInitialValues({});
      await appState.load();
      expect(appState.game7MaxDigits, 6);
      expect(appState.engine.game7MaxDigits, 6);
      await appState.setGame7MaxDigits(8);
      expect(appState.engine.game7MaxDigits, 8);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppState.kGame7MaxDigits), 8);
      await appState.load();
      expect(appState.game7MaxDigits, 8);
      expect(appState.engine.game7MaxDigits, 8);
      await appState.setGame7MaxDigits(12);
      expect(appState.game7MaxDigits, 8);
      await appState.setGame7MaxDigits(-3);
      expect(appState.game7MaxDigits, 1);
      SharedPreferences.setMockInitialValues({AppState.kGame7MaxDigits: 99});
      await appState.load();
      expect(appState.game7MaxDigits, 8);
    });

    testWidgets('Options: 7️⃣🔢 number length slider', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      final card = find.byKey(const ValueKey('opt_game7_max_digits'));
      await tester.scrollUntilVisible(card, 200);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('🔢 Number length'), findsOneWidget);
      expect(find.text('The most digits a number can have in 🔢 Sino numbers.'), findsOneWidget);
      final value = find.byKey(const ValueKey('opt_game7_max_digits_value'));
      expect(tester.widget<Text>(value).data, '6');
      final sliderFinder = find.byKey(const ValueKey('opt_game7_max_digits_slider'));
      final slider = tester.widget<Slider>(sliderFinder);
      expect([slider.min, slider.max, slider.divisions], [1, 8, 7]);
      expect(
        slider.activeColor ?? SliderTheme.of(tester.element(sliderFinder)).activeTrackColor,
        gameInfos[6].color,
      );
      await tester.drag(sliderFinder, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(appState.game7MaxDigits, 8);
      expect(tester.widget<Text>(value).data, '8');
      await tester.drag(sliderFinder, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(appState.game7MaxDigits, 1);
      expect(tester.takeException(), isNull);
      await tearDown(tester);
    });

    for (final kind in Kind.values) {
      testWidgets('8-digit 7️⃣ round fits at 360 wide and can be won: ${kind.name}', (
        tester,
      ) async {
        await setUp(
          tester,
          size: const Size(1080, 2400),
          dpr: 3,
          prefs: {AppState.kGame7MaxDigits: 8},
        );
        var seed = 0;
        while (true) {
          final e = GameEngine(appState.activeVocab(), random: Random(seed))..game7MaxDigits = 8;
          final r = e.newRound(7);
          if (kindOf(r) == kind && '${lastNumber(e)}'.length == 8) break;
          seed++;
        }
        appState.engine = GameEngine(appState.activeVocab(), random: Random(seed))
          ..game7MaxDigits = 8;
        final before = appState.sessionWins[7] ?? 0;
        await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 7)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final n = lastNumber(appState.engine);
        expect('$n'.length, 8);
        final ko = numberTranslation(n);
        final r = stateOf(tester).currentRound;
        expect(kindOf(r), kind);
        switch (kind) {
          case Kind.digitsToKorean:
            await tester.tap(find.text(ko));
          case Kind.koreanToDigits:
            await tester.tap(find.text('$n'));
          case Kind.typeKorean:
            await tester.enterText(find.byType(TextField), ko);
          case Kind.keypad:
            final display = find.byKey(const ValueKey('digit-display'));
            for (final d in '$n'.split('').take(7)) {
              await tester.tap(find.byKey(ValueKey('key_$d')));
              await tester.pump();
            }
            expect(
              find.descendant(of: display, matching: find.text('$n'.substring(0, 7))),
              findsOneWidget,
            );
            // The 8-digit display fits on one line inside the box.
            final box = tester.getRect(display);
            final text = tester.getRect(find.descendant(of: display, matching: find.byType(Text)));
            expect(text.width, lessThan(box.width - 20));
            await tester.tap(find.byKey(ValueKey('key_${'$n'[7]}')));
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(appState.sessionWins[7], before + 1);
        await tearDown(tester);
      });
    }

    testWidgets('🔀 Shuffle uses the 7️⃣ setting', (tester) async {
      await setUp(tester, prefs: {AppState.kGame7MaxDigits: 1});
      for (var g = 1; g <= GameEngine.gameCount; g++) {
        if (g != 7) await appState.setShuffleGame(g, false);
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      for (var i = 0; i < 25; i++) {
        expect(stateOf(tester).currentGame, 7);
        expect('${lastNumber(appState.engine)}'.length, 1);
        await tester.tap(find.text('➡️'));
        await tester.pump();
      }
      await appState.setGame7MaxDigits(8);
      final lens = <int>{};
      for (var i = 0; i < 80; i++) {
        await tester.tap(find.text('➡️'));
        await tester.pump();
        lens.add('${lastNumber(appState.engine)}'.length);
      }
      expect(lens, contains(8));
      expect(tester.takeException(), isNull);
      await tearDown(tester);
    });
  });

  group('🔀 Shuffle games', () {
    test('all on by default; switches are saved; the last one stays on', () async {
      SharedPreferences.setMockInitialValues({});
      var a = AppState();
      await a.load();
      expect([for (var g = 1; g <= 11; g++) a.shuffleIncludes(g)], everyElement(isTrue));
      expect(a.shuffleGameCount, 11);
      expect(await a.setShuffleGame(1, false), isTrue);
      expect(await a.setShuffleGame(9, false), isTrue);
      a = AppState();
      await a.load();
      expect(a.shuffleIncludes(1), isFalse);
      expect(a.shuffleIncludes(9), isFalse);
      expect(a.shuffleGameCount, 9);
      for (final g in [2, 3, 4, 5, 6, 7, 10, 11]) {
        expect(await a.setShuffleGame(g, false), isTrue);
      }
      expect(a.shuffleGameCount, 1);
      expect(await a.setShuffleGame(8, false), isFalse, reason: 'last game stays on');
      expect(a.shuffleIncludes(8), isTrue);
      expect(await a.setShuffleGame(1, true), isTrue);
      expect(await a.setShuffleGame(8, false), isTrue);
      expect(a.shuffleGameCount, 1);
    });

    test('migrates the old 3️⃣-in-Shuffle toggle', () async {
      SharedPreferences.setMockInitialValues({AppState.kLegacyShuffleGame3: false});
      var a = AppState();
      await a.load();
      expect(a.shuffleIncludes(3), isFalse);
      expect(a.shuffleGameCount, 10);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppState.kLegacyShuffleGame3), isFalse);
      expect(prefs.getStringList(AppState.kShuffleOff), ['3']);
      a = AppState();
      await a.load();
      expect(a.shuffleIncludes(3), isFalse, reason: 'kept after the migration');

      SharedPreferences.setMockInitialValues({AppState.kLegacyShuffleGame3: true});
      a = AppState();
      await a.load();
      expect(a.shuffleGameCount, 11);

      // A saved list with every game off (should never happen) turns them all on.
      SharedPreferences.setMockInitialValues({
        AppState.kShuffleOff: [for (var g = 1; g <= 11; g++) '$g'],
      });
      a = AppState();
      await a.load();
      expect(a.shuffleGameCount, 11);
    });

    test('picker: only switched-on, playable games; no 3️⃣ twice unless alone', () {
      final rand = Random(5);
      final seen = <int>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(pickShuffleGame(rand, enabled: (g) => g.isOdd, canPlay: (_) => true)!);
      }
      expect(seen, {1, 3, 5, 7, 9, 11});
      for (var i = 0; i < 200; i++) {
        expect(
          pickShuffleGame(
            rand,
            previous: 3,
            enabled: (g) => g == 3 || g == 4,
            canPlay: (_) => true,
          ),
          4,
        );
        expect(pickShuffleGame(rand, previous: 3, enabled: (g) => g == 3, canPlay: (_) => true), 3);
      }
      final noWords = GameEngine([]);
      expect(
        pickShuffleGame(rand, enabled: (g) => g <= 6 && g != 2, canPlay: noWords.canPlay),
        isNull,
      );
      // 🕒 needs no words.
      expect(pickShuffleGame(rand, enabled: (g) => g <= 6, canPlay: noWords.canPlay), 2);
      expect(pickShuffleGame(rand, enabled: (g) => g <= 7 && g != 2, canPlay: noWords.canPlay), 7);
    });

    testWidgets('Options row opens the sub-screen; switches update the summary', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      expect(find.byKey(const ValueKey('opt_shuffle_game3')), findsNothing);
      expect(find.text('3️⃣✍️ in 🔀 Shuffle'), findsNothing);
      final row = find.byKey(const ValueKey('opt_shuffle_games'));
      await tester.scrollUntilVisible(row, 200);
      expect(find.text('🔀 Shuffle games'), findsOneWidget);
      expect(find.text('11 of 11 games'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ShuffleGamesScreen), findsOneWidget);
      for (final info in gameInfos) {
        await tester.scrollUntilVisible(find.text(info.tileName), 200);
        expect(find.text(info.tileName), findsOneWidget);
      }
      // 9️⃣ keeps its rainbow accent.
      final box9 = tester.widget<ThemedBorderBox>(find.byKey(const ValueKey('shuffle_game_9')));
      expect(box9.info.gradient, rainbowGradient);

      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      final sw1 = find.byKey(const ValueKey('shuffle_switch_1'));
      await tester.scrollUntilVisible(sw1, 200);
      await tester.ensureVisible(sw1);
      await tester.pumpAndSettle();
      await tester.tap(sw1);
      await tester.pumpAndSettle();
      expect(appState.shuffleIncludes(1), isFalse);
      // Eleven games make the list longer than the screen: back to the top.
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.textContaining('10\u00A0of\u00A011\u00A0games are on'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('10 of 11 games'), findsOneWidget);
      await tearDown(tester);
    });

    testWidgets('the last game on cannot be switched off (snackbar)', (tester) async {
      await setUp(tester);
      for (final g in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11]) {
        await appState.setShuffleGame(g, false);
      }
      await tester.pumpWidget(const MaterialApp(home: ShuffleGamesScreen()));
      await tester.pump();
      final sw9 = find.byKey(const ValueKey('shuffle_switch_9'));
      await tester.scrollUntilVisible(sw9, 200);
      await tester.ensureVisible(sw9);
      await tester.pumpAndSettle();
      await tester.tap(sw9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(appState.shuffleIncludes(9), isTrue);
      expect(find.text(ShuffleGamesScreen.lastGameMessage), findsOneWidget);
      expect(tester.widget<SwitchListTile>(sw9).value, isTrue);
      await tearDown(tester);
    });

    testWidgets('🔀 Shuffle plays only the switched-on games', (tester) async {
      await setUp(tester);
      for (final g in [1, 2, 4, 5, 6, 8, 9, 10, 11]) {
        await appState.setShuffleGame(g, false);
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      final seen = <int>{};
      for (var i = 0; i < 60; i++) {
        seen.add(stateOf(tester).currentGame as int);
        await tester.tap(find.text('➡️'));
        await tester.pump();
      }
      expect(seen, {3, 7});
      expect(tester.takeException(), isNull);
      await tearDown(tester);
    });

    testWidgets('no switched-on game playable: friendly message at 360 wide', (tester) async {
      await setUp(tester, dpr: 3);
      await appState.setAllPacks(false);
      await appState.setBundleEnabled(customBundleId, false);
      // 🕒 🔢 🖐️ 🎨 and 🏗️ need no words.
      for (final g in [2, 7, 8, 9, 11]) {
        await appState.setShuffleGame(g, false);
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('no_shuffle_game')), findsOneWidget);
      expect(find.text('No 🔀 Shuffle games to play!'), findsOneWidget);
      // Switching a number game back on from there gets Shuffle going again.
      await tester.tap(find.byKey(const ValueKey('open_shuffle_games')));
      await tester.pumpAndSettle();
      final sw7 = find.byKey(const ValueKey('shuffle_switch_7'));
      await tester.scrollUntilVisible(sw7, 200);
      await tester.ensureVisible(sw7);
      await tester.pumpAndSettle();
      await tester.tap(sw7);
      await tester.pumpAndSettle();
      expect(appState.shuffleIncludes(7), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(stateOf(tester).currentGame, 7);
      expect(stateOf(tester).currentRound, isNotNull);
      expect(tester.takeException(), isNull);
      await tearDown(tester);
    });
  });
}
