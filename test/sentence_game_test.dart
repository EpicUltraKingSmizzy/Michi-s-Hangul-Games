import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vocab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = diskVocab();
  final bank = diskSentences();
  final verbWords = {
    for (final e in all)
      if (isVerbPackId(e.packId)) e.sectionName: e,
  };

  /// Food + Daily Grind in play.
  GameEngine engine(int level, int seed) =>
      GameEngine([
          for (final e in all)
            if (e.packId == 'food' || e.packId == 'daily-grind') e,
        ], random: Random(seed))
        ..sentenceBank = bank
        ..verbWords = verbWords
        ..sentenceLevel = level;

  group('engine', () {
    test('🏗️ tile, name and colour', () {
      final info = gameInfos[GameEngine.sentenceGame - 1];
      expect(GameEngine.gameCount, 11);
      expect(info.tileName, '🏗️ Sentence Builder');
      final others = [...gameInfos.where((g) => g != info).map((g) => g.color), shuffleInfo.color];
      expect(others, isNot(contains(info.color)));
      expect(all.where((e) => e.emoji == '🏗️'), isEmpty, reason: 'no word uses the game emoji');
    });

    test('rounds: verb pre-placed, answer + decoys in the tiles', () {
      for (var level = sentenceEasy; level <= sentenceMaster; level++) {
        final e = engine(level, level);
        for (var i = 0; i < 200; i++) {
          final r = e.newRound(GameEngine.sentenceGame) as SentenceRound;
          final s = r.sentence;
          expect(s.level, lessThanOrEqualTo(level));
          expect(r.word!.packId, 'daily-grind', reason: 'verbs of the packs on');
          expect(r.tiles.length, r.answer.length + s.decoys.length);
          for (final t in r.answer) {
            expect(r.tiles.where((x) => x == t).length, greaterThanOrEqualTo(1));
          }
          expect(s.korean.endsWith(s.verbChip), isTrue);
          expect(s.accepts(r.answer), isTrue);
        }
      }
    });

    test('no Verb Pack on: 🏗️ uses every verb; the other games get none', () {
      final e =
          GameEngine([
              for (final x in all)
                if (x.packId == 'food') x,
            ], random: Random(1))
            ..sentenceBank = bank
            ..verbWords = verbWords;
      expect(e.canPlay(GameEngine.sentenceGame), isTrue);
      final packs = {
        for (var i = 0; i < 400; i++)
          (e.newRound(GameEngine.sentenceGame) as SentenceRound).word!.packId,
      };
      expect(packs, hasLength(5));
      expect(e.playList.where((x) => isVerbPackId(x.packId)), isEmpty);
      expect(GameEngine([]).canPlay(GameEngine.sentenceGame), isFalse, reason: 'no data');
    });

    test('every verb can make a sentence for 🧩/🌀 and for a 🔗 card', () {
      final e = GameEngine([], random: Random(4))
        ..sentenceBank = bank
        ..verbWords = verbWords
        ..sentenceLevel = sentenceMaster;
      final cant = <String>[];
      for (final w in verbWords.values) {
        final v = e.verbOf(w)!;
        if (e.makeSentence(v, fits: GameEngine.linkSentence) == null) cant.add(v.dict);
      }
      expect(cant, isEmpty);
      for (final w in verbWords.values) {
        final v = e.verbOf(w)!;
        expect(e.makeSentence(v, fits: GameEngine.shortSentence), isNotNull, reason: v.dict);
        expect(e.makeSentence(v, fits: GameEngine.linkSentence), isNotNull, reason: v.dict);
      }
    });

    test('verbs in the other games are sentences; their decoys are sentences', () {
      bool isSentence(String ko) => ko.contains(' ') && ko.endsWith('요');
      for (var level = sentenceEasy; level <= sentenceMaster; level++) {
        final e = engine(level, 10 + level);
        var seen = 0;
        for (var i = 0; i < 400; i++) {
          final c = e.newRound(1) as ChoiceRound;
          final w = c.word!;
          if (!isVerbPackId(w.packId)) {
            final ko = c.optionsAreKorean ? c.options : [c.prompt];
            expect(ko.where((o) => o.endsWith('다') && isSentence(o)), isEmpty);
            continue;
          }
          seen++;
          final korean = c.optionsAreKorean ? c.options : [c.prompt];
          for (final k in korean) {
            expect(isSentence(k), isTrue, reason: k);
          }
          if (!c.optionsAreKorean) {
            for (final o in c.options) {
              expect(o.split(' ').length, greaterThan(1), reason: 'English sentence: $o');
            }
          }
        }
        expect(seen, greaterThan(20));

        for (final g in [3, 4, 5, 6]) {
          var verbs = 0;
          for (var i = 0; i < 300; i++) {
            final t = e.newRound(g) as TypingRound;
            if (!isVerbPackId(t.word!.packId)) continue;
            verbs++;
            expect(isSentence(t.word!.korean1), isTrue, reason: t.word!.korean1);
            expect(t.word!.english1.split(' ').length, greaterThan(1));
            if (g >= 5) {
              expect(
                stripSpaces(t.answer1).length,
                lessThanOrEqualTo(GameEngine.maxSentenceSyllables),
                reason: t.answer1,
              );
            }
          }
          expect(verbs, greaterThan(10), reason: 'game $g');
        }
      }
    });

    test('✍️/🧠/🧩 accept the parts of a sentence in any order', () {
      final e = engine(sentenceMaster, 3);
      for (var i = 0; i < 300; i++) {
        final t = e.newRound(4) as TypingRound;
        if (!isVerbPackId(t.word!.packId)) continue;
        final words = t.answer1.split(' ');
        if (words.length < 3) continue;
        for (final ok in t.alsoAccepted) {
          expect(ok.split(' ').last, words.last, reason: 'verb last');
        }
      }
    });

    test('🔗 Link Up: verbs join full-phrase boards as short sentences', () {
      final e =
          GameEngine([
              for (final x in all)
                if (x.packId == 'daily-grind') x,
            ], random: Random(7))
            ..sentenceBank = bank
            ..verbWords = verbWords
            ..sentenceLevel = sentenceMaster;
      expect(e.canPlay(GameEngine.linkUpGame), isTrue);
      for (var i = 0; i < 100; i++) {
        final r = e.newRound(GameEngine.linkUpGame) as LinkRound;
        for (final p in r.pairs) {
          expect(p.korean.contains(' '), isTrue, reason: p.korean);
          expect(stripSpaces(p.korean).length, lessThanOrEqualTo(10));
          expect(p.english.length, lessThanOrEqualTo(GameEngine.maxLinkSentenceEnglish));
          expect(p.word.packId, 'daily-grind');
        }
      }
    });

    test('difficulty: default Easy, saved, Master sets the flag', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      expect([a.sentenceLevel, a.engine.sentenceLevel, a.sentenceMasterReached], [0, 0, false]);
      await a.setSentenceLevel(sentenceMaster);
      await a.setSentenceLevel(sentenceMedium);
      final b = AppState();
      await b.load();
      expect([b.sentenceLevel, b.engine.sentenceLevel, b.sentenceMasterReached], [1, 1, true]);
      expect(b.engine.verbWords, hasLength(121));
      expect(sentenceLevelLabels, ['Easy', 'Medium', 'Hard', 'Master']);
    });
  });

  group('screens', () {
    Future<void> setUp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
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
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    dynamic state(WidgetTester t) => t.state(find.byType(GameScreen));

    Future<void> place(WidgetTester tester, List<String> order) async {
      final r = state(tester).currentRound as SentenceRound;
      final used = <int>{};
      for (final t in order) {
        final i = [for (var j = 0; j < r.tiles.length; j++) j]
            .firstWhere((j) => r.tiles[j] == t && !used.contains(j));
        used.add(i);
        await tester.tap(find.byKey(ValueKey('tile_$i')));
        await tester.pump();
      }
    }

    Future<void> winRound(WidgetTester tester) async {
      final r = state(tester).currentRound as SentenceRound;
      await place(tester, r.answer);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('home: 🧩 tile pops 🧩 and 🌀 bubbles; outside closes them', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.byKey(const ValueKey('bubble_5')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tile_5')));
      await settle(tester);
      expect(find.text('🧩 Syllable scramble'), findsOneWidget);
      expect(find.text('🌀 Scramble + decoys'), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.byKey(const ValueKey('bubble_5')), findsNothing);
      expect(find.byType(GameScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tile_5')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('bubble_6')));
      await settle(tester);
      expect(state(tester).currentGame, 6);
      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const ValueKey('bubble_6')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tile_11')));
      await settle(tester);
      expect(state(tester).currentGame, GameEngine.sentenceGame);
      expect(state(tester).currentRound, isA<SentenceRound>());
      await done(tester);
    });

    testWidgets('🏗️ play: any unit order wins; wrong tiles shake; hint and 🔊', (tester) async {
      await setUp(tester, prefs: {AppState.kSentenceLevel: sentenceMaster});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      var r = state(tester).currentRound as SentenceRound;
      expect(find.text(r.sentence.english), findsOneWidget);
      expect(find.byKey(const ValueKey('verb_chip')), findsOneWidget);
      // One line of slots.
      final slots = [
        for (var i = 0; i < r.answer.length; i++) tester.getRect(find.byKey(ValueKey('slot_$i'))),
      ];
      for (final s in slots) {
        expect(s.center.dy, closeTo(slots.first.center.dy, 0.5));
      }

      // Hint: faded answer, then 🔊 reads the whole sentence.
      expect(find.byKey(const ValueKey('hint_speak')), findsNothing);
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.byKey(const ValueKey('ghost_0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hint_speak')));
      await tester.pump();
      expect(Speaker.debugSpoken, contains(r.sentence.korean));

      // A wrong particle: no win.
      final decoy = r.tiles.firstWhere((t) => !r.answer.contains(t));
      await place(tester, [decoy]);
      expect(state(tester).tileSlots.charAt(0), decoy);
      await tester.tap(find.byKey(const ValueKey('tile_backspace')));
      await tester.pump();

      // Units in another order still win.
      final units = r.sentence.units.reversed.expand((u) => u).toList();
      await place(tester, [...units, if (r.sentence.negated) '안']);
      expect(state(tester).streakCount, 1);
      await tester.pump(const Duration(seconds: 5));
      r = state(tester).currentRound as SentenceRound;
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    testWidgets('🏗️ 5 in a row: difficulty pop-up once per launch, direct play only', (
      tester,
    ) async {
      final prompt = find.byKey(const ValueKey('sentence_prompt'));
      await setUp(tester);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        expect(prompt, findsNothing);
        await winRound(tester);
      }
      expect(prompt, findsOneWidget);
      expect(find.text('🔥 5 in a row! Ready for longer sentences?'), findsOneWidget);
      expect(find.text('Raise the difficulty to build longer sentences!'), findsOneWidget);
      expect(find.byKey(const ValueKey('opt_sentence_level')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sentence_prompt_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 5; i++) {
        await winRound(tester);
        expect(prompt, findsNothing, reason: 'once per launch');
      }
      await done(tester);

      // Next launch: back; never again once Master was chosen.
      await setUp(tester, prefs: {AppState.kSentenceMasterReached: true});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await winRound(tester);
      }
      expect(prompt, findsNothing);
      await done(tester);

      // 🔀 Shuffle never shows it.
      await setUp(tester);
      for (var g = 1; g <= GameEngine.gameCount; g++) {
        if (g != 11) await appState.setShuffleGame(g, false);
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await winRound(tester);
      }
      expect(prompt, findsNothing);
      await done(tester);
    });

    testWidgets('Options: 🏗️ Sentence difficulty slider', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      final card = find.byKey(const ValueKey('opt_sentence_level'));
      await tester.scrollUntilVisible(card, 200);
      expect(find.text('🤖 Sentence difficulty'), findsOneWidget);
      expect(
        find.text(
          'How long the sentences are in 🏗️ Sentence Builder, and in other games when Verb Packs are on.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(find.byKey(const ValueKey('opt_sentence_level_value'))).data, 'E');
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Master'), findsOneWidget);
      await done(tester);
    });
  });
}
