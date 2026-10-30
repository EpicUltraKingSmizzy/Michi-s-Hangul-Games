import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _hangulOnly = RegExp(r'^[가-힣]+$');

void main() {
  group('9️⃣ colours', () {
    test('12 colours with the agreed Korean names', () {
      expect(gameColors.length, 12);
      expect(gameColors.map((c) => c.korean).toList(), [
        '빨간색',
        '주황색',
        '노란색',
        '초록색',
        '청록색',
        '파란색',
        '보라색',
        '분홍색',
        '갈색',
        '흰색',
        '회색',
        '검은색',
      ]);
      expect(gameColors.where((c) => c.short != null).map((c) => c.short).toList(), [
        '빨강',
        '주황',
        '노랑',
        '초록',
        '청록',
        '파랑',
        '보라',
        '분홍',
        '하양',
        '검정',
      ]);
      expect(gameColors.firstWhere((c) => c.id == 'brown').short, isNull);
      expect(gameColors.firstWhere((c) => c.id == 'gray').short, isNull);
      expect(gameColors.map((c) => c.argb).toSet().length, 12, reason: 'distinct colours');
      expect(gameColors.firstWhere((c) => c.id == 'white').isLight, isTrue);
      expect(gameColors.firstWhere((c) => c.id == 'black').isLight, isFalse);
    });

    test('rounds: target + 2 distinct decoys, one wording style, both modes', () {
      final engine = GameEngine([], random: Random(3));
      expect(engine.canPlay(9), isTrue, reason: 'no words needed');
      final modes = <bool>{}, styles = <bool>{}, targets = <String>{};
      var lastModes = <bool>[];
      for (var i = 0; i < 600; i++) {
        final r = engine.newRound(9) as ColorRound;
        expect(r.options.length, 3);
        expect(r.options.map((c) => c.id).toSet().length, 3);
        expect(r.options.where((c) => c.id == r.target.id).length, 1);
        for (final c in r.options) {
          final name = r.nameOf(c);
          expect(name, matches(_hangulOnly), reason: 'Korean only, no English/emoji');
          expect(name, r.shortForm ? c.short : c.korean);
          if (r.shortForm) expect(['brown', 'gray'], isNot(contains(c.id)));
        }
        modes.add(r.colorInBox);
        styles.add(r.shortForm);
        targets.add(r.target.id);
        lastModes.add(r.colorInBox);
      }
      expect(modes, {true, false});
      expect(styles, {true, false});
      expect(targets.length, 12);
      // Random, not alternating.
      var repeats = 0;
      for (var i = 1; i < lastModes.length; i++) {
        if (lastModes[i] == lastModes[i - 1]) repeats++;
      }
      expect(repeats, greaterThan(100));
    });

    test('tile name', () {
      expect(gameInfos.length, GameEngine.gameCount);
      expect(gameInfos[8].tileName, '🎨 Color match');
      expect(gameInfos[4].tileName, '🧩 Syllable scramble');
      expect(gameInfos[9].tileName, '🔗 Link Up');
      expect(gameInfos[0].tileName, '🔍 Pick the meaning');
      expect(shuffleInfo.tileName, '🔀 Shuffle');
    });
  });

  group('🔀 Shuffle picker', () {
    test('never 3️⃣ twice in a row; others may repeat', () {
      final rand = Random(1);
      int? prev;
      final seen = <int>{};
      var repeats = 0;
      for (var i = 0; i < 3000; i++) {
        final g = pickShuffleGame(rand, previous: prev, canPlay: (_) => true)!;
        if (prev == 3) expect(g, isNot(3));
        if (g == prev) repeats++;
        seen.add(g);
        prev = g;
      }
      expect(seen, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11});
      expect(repeats, greaterThan(0));
    });

    test('games switched off stay out; only playable games', () {
      final rand = Random(2);
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(pickShuffleGame(rand, enabled: (g) => g != 3, canPlay: (_) => true)!);
      }
      expect(seen, {1, 2, 4, 5, 6, 7, 8, 9, 10, 11});
      final engine = GameEngine([], random: Random(4));
      seen.clear();
      for (var i = 0; i < 500; i++) {
        seen.add(pickShuffleGame(rand, canPlay: engine.canPlay)!);
      }
      expect(seen, {2, 7, 8, 9}, reason: 'no words: only 🕒 7️⃣ 8️⃣ 9️⃣');
    });
  });

  group('options & labels', () {
    test('🔀 Shuffle games: 3️⃣ defaults on and its switch persists', () async {
      SharedPreferences.setMockInitialValues({});
      var a = AppState();
      await a.load();
      expect(a.shuffleIncludes(3), isTrue);
      await a.setShuffleGame(3, false);
      a = AppState();
      await a.load();
      expect(a.shuffleIncludes(3), isFalse);
    });

    test('pack counter: words and phrases, singular, zero counts left out', () {
      VocabEntry e(bool phrase) => VocabEntry(isFullPhrase: phrase);
      expect(
        packCountLabel([...List.filled(18, e(false)), ...List.filled(6, e(true))]),
        '18 words · 6 phrases',
      );
      expect(packCountLabel(List.filled(24, e(true))), '24 phrases');
      expect(packCountLabel([e(false), e(true)]), '1 word · 1 phrase');
      expect(packCountLabel([e(false)]), '1 word');
      expect(packCountLabel([]), '');
      expect(wordsInPlay(1), '1 word in play');
    });

    testWidgets('Word Packs: new intro text and split counters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      expect(find.textContaining('Flip packs on'), findsNothing);
      expect(find.textContaining('right now'), findsNothing);
      final n = appState.activeVocab().length;
      expect(find.text('$n words in play.'), findsOneWidget);
      // Handy Phrases: all phrases.
      final phrases = builtInBundles.first;
      final words = appState.wordsInPack(phrases.id);
      expect(find.text('${packCountLabel(words)} • ${phrases.blurb}'), findsOneWidget);
      expect(packCountLabel(words), isNot(contains('word')));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Options shows the 🔀 Shuffle games row', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('🔀 Shuffle games'), 200);
      expect(find.text('🔀 Shuffle games'), findsOneWidget);
      expect(find.text('3️⃣✍️ in 🔀 Shuffle'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('playing', () {
    Future<void> setUpApp(WidgetTester tester, {bool packsOff = false}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      await tester.runAsync(appState.load);
      if (packsOff) {
        await appState.setAllPacks(false);
        await appState.setBundleEnabled(customBundleId, false);
      }
    }

    dynamic stateOf(WidgetTester tester) => tester.state(find.byType(GameScreen));

    Future<void> tapRight(WidgetTester tester, ColorRound r) async {
      final i = r.options.indexWhere((c) => c.id == r.target.id);
      await tester.tap(find.byKey(ValueKey('color_option_$i')));
      await tester.pump();
    }

    testWidgets('9️⃣ with every pack off: wrong tap resets streak, win is counted', (tester) async {
      await setUpApp(tester, packsOff: true);
      final before = appState.sessionWins[9]!;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
      await tester.pump();
      expect(find.text('Not enough words to play!'), findsNothing);
      for (var i = 0; i < 3; i++) {
        final r = stateOf(tester).currentRound as ColorRound;
        expect(
          find.byKey(const ValueKey('color_box')),
          r.colorInBox ? findsOneWidget : findsNothing,
        );
        if (!r.colorInBox) expect(find.text(r.answer), findsOneWidget);
        await tapRight(tester, r);
        expect(stateOf(tester).streakCount, i + 1);
        await tester.pump(const Duration(milliseconds: 400));
        expect(identical(stateOf(tester).currentRound, r), isFalse);
      }
      expect(appState.sessionWins[9], before + 3);
      expect(appState.allTimeByGame[9], 3);
      final r = stateOf(tester).currentRound as ColorRound;
      final wrong = r.options.indexWhere((c) => c.id != r.target.id);
      await tester.tap(find.byKey(ValueKey('color_option_$wrong')));
      await tester.pump();
      expect(stateOf(tester).streakCount, 0);
      expect(appState.sessionWins[9], before + 3);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
      await tester.pump();
      expect(find.text('🎨'), findsWidgets);
      expect(find.text('9️⃣'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('🔀 Shuffle: streak and wins carry across games, stats per game', (tester) async {
      await setUpApp(tester, packsOff: true); // only word-free games and 🧱 playable
      final before9 = appState.sessionWins[9]!;
      final beforeShuffle = appState.shuffleSessionWins;
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      final played = <int>[];
      var wins = 0;
      for (var i = 0; i < 40 && wins < 6; i++) {
        final game = stateOf(tester).currentGame as int;
        expect([2, 7, 8, 9, 11], contains(game));
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('shuffle_game_name'))).data,
          gameInfos[game - 1].tileName,
        );
        if (game == 9) {
          await tapRight(tester, stateOf(tester).currentRound as ColorRound);
          wins++;
          played.add(game);
          expect(stateOf(tester).streakCount, wins, reason: 'streak carries over');
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          // Skipping breaks the streak, so only do it before the first win.
          if (wins > 0) break;
          await tester.tap(find.text('➡️'));
          await tester.pump();
        }
      }
      expect(wins, greaterThan(0));
      expect(appState.shuffleSessionWins, beforeShuffle + wins);
      expect(appState.sessionWins[9], before9 + wins, reason: 'filed under the game played');
      expect(find.text('🏆 ${beforeShuffle + wins}'), findsOneWidget);
      await tester.tap(find.text('➡️'));
      await tester.pump();
      expect(stateOf(tester).streakCount, 0, reason: '➡️ resets the streak');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('🔀 Shuffle with all words: 3️⃣ switched off stays out', (tester) async {
      await setUpApp(tester);
      await tester.runAsync(() => appState.setShuffleGame(3, false));
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      final seen = <int>{};
      for (var i = 0; i < 120; i++) {
        seen.add(stateOf(tester).currentGame as int);
        await tester.tap(find.text('➡️'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(seen, isNot(contains(3)));
      expect(seen.length, greaterThanOrEqualTo(6));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
    testWidgets('9️⃣ tile uses the rainbow gradient, others stay solid', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      expect(gameInfos[8].gradient, rainbowGradient);
      expect(gameInfos.where((g) => g.gradient != null).length, 1);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      final tile9 = tester.widget<BouncyButton>(find.byKey(const ValueKey('tile_9')));
      expect(tile9.gradient, rainbowGradient);
      final tile2 = tester.widget<BouncyButton>(find.byKey(const ValueKey('tile_2')));
      expect(tile2.gradient, isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('tile_9'))),
        tester.getSize(find.byKey(const ValueKey('tile_8'))),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
