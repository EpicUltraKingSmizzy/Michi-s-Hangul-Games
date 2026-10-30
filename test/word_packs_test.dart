import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/data/packs.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/custom_words_screen.dart';
import 'package:hangul_hooray/screens/emoji_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry word(String en, String ko, {String pack = '', String section = ''}) =>
    VocabEntry(english1: en, korean1: ko, packId: pack, sectionName: section);

Future<AppState> fresh([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState();
  await s.load();
  return s;
}

Future<AppState> reload() async {
  final s = AppState();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pack resolution', () {
    const kdrama = UserPack(id: 'user_1', name: 'K-Drama', emoji: '🎬');
    PackChoice r(String s) => resolvePackInput(s, userPacks: const [kdrama]);

    test('blank and My Words go to My Words', () {
      for (final s in ['', '   ', 'My Words', '  my words ', 'MY WORDS', '✏️ My Words', '✏️']) {
        expect(r(s).kind, PackKind.myWords, reason: '"$s"');
        expect(r(s).id, customBundleId);
      }
    });

    test('built-in pack names: trimmed, any case, leading emoji ignored', () {
      for (final s in ['Food', ' food ', 'FOOD', '🍜 Food', '🍜Food', '  🍜  fOoD  ']) {
        expect((r(s).kind, r(s).id), (PackKind.builtIn, 'food'), reason: '"$s"');
      }
      expect(r('out & about').id, 'outside');
      expect(r('Body   Parts').id, 'body', reason: 'inner spaces collapsed');
    });

    test('user pack names resolve to that pack', () {
      for (final s in ['K-Drama', 'k-drama', ' K-DRAMA ', '🎬 k-drama']) {
        expect((r(s).kind, r(s).id), (PackKind.user, 'user_1'), reason: '"$s"');
      }
    });

    test('anything else is a new pack, tidy name, typed emoji kept for the picker', () {
      final c = r('  🍕 Pizza   night ');
      expect((c.kind, c.id, c.name, c.typedEmoji), (PackKind.newPack, '', 'Pizza night', '🍕'));
      final d = r('Travel');
      expect((d.kind, d.name, d.typedEmoji), (PackKind.newPack, 'Travel', ''));
      expect(r('Foods').kind, PackKind.newPack, reason: 'no fuzzy matching');
    });
  });

  group('visibility', () {
    test('My Words / built-in pack / user pack rules', () async {
      final s = await fresh();
      final mine = await s.saveWord(word('Kimbap roll', '김밥말이'), packChoice: s.resolvePack(''));
      final inFood = await s.saveWord(word('Tteokbokki', '떡볶이'), packChoice: s.resolvePack('Food'));
      final inUser = await s.saveWord(
        word('Actor', '배우'),
        packChoice: s.resolvePack('K-Drama'),
        newPackEmoji: '🎬',
      );
      expect(mine.packId, customBundleId);
      expect(inFood.packId, 'food');
      final drama = s.userPacks.single;
      expect((inUser.packId, drama.name, drama.emoji), (drama.id, 'K-Drama', '🎬'));
      expect(s.enabledBundles, contains(drama.id), reason: 'new packs start on');

      bool playing(VocabEntry e) => s.activeVocab().any((x) => x.sectionName == e.sectionName);
      expect([mine, inFood, inUser].every(playing), isTrue);

      // Built-in pack word needs BOTH My Words and its pack.
      await s.setBundleEnabled('food', false);
      expect((playing(inFood), playing(mine)), (false, true));
      await s.setBundleEnabled('food', true);
      await s.setBundleEnabled(customBundleId, false);
      expect((playing(inFood), playing(mine)), (false, false));
      // User packs do not care about My Words.
      expect(playing(inUser), isTrue);
      await s.setBundleEnabled(drama.id, false);
      expect(playing(inUser), isFalse);
      await s.setBundleEnabled(customBundleId, true);
      expect((playing(inFood), playing(mine), playing(inUser)), (true, true, false));

      // Listing: the Food pack lists the attached word; so does My Words.
      expect(s.wordsInPack('food').map((e) => e.sectionName), contains(inFood.sectionName));
      expect(
        s.wordsInPack(customBundleId).map((e) => e.sectionName),
        containsAll([mine.sectionName, inFood.sectionName]),
      );
      expect(s.wordsInPack(drama.id).single.sectionName, inUser.sectionName);
    });
  });

  group('empty user packs', () {
    test('are deleted with their switch; built-in packs never are', () async {
      final s = await fresh();
      final a = await s.saveWord(
        word('Beach', '해변'),
        packChoice: s.resolvePack('Travel'),
        newPackEmoji: '🏖️',
      );
      final id = a.packId;
      final b = await s.saveWord(word('Hotel', '호텔'), packChoice: s.resolvePack('travel'));
      expect(b.packId, id, reason: 'same pack, no duplicate');
      expect(s.userPacks.length, 1);
      await s.setBundleEnabled(id, false);

      await s.deleteCustomWord(a);
      expect(s.userPacks.length, 1, reason: 'still has Hotel');
      // Moving the last word out empties the pack.
      await s.saveWord(b, packChoice: s.resolvePack('My Words'));
      expect(s.userPacks, isEmpty);
      expect(s.enabledBundles.any(isUserPackId), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(AppState.kUserPacks)!), isEmpty);
      expect(prefs.getStringList('enabled_bundles')!.any(isUserPackId), isFalse);
      expect((await reload()).userPacks, isEmpty);

      // Move every Colour Splash word away: the pack is hidden, never deleted.
      for (final e in s.wordsInPack('colours').toList()) {
        await s.saveWord(e, packChoice: s.resolvePack('Grab Bag'));
      }
      expect(s.wordsInPack('colours'), isEmpty);
      expect(s.builtInPackIds, isNot(contains('colours')));
      expect(builtInBundleById('colours'), isNotNull);
      expect(s.enabledBundles, contains('colours'));
    });
  });

  group('built-in edits', () {
    test('saved as overrides by section, survive restart, Reset restores', () async {
      final s = await fresh();
      final cat = s.effectiveBuiltIn.firstWhere((e) => e.english1 == 'Cat');
      expect(cat.packId, 'animals');
      final edited = await s.saveWord(
        cat.copyWith(korean2: '냥이'),
        packChoice: s.resolvePack('Pets'),
        newPackEmoji: '🐾',
      );
      expect(s.isOverridden(cat), isTrue);
      expect(
        s.customWords.map((e) => e.sectionName),
        seededMyWords.map((e) => e.sectionName),
        reason: 'an edit, not a copy',
      );
      expect(s.builtIn.firstWhere((e) => e.english1 == 'Cat').korean2, '', reason: 'original');

      var t = await reload();
      final cat2 = t.effectiveBuiltIn.firstWhere((e) => e.sectionName == cat.sectionName);
      expect((cat2.korean2, cat2.packId), ('냥이', edited.packId));
      expect(t.userPacks.single.name, 'Pets');
      expect(t.wordsInPack('animals').any((e) => e.sectionName == cat.sectionName), isFalse);
      expect(t.activeVocab().where((e) => e.sectionName == cat.sectionName).single.korean2, '냥이');

      await t.resetBuiltInWord(cat2);
      expect(t.isOverridden(cat2), isFalse);
      expect(t.userPacks, isEmpty, reason: 'Pets emptied by the reset');
      t = await reload();
      final cat3 = t.effectiveBuiltIn.firstWhere((e) => e.sectionName == cat.sectionName);
      expect(cat3, cat);
    });

    test('saving an unchanged built-in word stores no override', () async {
      final s = await fresh();
      final dog = s.effectiveBuiltIn.firstWhere((e) => e.english1 == 'Dog');
      await s.saveWord(dog, packChoice: s.resolvePack('Animals'));
      expect(s.overrides, isEmpty);
    });

    test('an override for a section no longer in the vocab file is ignored', () async {
      final s = await fresh({
        AppState.kOverrides: jsonEncode({
          'Entry_99999': word('Ghost', '유령', pack: 'food').toJson(),
        }),
      });
      expect(s.activeVocab().any((e) => e.english1 == 'Ghost'), isFalse);
      expect(s.overrides, isEmpty); // dropped, e.g. edits of the removed 🏃 Action Heroes
      expect(
        s.activeVocab().length,
        463,
      ); // the same as a fresh install: 🗣️ and the other default-off packs off
    });
  });

  group('decoys', () {
    test('wrong answers come from the same pack first, then same phrase-ness', () {
      final list = [
        for (var i = 0; i < 4; i++) word('pet$i', '펫$i', pack: 'user_pets', section: 'p$i'),
        for (var i = 0; i < 20; i++) word('food$i', '음식$i', pack: 'food', section: 'f$i'),
        const VocabEntry(
          sectionName: 'ph',
          english1: 'Hello there',
          korean1: '안녕하세요',
          packId: 'user_pets',
          isFullPhrase: true,
        ),
      ];
      final eng = GameEngine(list, random: Random(3));
      for (var i = 0; i < 30; i++) {
        final w = eng.getWrongAnswers(list[0], list);
        expect(w.every((x) => x.packId == 'user_pets' && !x.isFullPhrase), isTrue);
      }
      // Pack too small for its phrase: other packs' phrase-ness tier is empty,
      // so it falls to anything in play.
      expect(eng.getWrongAnswers(list.last, list).length, 2);
      // Wrong characters: the same pack is used first.
      final chars = eng.getWrongCharacters('펫0', list[0], list, optionCount: 3);
      expect(chars.length, 3);
      expect({'1', '2', '3', '안', '녕', '하', '세', '요'}.containsAll(chars), isTrue, reason: '$chars');
    });
  });

  group('All packs', () {
    test('covers user packs, never My Words', () async {
      final s = await fresh();
      await s.saveWord(
        word('Beach', '해변'),
        packChoice: s.resolvePack('Travel'),
        newPackEmoji: '🏖️',
      );
      final id = s.userPacks.single.id;
      expect(s.allPackIds, contains(id));
      await s.setAllPacks(false);
      expect(s.enabledBundles, {customBundleId});
      // Only the seeded family names in My Words are left in play.
      expect(s.activeVocab().map((e) => e.sectionName), seededMyWords.map((e) => e.sectionName));
      await s.setBundleEnabled(id, true);
      expect(s.allPacksOn, isTrue, reason: 'a user pack alone counts');
      await s.setBundleEnabled(id, false);
      await s.setAllPacks(true);
      expect(s.enabledBundles, containsAll([...s.builtInPackIds, id, customBundleId]));
    });
  });

  group('migration and persistence', () {
    test('packs, order, toggles, words and edits all survive a restart', () async {
      final s = await fresh();
      for (final (name, emoji) in [('Zoo', '🦁'), ('Anime', '🍥'), ('Music', '🎵')]) {
        await s.saveWord(
          word('$name word', '단어'),
          packChoice: s.resolvePack(name),
          newPackEmoji: emoji,
        );
      }
      await s.saveWord(word('Rice cake', '떡'), packChoice: s.resolvePack('🍜 food'));
      final sun = s.effectiveBuiltIn.firstWhere((e) => e.english1 == 'Sunday');
      await s.saveWord(sun.copyWith(emoji: '🌞'), packChoice: s.resolvePack('Zoo'));
      await s.setBundleEnabled(s.userPacks[1].id, false);
      await s.setBundleEnabled('food', false);

      final t = await reload();
      expect(t.userPacks.map((p) => (p.name, p.emoji)), [
        ('Zoo', '🦁'),
        ('Anime', '🍥'),
        ('Music', '🎵'),
      ]);
      expect(t.enabledBundles.contains(t.userPacks[1].id), isFalse);
      expect(t.enabledBundles.contains(t.userPacks[0].id), isTrue);
      expect(t.enabledBundles.contains('food'), isFalse);
      expect(t.customWords.map((e) => e.packId), [
        ...seededMyWords.map((e) => e.packId),
        t.userPacks[0].id,
        t.userPacks[1].id,
        t.userPacks[2].id,
        'food',
      ]);
      final sun2 = t.effectiveBuiltIn.firstWhere((e) => e.sectionName == sun.sectionName);
      expect((sun2.emoji, sun2.packId), ('🌞', t.userPacks[0].id));
      expect(t.wordsInPack(t.userPacks[0].id).length, 2);
    });
  });

  group('screens', () {
    Future<void> setUp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      await tester.runAsync(appState.load);
    }

    testWidgets('new pack: emoji picker first; Back saves nothing; Confirm saves', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: EditWordScreen()));
      expect(find.text('➕ New Word'), findsOneWidget);
      expect(find.textContaining('ategor'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), '배우');
      await tester.enterText(find.byType(TextFormField).at(2), 'Actor');
      await tester.enterText(find.byKey(const ValueKey('pack_field')), ' k-drama ');
      await tester.pump();
      expect(find.textContaining('New pack "k-drama"'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_word')));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPickerScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('➕ New Word'), findsOneWidget, reason: 'back on the form');
      expect(
        appState.customWords.map((e) => e.sectionName),
        seededMyWords.map((e) => e.sectionName),
      );
      expect(appState.userPacks, isEmpty);

      await tester.tap(find.byKey(const ValueKey('save_word')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('emoji_field')), '🦖🦕');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('emoji_preview'))).data, '🦖');
      await tester.tap(find.byKey(const ValueKey('emoji_choice_🎬')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('emoji_confirm')));
      await tester.pumpAndSettle();
      expect(appState.userPacks.single.name, 'k-drama');
      expect(appState.userPacks.single.emoji, '🎬');
      expect(appState.customWords.last.packId, appState.userPacks.single.id);
      expect(appState.customWords, hasLength(seededMyWords.length + 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('quick-picks: My Words, every built-in pack and user packs', (tester) async {
      await setUp(tester);
      await tester.runAsync(
        () => appState.saveWord(
          word('Beach', '해변'),
          packChoice: appState.resolvePack('Travel'),
          newPackEmoji: '🏖️',
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: EditWordScreen()));
      for (final id in [customBundleId, ...appState.builtInPackIds, appState.userPacks[0].id]) {
        expect(find.byKey(ValueKey('pack_pick_$id')), findsOneWidget, reason: id);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('pack_pick_food')));
      await tester.tap(find.byKey(const ValueKey('pack_pick_food')));
      await tester.pump();
      expect(
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('pack_pick_food'))).selected,
        isTrue,
      );
      expect(appState.resolvePack('Food').id, 'food');
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pump();
      expect(
        tester.widget<TextFormField>(find.byKey(const ValueKey('pack_field'))).controller!.text,
        'Food',
      );
      expect(find.textContaining('Plays when'), findsNothing, reason: 'helper text removed');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Word Packs: hint, long-press opens Edit Word with Reset', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      expect(find.text('Tap a word to hear it. Long press to edit it.'), findsNothing);
      await tester.tap(find.text('Handy Phrases'));
      await tester.pumpAndSettle();
      expect(find.text('Tap a word to hear it. Long press to edit it.'), findsOneWidget);
      expect(find.textContaining('✏️ '), findsNothing, reason: 'no pencil on every word');
      final first = appState.wordsInPack('phrases').first;
      await tester.longPress(find.byKey(ValueKey('word_${first.sectionName}')));
      await tester.pumpAndSettle();
      expect(find.text('✏️ Edit Word'), findsOneWidget);
      expect(find.byKey(const ValueKey('reset_word')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete_word')), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byKey(const ValueKey('pack_field'))).controller!.text,
        'Handy Phrases',
      );
      // Edit it, save, then Reset.
      await tester.enterText(find.byType(TextFormField).at(1), '테스트');
      await tester.tap(find.byKey(const ValueKey('save_word')));
      await tester.pumpAndSettle();
      expect(appState.isOverridden(first), isTrue);
      expect(find.byType(BundlesScreen), findsOneWidget);
      await tester.longPress(find.byKey(ValueKey('word_${first.sectionName}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reset_word')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();
      expect(appState.isOverridden(first), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('custom words get Delete instead of Reset', (tester) async {
      await setUp(tester);
      final w = (await tester.runAsync(
        () => appState.saveWord(word('Pen', '펜'), packChoice: appState.resolvePack('')),
      ))!;
      await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: w)));
      expect(find.byKey(const ValueKey('delete_word')), findsOneWidget);
      expect(find.byKey(const ValueKey('reset_word')), findsNothing);
      expect(find.text('✏️ Edit Word'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
