import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/logic/sentences.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
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
  String verbPack() => appState.verbPackIds.first;
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

    test('verb pieces: stem + tense, then the polite ending', () {
      expect(splitVerbForm('먹었어요'), ['먹었', '어요']);
      expect(splitVerbForm('먹어요'), ['먹', '어요']);
      expect(splitVerbForm('앉아요'), ['앉', '아요']);
      expect(splitVerbForm('먹을 거예요'), ['먹을 거', '예요']);
      expect(splitVerbForm('가요'), ['가', '요']);
      expect(splitVerbForm('마셔요'), ['마셔', '요']);
      expect(splitVerbForm('공부해요'), ['공부해', '요']);
      expect(splitVerbForm('공부했어요'), ['공부했', '어요']);
      expect(splitVerbForm('공부할 거예요'), ['공부할 거', '예요']);
      for (final v in bank.verbs) {
        for (final t in Tense.values) {
          final f = v.conj.form(t);
          final p = splitVerbForm(f);
          expect(p.join(), f, reason: f);
          expect(p.every((x) => x.isNotEmpty), isTrue, reason: f);
        }
      }
    });

    test('Easy/Medium keep the verb pre-placed; Hard/Master place its pieces last', () {
      for (var level = sentenceEasy; level <= sentenceMaster; level++) {
        final e = engine(level, 100 + level);
        for (var i = 0; i < 150; i++) {
          final s = (e.newRound(GameEngine.sentenceGame) as SentenceRound).sentence;
          final placed = s.level >= sentenceHard;
          expect(s.verbPlaced, placed);
          final a = s.answerTiles;
          if (placed) {
            expect(a.sublist(a.length - 2), splitVerbForm(s.verbChip), reason: s.korean);
            expect(s.accepts(a.sublist(0, a.length - 2)), isFalse);
            // The two pieces swapped: wrong.
            final swapped = [...a.sublist(0, a.length - 2), a.last, a[a.length - 2]];
            expect(s.accepts(swapped), isFalse);
          } else {
            expect(a.any(s.verbChip.contains), isFalse, reason: s.korean);
          }
          // Built from the pieces, the slot line reads the sentence.
          final line = [
            for (final u in s.units) u.join(),
            if (!placed && s.fixedBeforeNegation.isNotEmpty) s.fixedBeforeNegation,
            ...s.tailTiles.where((t) => t == '안' || t == s.verb.splitNoun),
            if (placed) s.verbPieces.join() else s.verbChip,
          ].join(' ');
          expect(line.replaceAll(' ', ''), s.korean.replaceAll(' ', ''), reason: s.korean);
        }
      }
    });

    test('Master verb decoys: wrong tense, another verb, wrong ending; never an answer', () {
      final e = engine(sentenceMaster, 7);
      var withOther = 0, withEnding = 0;
      for (var i = 0; i < 400; i++) {
        final r = e.newRound(GameEngine.sentenceGame) as SentenceRound;
        final s = r.sentence;
        if (s.level < sentenceMaster) continue;
        final stem = s.verbPieces[0];
        final wrongStems = {
          for (final t in Tense.values)
            if (t != s.tense)
              splitVerbForm(
                s.verbChip == s.verb.conj.form(s.tense)
                    ? s.verb.conj.form(t)
                    : s.verb.conj.form(t).substring(s.verb.splitNoun.length),
              )[0],
        };
        expect(
          s.decoys.where(wrongStems.contains),
          hasLength(1),
          reason: '${s.korean} ${s.decoys}',
        );
        final otherStems = {
          for (final v in bank.verbs)
            if (v.dict != s.verb.dict) splitVerbForm(v.conj.form(s.tense))[0],
        };
        if (s.decoys.any((d) => otherStems.contains(d) && !wrongStems.contains(d))) withOther++;
        final ending = verbEndingDecoys[s.verbPieces[1]];
        if (ending != null) {
          expect(s.decoys, contains(ending));
          withEnding++;
        }
        expect(s.decoys, isNot(contains(stem)));
        // No decoy is an answer piece, so no accepted order can use one.
        expect(s.decoys.toSet().intersection(s.answerTiles.toSet()), isEmpty);
        for (final o in s.acceptedTileOrders) {
          expect(o.any(s.decoys.contains), isFalse);
        }
        // Swapping any decoy into the answer is never accepted.
        for (final d in s.decoys) {
          for (var j = 0; j < s.answerTiles.length; j++) {
            final x = [...s.answerTiles]..[j] = d;
            expect(s.accepts(x), isFalse, reason: '$x');
          }
        }
        expect(r.tiles.length, s.answerTiles.length + s.decoys.length);
      }
      expect(withOther, greaterThan(50));
      expect(withEnding, greaterThan(50));
    });

    test('Hard has no verb decoys', () {
      final e = engine(sentenceHard, 3);
      for (var i = 0; i < 200; i++) {
        final s = (e.newRound(GameEngine.sentenceGame) as SentenceRound).sentence;
        final stems = {
          for (final v in bank.verbs)
            for (final t in Tense.values) splitVerbForm(v.conj.form(t))[0],
        };
        // Particle decoys such as 가 can look like a stem (가다 → 가 + 요).
        stems.removeAll(['가', '이', '와', '과', '에', '을', '를', '은', '는', '도']);
        expect(
          s.decoys.where((d) => stems.contains(d) || verbEndingDecoys.containsValue(d)),
          isEmpty,
          reason: '${s.decoys}',
        );
      }
    });

    test('acceptedTileOrders are exactly what accepts() takes', () {
      for (var seed = 0; seed < 40; seed++) {
        final r = engine(sentenceMaster, seed).newRound(GameEngine.sentenceGame) as SentenceRound;
        final orders = r.sentence.acceptedTileOrders;
        expect(orders.any((o) => o.join('|') == r.answer.join('|')), isTrue);
        for (final o in orders) {
          expect(r.sentence.accepts(o), isTrue);
        }
      }
    });

    test('no Verb Pack on: no 🏗️, and the other games get no verbs', () {
      final e =
          GameEngine([
              for (final x in all)
                if (x.packId == 'food') x,
            ], random: Random(1))
            ..sentenceBank = bank
            ..verbWords = verbWords;
      expect(e.canPlay(GameEngine.sentenceGame), isFalse);
      expect(e.hasSentenceVerbs, isFalse);
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
    Future<void> setUp(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      bool verbsOn = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kVibration: false,
        AppState.kSpokenAnswer: false,
        ...prefs,
      });
      await tester.runAsync(appState.load);
      if (verbsOn) await tester.runAsync(() => appState.setBundleEnabled(verbPack(), true));
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

    testWidgets('🏗️ with no Verb Pack on: warning, then Open Verb Packs', (tester) async {
      await setUp(tester, verbsOn: false);
      for (final id in appState.verbPackIds) {
        expect(appState.enabledBundles, isNot(contains(id)));
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      expect(state(tester).currentRound, isNull);
      expect(find.byKey(const ValueKey('needs_verbs')), findsOneWidget);
      expect(find.text('🏗️ Sentence Builder needs verbs'), findsOneWidget);
      expect(
        find.text('Turn on at least one Verb Pack to start building sentences.'),
        findsOneWidget,
      );
      expect(find.text('Not enough words to play!'), findsNothing);

      // Back with none on: the warning stays.
      await tester.tap(find.text('Open Verb Packs'));
      await settle(tester);
      expect(find.byType(VerbPacksScreen), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const ValueKey('needs_verbs')), findsOneWidget);

      // Back with a pack on: the game starts.
      await tester.tap(find.text('Open Verb Packs'));
      await settle(tester);
      await tester.runAsync(() => appState.setBundleEnabled(verbPack(), true));
      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const ValueKey('needs_verbs')), findsNothing);
      expect(state(tester).currentRound, isA<SentenceRound>());
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    test('🔀 Shuffle skips 🏗️ while no Verb Pack is on', () {
      final e =
          GameEngine([
              for (final x in all)
                if (x.packId == 'food') x,
            ], random: Random(3))
            ..sentenceBank = bank
            ..verbWords = verbWords;
      final rand = Random(4);
      for (var i = 0; i < 300; i++) {
        expect(pickShuffleGame(rand, canPlay: e.canPlay), isNot(GameEngine.sentenceGame));
      }
    });

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

    testWidgets('🏗️ 💡: wrong tiles go back; any accepted order stays', (tester) async {
      await setUp(tester, prefs: {AppState.kSentenceLevel: sentenceMaster});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      var r = state(tester).currentRound as SentenceRound;
      while (r.sentence.units.length < 2) {
        await tester.tap(find.text('➡️'));
        await tester.pump(const Duration(milliseconds: 500));
        r = state(tester).currentRound as SentenceRound;
      }
      final slots = state(tester).tileSlots;
      // Another accepted order, all but its last tile: nothing is cleared.
      final other = r.sentence.acceptedTileOrders.last;
      await place(tester, other.sublist(0, other.length - 1));
      await tester.tap(find.byKey(const ValueKey('hint_button')));
      await tester.pump();
      expect([
        for (var i = 0; i < other.length - 1; i++) slots.charAt(i),
      ], other.sublist(0, other.length - 1));
      await tester.tap(find.byKey(const ValueKey('hint_button')));
      await tester.pump();

      // A decoy first, then the right second tile: only the decoy goes.
      await tester.tap(find.byKey(const ValueKey('tile_backspace')));
      for (var i = 0; i < other.length; i++) {
        await tester.tap(find.byKey(const ValueKey('tile_backspace')));
      }
      await tester.pump();
      expect(slots.isEmpty, isTrue);
      final decoy = r.tiles.firstWhere((t) => !r.answer.contains(t));
      await place(tester, [decoy, r.answer[1]]);
      await tester.tap(find.byKey(const ValueKey('hint_button')));
      await tester.pump();
      expect(slots.tileAt(0), isNull);
      expect(slots.charAt(1), r.answer[1]);
      expect(find.byKey(const ValueKey('ghost_0')), findsOneWidget);
      await done(tester);
    });

    testWidgets('🏗️ play: any unit order wins; wrong tiles shake; hint and 🔊', (tester) async {
      await setUp(tester, prefs: {AppState.kSentenceLevel: sentenceMaster});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 11)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      var r = state(tester).currentRound as SentenceRound;
      expect(find.text(r.sentence.english), findsOneWidget);
      // Master: nothing pre-placed; the verb is two pieces in the pool.
      expect(find.byKey(const ValueKey('verb_chip')), findsNothing);
      expect(r.answer.sublist(r.answer.length - 2), r.sentence.verbPieces);
      // One line of slots.
      final slots = [
        for (var i = 0; i < r.answer.length; i++) tester.getRect(find.byKey(ValueKey('slot_$i'))),
      ];
      for (final s in slots) {
        expect(s.center.dy, closeTo(slots.first.center.dy, 0.5));
      }

      // Hint: faded answer, then 🔊 reads the whole sentence.
      expect(find.byKey(const ValueKey('hint_speak')), findsNothing);
      await tester.tap(find.text('💡'));
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
      await place(tester, [...units, ...r.sentence.tailTiles]);
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
      expect(find.text('Sentence difficulty'), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('🤖')), findsOneWidget);
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
