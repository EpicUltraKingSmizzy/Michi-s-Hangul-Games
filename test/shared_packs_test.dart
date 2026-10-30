import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vocab.dart';

/// The top-500 noun packs (v9): shared words, homographs, emojis, defaults.
final _all = diskVocab();

const _newPacks = [
  'whos-who',
  'tick-tock',
  'here-there-everywhere',
  'heart-and-body',
  'stuff-and-nature',
  'showtime',
  'school-and-hustle',
  'big-words',
  'big-brain-ideas',
  'how-things-are',
];

const _verbPacks = ['daily-grind', 'on-the-move', 'talk-and-think', 'give-and-take', 'life-happens'];

VocabEntry _w(String korean, String english) =>
    _all.singleWhere((e) => e.korean1 == korean && e.english1 == english);

/// The pre-v9 saved state of a player: old packs, with Colours switched off.
const _oldIds = [
  'phrases',
  'food',
  'home',
  'outside',
  'time',
  'people',
  'animals',
  'body',
  'emotions',
  'verbs',
  'numbers',
  'native',
  'colours',
  'grabbag',
  'custom',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data', () {
    test('10 new packs after the old ones, in theme order, with Big Words', () {
      final ids = builtInBundles.map((b) => b.id).toList();
      expect(ids.sublist(ids.length - 15, ids.length - 5), _newPacks); // then the 5 Verb Packs
      expect(ids.indexOf('whos-who'), ids.indexOf('grabbag') + 1);
      expect(defaultOffBundles, {'phrases', 'everyday-talk', ..._newPacks, ..._verbPacks});
      final big = builtInBundleById('big-words')!;
      expect((big.emoji, big.name), ('🏛️', 'Big Words'));
      expect(builtInBundles.where((b) => b.name.contains('Grown-Up')), isEmpty);
    });

    test('412 words in the new packs; shared words stay one entry with extra packs', () {
      // 412 top-500 nouns; v11 moved 12 People words to Who's Who and 10 to Family.
      expect(_all.where((e) => _newPacks.contains(e.packId)), hasLength(412)); // v16: +Gift, +Story;
      final shared = _all.where((e) => e.alsoPacks.isNotEmpty).toList();
      expect(
        shared,
        hasLength(60),
      ); // v11: Family / Who's Who no longer share 14 words; v12: −11 body parts
      // Only 시민 Citizen (Who's Who, also Big Words) has a new-pack home.
      expect(shared.where((e) => _newPacks.contains(e.packId)).map((e) => e.korean1), ['시민']);
      // Kept their English and emoji.
      final person = _w('사람', 'Person');
      expect((person.packId, person.emoji), ('whos-who', '🧑'));
      expect(person.alsoPacks, isEmpty);
      expect(_w('형', 'Older Brother').korean2, '오빠');
      // Each pack's members (home + shared), as on the Word Packs screen.
      final members = {for (final p in _newPacks) p: _all.where((e) => e.inPack(p)).length};
      expect(members, {
        'whos-who': 32,
        'tick-tock': 50,
        'here-there-everywhere': 40,
        'heart-and-body': 32,
        'stuff-and-nature': 48,
        'showtime': 41,
        'school-and-hustle': 40,
        'big-words': 70,
        'big-brain-ideas': 60,
        'how-things-are': 59,
      });
      // Every Korean spelling of a new word is new, except the 5 homographs (공 Ball meets 공 zero since v14).
      final oldKorean = {
        for (final e in _all.where((e) => !_newPacks.contains(e.packId))) ...[e.korean1, e.korean2],
      }..remove('');
      expect(
        _all
            .where((e) => _newPacks.contains(e.packId) && oldKorean.contains(e.korean1))
            .map((e) => '${e.korean1} ${e.english1}'),
        unorderedEquals(['차 Car (vehicle)', '일 Work (task)', '신 God', '거리 Distance', '공 Ball']),
      );
    });

    test('no new word reuses an emoji (exact or without U+FE0F)', () {
      String norm(String s) => s.replaceAll('\uFE0F', '');
      final newOnes = _all.where((e) => _newPacks.contains(e.packId) && e.emoji.isNotEmpty);
      expect(newOnes, hasLength(36)); // 36 noun emojis; v11 +7 / −5 by pack moves; − Name emoji; − Construction emoji
      final counts = <String, int>{};
      for (final e in _all.where((e) => e.emoji.isNotEmpty)) {
        counts.update(norm(e.emoji), (v) => v + 1, ifAbsent: () => 1);
      }
      for (final e in newOnes) {
        expect(counts[norm(e.emoji)], 1, reason: '${e.korean1} ${e.emoji}');
      }
      // App-wide, no emoji is shared (💪 is Arm's only, since t44u).
      expect(counts.entries.where((c) => c.value > 1).map((c) => c.key), isEmpty);
      expect(_w('차', 'Car (vehicle)').emoji, '', reason: '🚗 is 자동차');
    });

    test('the curated English is kept as is (no added notes)', () {
      expect(_w('일', 'Work (task)').english2, '');
      expect(_w('신', 'God').english1, 'God');
      expect(_w('거리', 'Distance').english1, 'Distance');
    });
  });

  group('packs on and off', () {
    test('fresh install: the new packs start off', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.enabledBundles.intersection(_newPacks.toSet()), isEmpty);
      expect(s.enabledBundles.containsAll(['food', 'people', 'custom']), isTrue);
      expect(s.activeVocab().where((e) => _newPacks.contains(e.packId)), isEmpty);
    });

    test('update: new packs off, the old saved switches untouched', () async {
      SharedPreferences.setMockInitialValues({
        'enabled_bundles': [..._oldIds]..remove('colours'),
        'known_bundles': _oldIds.where((id) => id != 'custom').toList()..add('custom'),
      });
      final s = AppState();
      await s.load();
      // 'verbs' (🏃 Action Heroes, removed) is dropped from old saves.
      expect(s.enabledBundles, {..._oldIds}..removeAll(['colours', 'verbs']));
      // And they stay off after a restart.
      final again = AppState();
      await again.load();
      expect(again.enabledBundles.intersection(_newPacks.toSet()), isEmpty);
    });

    test('a shared word is in play once, when any of its packs is on', () async {
      SharedPreferences.setMockInitialValues({
        'enabled_bundles': ['whos-who'],
        'known_bundles': [...builtInBundles.map((b) => b.id), 'custom'],
      });
      final s = AppState();
      await s.load();
      final ids = s.activeVocab().map((e) => e.sectionName).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, hasLength(32));
      expect(ids, contains(_w('시민', 'Citizen').sectionName)); // also in Big Words (off)
      await s.setBundleEnabled('big-words', true);
      final both = s.activeVocab().map((e) => e.sectionName).toList();
      final big = s.wordsInPack('big-words').length;
      final shared = s.wordsInPack('whos-who').where((e) => e.inPack('big-words')).length;
      expect(shared, 1);
      expect(both, hasLength(32 + big - shared), reason: 'counted once');
      expect(both.toSet().length, both.length);
      // The pack lists the shared words too.
      expect(s.wordsInPack('big-words'), hasLength(70));
      await s.setBundleEnabled('whos-who', false);
      expect(s.activeVocab().map((e) => e.sectionName), contains(_w('시민', 'Citizen').sectionName));
      expect(
        s.activeVocab().map((e) => e.sectionName),
        isNot(contains(_w('사람', 'Person').sectionName)),
      );
    });

    test('editing a shared word keeps it in both packs; old edits pick it up', () async {
      final person = _w('시민', 'Citizen');
      SharedPreferences.setMockInitialValues({
        // An edit saved before shared packs existed (no alsoPacks key).
        AppState.kOverrides: jsonEncode({
          person.sectionName: person.copyWith(english1: 'Townsperson', alsoPacks: const []).toJson()
            ..remove('alsoPacks'),
        }),
        'enabled_bundles': ['whos-who'],
        'known_bundles': [...builtInBundles.map((b) => b.id), 'custom'],
      });
      final s = AppState();
      await s.load();
      final edited = s.activeVocab().singleWhere((e) => e.sectionName == person.sectionName);
      expect(edited.english1, 'Townsperson');
      expect(edited.alsoPacks, ['big-words']);
      await s.saveWord(
        edited.copyWith(english1: 'Citizen', alsoPacks: const []),
        packChoice: s.resolvePack("Who's Who"),
      );
      expect(s.isOverridden(person), isFalse, reason: 'back to the original');
      expect(s.wordsInPack('big-words').map((e) => e.sectionName), contains(person.sectionName));
    });
  });

  group('homographs', () {
    final tea = _w('차', 'Tea');
    final car = _w('차', 'Car (vehicle)');
    final one = _all.firstWhere((e) => e.korean1 == '일' && e.english1 == '1');
    final work = _w('일', 'Work (task)');
    final road = _all.firstWhere((e) => e.english1 == 'Road');
    final distance = _w('거리', 'Distance');
    final parents = _w('부모', 'Parents');
    final parents2 = _all.singleWhere((e) => e.korean1 == '부모님');
    final fillers = _all.where((e) => e.packId == 'animals').take(4);
    final words = [tea, car, one, work, road, distance, parents, parents2, ...fillers];

    for (final emoji in [true, false]) {
      test('1️⃣ never puts two meanings of one Korean in a round (emoji $emoji)', () {
        final eng = GameEngine(words, random: Random(7))..useEmoji = emoji;
        String shown(VocabEntry e) => emoji && e.emoji.isNotEmpty ? e.emoji : e.english1;
        for (var i = 0; i < 400; i++) {
          final r = legacyRound(eng, 1) as ChoiceRound;
          // A shown text can belong to two cards (부모 / 부모님 "Parents" with
          // emojis off); prefer the one the prompt is about.
          VocabEntry card(String o) {
            final m = words.where((e) => shown(e) == o);
            return m.firstWhere((e) => e.korean1 == r.prompt, orElse: () => m.first);
          }

          final cards = [for (final o in r.options) card(o)];
          final korean = cards.expand((e) => [e.korean1, e.korean2]).where((k) => k.isNotEmpty);
          expect(korean.toSet().length, korean.length, reason: '${r.prompt} ${r.options}');
          expect(r.options.toSet().length, r.options.length);
          // Only the right card carries the prompt's Korean.
          expect(
            cards.where((e) => e.korean1 == r.prompt || e.korean2 == r.prompt),
            hasLength(1),
            reason: '${r.prompt} ${r.options}',
          );
          final english = cards.map((e) => e.english1.toLowerCase());
          expect(english.toSet().length, english.length, reason: 'Parents twice: ${r.options}');
        }
      });

      test('2️⃣ never shows the same Korean twice (emoji $emoji)', () {
        final eng = GameEngine(words, random: Random(8))..useEmoji = emoji;
        for (var i = 0; i < 400; i++) {
          final r = legacyRound(eng, 2) as ChoiceRound;
          expect(r.options.toSet().length, r.options.length, reason: '${r.prompt} ${r.options}');
          expect(r.options, contains(r.correctAnswer));
        }
      });
    }

    test('3️⃣–6️⃣ typing: the homograph Korean is simply the answer', () {
      final eng = GameEngine([car, work, distance, parents, ...fillers], random: Random(9));
      for (final target in [car, work, distance]) {
        final r = eng.createTextBoxGame(target);
        expect(r.prompt, target.english1, reason: 'no emoji: English prompt');
        expect(isTypedAnswerCorrect(target.korean1, r), isTrue);
      }
      final both = GameEngine([parents, parents2, ...fillers], random: Random(9));
      final r = both.createTextBoxGame(parents);
      expect(r.prompt, 'Parents');
      expect(isTypedAnswerCorrect('부모', r), isTrue);
      expect(isTypedAnswerCorrect('부모님', r), isTrue, reason: 'also means "Parents"');
    });

    test('every game still works with all the packs on', () {
      final eng = GameEngine(_all, random: Random(10));
      for (final emoji in [true, false]) {
        eng.useEmoji = emoji;
        for (var game = 1; game <= 9; game++) {
          for (var i = 0; i < 60; i++) {
            expect(legacyRound(eng, game), isNotNull);
          }
        }
      }
    });
  });

  group('no-emoji cards', () {
    Future<void> setUp(WidgetTester tester, List<VocabEntry> words) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      await tester.runAsync(appState.load);
      appState.engine = GameEngine(words, random: Random(4))..useEmoji = true;
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }

    final plain = [_w('정부', 'Government'), _w('사회', 'Society'), _w('경제', 'Economy')];

    testWidgets('1️⃣ shows their English on the buttons, emojis on', (tester) async {
      expect(plain.every((e) => e.emoji.isEmpty), isTrue);
      await setUp(tester, plain);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      final r = tester.state<State>(find.byType(GameScreen));
      final round = (r as dynamic).currentRound as ChoiceRound;
      expect(round.options.toSet(), {'Government', 'Society', 'Economy'});
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('option_text_$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    testWidgets('2️⃣–6️⃣ show their English prompt, no peek', (tester) async {
      await setUp(tester, plain);
      for (final game in [2, 3, 4, 5, 6]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: _legacy(game)),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('prompt_text')), findsOneWidget, reason: 'game $game');
        expect(find.byKey(const ValueKey('prompt_peek')), findsNothing);
        final round = (tester.state<State>(find.byType(GameScreen)) as dynamic).currentRound;
        final prompt = round is ChoiceRound ? round.prompt : (round as TypingRound).prompt;
        expect(['Government', 'Society', 'Economy'], contains(prompt));
        expect(tester.takeException(), isNull);
      }
      await done(tester);
    });

    testWidgets('Word Packs lists the new packs, off, with their counts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      final card = find.byKey(const ValueKey('pack_whos-who'));
      await tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('32 words • Jobs, friends, strangers'), findsOneWidget);
      final sw = tester.widget<Switch>(find.descendant(of: card, matching: find.byType(Switch)));
      expect(sw.value, isFalse);
    });
  });
}

/// Old 2️⃣ 🎯 Pick the Korean is 1️⃣ in its Korean-answer format now.
int _legacy(int game) {
  GameEngine.pickKoreanFormat = game == 2 ? true : null;
  addTearDown(() => GameEngine.pickKoreanFormat = null);
  return game == 2 ? 1 : game;
}
