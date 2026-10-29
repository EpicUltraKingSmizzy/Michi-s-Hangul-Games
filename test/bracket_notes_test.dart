import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// t44u: 💪 off 힘 Strength, and the ⚙️ 📑 Bracket notes option.
final _all = parseIni(File('assets/korean_vocab.ini').readAsStringSync());

VocabEntry _w(String korean, String english) =>
    _all.singleWhere((e) => e.korean1 == korean && e.english1 == english);

String _key(String s) => stripSpaces(s).toLowerCase();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('💪 Strength', () {
    test('힘 Strength has no emoji; 팔 Arm keeps 💪', () {
      expect(_w('힘', 'Strength').emoji, '');
      expect(_w('팔', 'Arm').emoji, '💪');
      expect(_all.where((e) => e.emoji == '💪'), hasLength(1));
    });

    test('a saved edit carrying the old 💪 gets no emoji; other edits stay', () async {
      final strength = _w('힘', 'Strength');
      SharedPreferences.setMockInitialValues({
        AppState.kOverrides: jsonEncode({
          strength.sectionName: strength.copyWith(emoji: '💪', korean2: '기운').toJson(),
        }),
      });
      final s = AppState();
      await s.load();
      final e = s.effectiveBuiltIn.singleWhere((e) => e.sectionName == strength.sectionName);
      expect(e.emoji, '');
      expect(e.korean2, '기운', reason: 'the real edit is kept');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.kOverrides), isNot(contains('💪')));
    });

    test('an edit that only differed by the old 💪 goes away', () async {
      final strength = _w('힘', 'Strength');
      SharedPreferences.setMockInitialValues({
        AppState.kOverrides: jsonEncode({
          strength.sectionName: strength.copyWith(emoji: '💪').toJson(),
        }),
      });
      final s = AppState();
      await s.load();
      expect(s.isOverridden(strength), isFalse);
      expect(
        s.effectiveBuiltIn.singleWhere((e) => e.sectionName == strength.sectionName).emoji,
        '',
      );
    });

    test('a different emoji the player chose for Strength is kept', () async {
      final strength = _w('힘', 'Strength');
      SharedPreferences.setMockInitialValues({
        AppState.kOverrides: jsonEncode({
          strength.sectionName: strength.copyWith(emoji: '🏋️').toJson(),
        }),
      });
      final s = AppState();
      await s.load();
      expect(
        s.effectiveBuiltIn.singleWhere((e) => e.sectionName == strength.sectionName).emoji,
        '🏋️',
      );
    });
  });

  group('stripBracketNotes', () {
    test('removes notes in brackets, keeps the rest', () {
      expect(stripBracketNotes('Car (vehicle)'), 'Car');
      expect(stripBracketNotes('Work (of art)'), 'Work');
      expect(stripBracketNotes('Goodbye (they are leaving)'), 'Goodbye');
      expect(stripBracketNotes('Seat (spot)'), 'Seat');
      expect(stripBracketNotes('A (b) c (d)'), 'A c');
      expect(stripBracketNotes('Hi (there)!'), 'Hi!');
      expect(stripBracketNotes('Hello'), 'Hello');
      expect(stripBracketNotes('(only a note)'), '(only a note)', reason: 'never empty');
    });

    test('every built-in English still has words after stripping', () {
      for (final e in _all) {
        final s = stripBracketNotes(e.english1);
        expect(s.trim(), isNotEmpty);
        expect(s, isNot(contains('(')), reason: e.english1);
      }
    });

    test('stripping makes 30 new look-alike groups (64 cards)', () {
      Map<String, List<VocabEntry>> group(String Function(VocabEntry) f) {
        final m = <String, List<VocabEntry>>{};
        for (final e in _all) {
          m.putIfAbsent(_key(f(e)), () => []).add(e);
        }
        return m;
      }

      final before = group((e) => e.english1);
      final after = group((e) => stripBracketNotes(e.english1));
      final grown = after.entries
          .where((g) => g.value.length > 1 && (before[g.key]?.length ?? 0) != g.value.length)
          .toList();
      expect(grown, hasLength(30));
      expect(grown.fold<int>(0, (n, g) => n + g.value.length), 64);
      expect(after['0']!.map((e) => e.korean1).toSet(), {'영', '공'});
      expect(after['rice']!.map((e) => e.korean1).toSet(), {'밥', '쌀'});
      expect(after['car']!.map((e) => e.korean1).toSet(), {'자동차', '차'});
    });
  });

  group('engine with bracket notes off', () {
    final rice = _w('밥', 'Rice');
    final rawRice = _w('쌀', 'Rice (uncooked)');
    final car = _w('자동차', 'Car');
    final carVehicle = _w('차', 'Car (vehicle)');

    GameEngine engine(List<VocabEntry> words, int seed, {bool emoji = true, bool notes = false}) =>
        GameEngine(words, random: Random(seed))
          ..useEmoji = emoji
          ..showBracketNotes = notes;

    test('prompts, answers and peeks show the English without notes', () {
      final words = [carVehicle, _w('정부', 'Government'), _w('사회', 'Society')];
      var seen = 0;
      for (var seed = 0; seed < 200; seed++) {
        final r = engine(words, seed).newRound(1) as ChoiceRound;
        if (r.prompt == '차') {
          expect(r.correctAnswer, 'Car');
          seen++;
        }
        expect(r.options.where((o) => o.contains('(')), isEmpty);
      }
      expect(seen, greaterThan(0));
      final e = engine([rawRice, ..._all.take(20)], 1);
      final peek = (e.matchingGame(rawRice, [], true)).promptEnglish;
      expect(peek, 'Rice');
      final on = engine([rawRice, ..._all.take(20)], 1, notes: true);
      expect(on.matchingGame(rawRice, [], true).promptEnglish, 'Rice (uncooked)');
      expect(GameEngine.peekEnglish(rawRice, showBracketNotes: false), 'Rice');
    });

    test('custom words lose their notes too', () {
      const mug = VocabEntry(english1: 'Cup (mug)', korean1: '머그컵', packId: customBundleId);
      final e = engine([mug, _w('정부', 'Government'), _w('사회', 'Society')], 3, emoji: false);
      expect(e.matchingGame(mug, [], true).prompt, 'Cup');
      expect(e.createTextBoxGame(mug).prompt, 'Cup');
    });

    test('1️⃣/2️⃣ never show two cards with the same English (all words, emojis off)', () {
      final e = engine(_all, 7, emoji: false);
      for (var i = 0; i < 3000; i++) {
        final game = 1 + i % 2;
        final r = legacyRound(e, game) as ChoiceRound;
        final shown = game == 1 ? r.options : [r.prompt];
        if (game == 1) {
          expect(shown.map(_key).toSet(), hasLength(shown.length), reason: '$shown');
        } else {
          // The Korean buttons: only one card behind the English prompt.
          final behind = _all.where((x) => _key(stripBracketNotes(x.english1)) == _key(r.prompt));
          final right = r.options
              .where(
                (o) => behind.any((x) => _key(x.korean1) == _key(o) || _key(x.korean2) == _key(o)),
              )
              .toList();
          expect(right, hasLength(1), reason: '${r.prompt}: ${r.options}');
        }
      }
    });

    test('Rice next to Rice / Car next to Car never share a round', () {
      final words = [rice, rawRice, car, carVehicle, _w('정부', 'Government'), _w('사회', 'Society')];
      for (var seed = 0; seed < 300; seed++) {
        for (final emoji in [true, false]) {
          final e = engine(words, seed, emoji: emoji);
          for (final t in [rice, rawRice, car, carVehicle]) {
            final wrong = e.getWrongAnswers(t, words);
            final twin = t == rice || t == rawRice ? {rice, rawRice} : {car, carVehicle};
            final clashes = wrong.where(twin.contains);
            // With emojis on, 🍚 vs 🌾 look different; Car vs 🚗 does not
            // (one shows English), so only the both-emoji pair may meet.
            if (!(emoji && t.emoji.isNotEmpty && clashes.every((c) => c.emoji.isNotEmpty))) {
              expect(clashes, isEmpty, reason: '${t.english1} seed $seed emoji $emoji');
            }
          }
        }
      }
    });

    test('typing: any Korean behind the shown English is accepted', () {
      final words = [rice, rawRice, car, carVehicle, _w('정부', 'Government')];
      final off = engine(words, 2, emoji: false);
      final r = off.createTextBoxGame(rawRice);
      expect(r.prompt, 'Rice');
      expect(isTypedAnswerCorrect('밥', r), isTrue);
      expect(isTypedAnswerCorrect('쌀', r), isTrue);
      final c = off.createTextBoxGame(carVehicle);
      expect(c.prompt, 'Car');
      expect(isTypedAnswerCorrect('자동차', c), isTrue);
      // Notes on: the prompts differ again, so only the own Korean counts.
      final on = engine(words, 2, emoji: false, notes: true);
      final r2 = on.createTextBoxGame(rawRice);
      expect(r2.prompt, 'Rice (uncooked)');
      expect(isTypedAnswerCorrect('밥', r2), isFalse);
      expect(isTypedAnswerCorrect('쌀', r2), isTrue);
    });

    test('stored words never change', () {
      final e = engine([rawRice, rice, car], 1, emoji: false);
      e.newRound(1);
      expect(rawRice.english1, 'Rice (uncooked)');
      expect(e.vocabList.first.english1, 'Rice (uncooked)');
    });
  });

  group('⚙️ 📑 Bracket notes', () {
    Future<void> setUp(WidgetTester tester, Map<String, Object> prefs) async {
      // Tall enough to build every option card and the Animals pack.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      await tester.runAsync(appState.load);
    }

    testWidgets('off by default, right after 😀 Emoji, saved, switches the engine', (tester) async {
      await setUp(tester, {});
      expect(appState.showBracketNotes, isFalse);
      expect(appState.engine.showBracketNotes, isFalse);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      final card = find.byKey(const ValueKey('opt_show_bracket_notes'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('📑')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Bracket notes')), findsOneWidget);
      expect(
        find.text('Show context in brackets like Orange (color) and Orange (fruit).'),
        findsOneWidget,
      );
      final emojiTop = tester.getTopLeft(find.byKey(const ValueKey('opt_use_emoji'))).dy;
      final top = tester.getTopLeft(card).dy;
      final shuffleTop = tester.getTopLeft(find.byKey(const ValueKey('opt_shuffle_games'))).dy;
      expect(top, greaterThan(emojiTop));
      expect(top, lessThan(shuffleTop));
      await tester.tap(find.descendant(of: card, matching: find.byType(Switch)));
      await tester.pump();
      expect(appState.showBracketNotes, isTrue);
      expect(appState.engine.showBracketNotes, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kShowBracketNotes), isTrue);
      await tester.runAsync(appState.load);
      expect(appState.showBracketNotes, isTrue, reason: 'saved');
      expect(appState.engine.showBracketNotes, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved choice is kept; an untouched existing install gets the new default', (
      tester,
    ) async {
      await setUp(tester, {
        AppState.kShowBracketNotes: true,
        'known_bundles': <String>['food'],
      });
      expect(appState.showBracketNotes, isTrue);
      expect(appState.engine.showBracketNotes, isTrue);
      await setUp(tester, {
        AppState.kShowBracketNotes: false,
        'known_bundles': <String>['food'],
      });
      expect(appState.showBracketNotes, isFalse);
      // Never touched: nothing saved for the option, so it starts off.
      await setUp(tester, {
        AppState.kVibration: true,
        'known_bundles': <String>['food'],
      });
      expect(appState.showBracketNotes, isFalse);
      expect(appState.engine.showBracketNotes, isFalse);
    });

    testWidgets('Word Packs chips drop the notes when off', (tester) async {
      await setUp(tester, {AppState.kShowBracketNotes: false});
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      await tester.tap(find.text('Animals'));
      await tester.pumpAndSettle();
      expect(find.text('🐁 Mouse = 생쥐'), findsOneWidget);
      expect(find.textContaining('Mouse (animal)'), findsNothing);
      await appState.setShowBracketNotes(true);
      await tester.pump();
      expect(find.text('🐁 Mouse (animal) = 생쥐'), findsOneWidget);
    });

    testWidgets('1️⃣ shows the stripped English on its buttons', (tester) async {
      await setUp(tester, {
        AppState.kShowBracketNotes: false,
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      final words = [_w('차', 'Car (vehicle)'), _w('정부', 'Government'), _w('사회', 'Society')];
      appState.engine = GameEngine(words, random: Random(1))..showBracketNotes = false;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      final round =
          (tester.state<State>(find.byType(GameScreen)) as dynamic).currentRound as ChoiceRound;
      expect(round.options.toSet(), {'Car', 'Government', 'Society'});
      expect(find.text('Car'), findsOneWidget);
      expect(find.textContaining('(vehicle)'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
