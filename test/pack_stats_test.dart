import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/data/packs.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/pack_stats_screen.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _load(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
}

int _session(String id) => appState.packSessionWins[id] ?? 0;

/// A built-in word that is also in another pack.
VocabEntry _shared() => appState.effectiveBuiltIn.firstWhere((e) => e.alsoPacks.isNotEmpty);

/// The built-in pack with the fewest words.
String _smallestPack() =>
    (appState.builtInPackIds.toList()..sort(
          (a, b) => appState.wordsInPack(a).length.compareTo(appState.wordsInPack(b).length),
        ))
        .first;

void main() {
  testWidgets('a win counts for every pack its word is in: session, today, all time', (
    tester,
  ) async {
    await _load(tester);
    final w = _shared();
    final packs = [w.packId, ...w.alsoPacks];
    expect(packs.length, greaterThanOrEqualTo(2));
    final before = {for (final p in packs) p: _session(p)};
    final other = appState.builtInPackIds.firstWhere((p) => !w.inPack(p));
    final otherBefore = _session(other);
    final today = dayKey(DateTime.now());

    await appState.recordWin(1, word: w);
    await appState.recordWin(4, word: w);
    for (final p in packs) {
      expect(_session(p), before[p]! + 2, reason: p);
      expect(appState.packWinsOnDay(p, today), 2, reason: p);
      expect(appState.packAllTime(p), 2, reason: p);
    }
    expect(_session(other), otherBefore, reason: 'other packs untouched');
    expect(appState.packAllTime(other), 0);
    expect(appState.wonWords, contains(w.sectionName));
    // The game stats still count each win once.
    expect(appState.winsOnDay(today), 2);
  });

  testWidgets('7️⃣ 8️⃣ 9️⃣ wins (no word) leave the packs alone', (tester) async {
    await _load(tester);
    final before = Map.of(appState.packSessionWins);
    final total = appState.allTimeTotal;
    await appState.recordWin(7);
    await appState.recordWin(9);
    expect(appState.packSessionWins, before);
    expect(appState.packWinsByDay, isEmpty);
    expect(appState.wonWords, isEmpty);
    expect(appState.allTimeTotal, total + 2);
  });

  testWidgets('today resets at midnight; all time keeps every day', (tester) async {
    await _load(tester);
    final w = appState.effectiveBuiltIn.firstWhere((e) => e.alsoPacks.isEmpty);
    final p = w.packId;
    final late = DateTime(2026, 10, 27, 23, 59);
    final early = DateTime(2026, 10, 28, 0, 1);
    await appState.recordWin(1, word: w, now: late);
    await appState.recordWin(1, word: w, now: late);
    await appState.recordWin(2, word: w, now: early);
    expect(appState.packWinsOnDay(p, dayKey(late)), 2);
    expect(appState.packWinsOnDay(p, dayKey(early)), 1);
    expect(appState.packWinsOnDay(p, dayKey(DateTime(2026, 10, 29))), 0);
    expect(appState.packAllTime(p), 3);
  });

  testWidgets('day and all-time pack wins and won words survive a restart', (tester) async {
    await _load(tester);
    final w = _shared();
    await appState.recordWin(3, word: w, now: DateTime(2026, 10, 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = {for (final k in prefs.getKeys()) k: prefs.get(k)!}
        .map((k, v) => MapEntry(k, v is List ? List<String>.from(v) : v));
    await _load(tester, saved.cast<String, Object>());
    expect(appState.packAllTime(w.packId), 1);
    expect(appState.packWinsOnDay(w.alsoPacks.first, '2026-10-01'), 1);
    expect(appState.wonWords, {w.sectionName});
  });

  testWidgets('an older install starts with zero pack stats and keeps its game stats', (
    tester,
  ) async {
    await _load(tester, {
      'wins_by_day': jsonEncode({
        '2026-09-30': {'1': 4, '9': 2},
      }),
    });
    expect(appState.allTimeTotal, 6);
    expect(appState.allTimeByGame[1], 4);
    expect(appState.packWinsByDay, isEmpty);
    expect(appState.wonWords, isEmpty);
    for (final id in appState.statsPackIds) {
      expect(appState.packAllTime(id), 0);
      expect(appState.packStarred(id), isFalse);
    }
  });

  testWidgets('a broken pack-stats save is ignored, not fatal', (tester) async {
    await _load(tester, {AppState.kPackWins: 'not json'});
    expect(appState.packWinsByDay, isEmpty);
  });

  testWidgets('a word you added to a built-in pack counts for it and for My Words', (tester) async {
    await _load(tester);
    final pack = builtInBundles.first;
    final w = await appState.saveWord(
      const VocabEntry(english1: 'Zebra crossing', korean1: '횡단보도'),
      packChoice: PackChoice(PackKind.builtIn, pack.id, pack.name),
    );
    expect(appState.packsOfWord(w), {pack.id, customBundleId});
    final my = await appState.saveWord(
      const VocabEntry(english1: 'Kite', korean1: '연'),
      packChoice: const PackChoice(PackKind.myWords, customBundleId, myWordsName),
    );
    expect(appState.packsOfWord(my), {customBundleId});
    await appState.recordWin(1, word: w);
    expect(appState.packAllTime(pack.id), 1);
    expect(appState.packAllTime(customBundleId), 1);
  });

  testWidgets('⭐ once every word in the pack has been won; new words take it away', (tester) async {
    await _load(tester);
    final id = _smallestPack();
    final words = appState.wordsInPack(id);
    expect(appState.packStarred(id), isFalse);
    for (final w in words.skip(1)) {
      await appState.recordWin(1, word: w);
    }
    expect(appState.packStarred(id), isFalse, reason: 'one word still unwon');
    expect(appState.packWordProgress(id), (won: words.length - 1, total: words.length));
    // Winning the same word again doesn't fill the gap.
    await appState.recordWin(1, word: words[1]);
    expect(appState.packStarred(id), isFalse);
    await appState.recordWin(2, word: words.first);
    expect(appState.packStarred(id), isTrue);

    // The pack grows: the star waits for the new word.
    final pack = builtInBundleById(id)!;
    final added = await appState.saveWord(
      const VocabEntry(english1: 'Brand new', korean1: '새것'),
      packChoice: PackChoice(PackKind.builtIn, id, pack.name),
    );
    expect(appState.packStarred(id), isFalse);
    await appState.recordWin(1, word: added);
    expect(appState.packStarred(id), isTrue);
    // An empty pack never has a star.
    expect(appState.packStarred('no_such_pack'), isFalse);
  });

  test('rounds carry their word for 1️⃣-6️⃣, none for 7️⃣ 8️⃣ 9️⃣', () {
    const words = [
      VocabEntry(sectionName: 'a', packId: 'food', english1: 'Apple', korean1: '사과'),
      VocabEntry(sectionName: 'b', packId: 'food', english1: 'Banana', korean1: '바나나'),
      VocabEntry(sectionName: 'c', packId: 'food', english1: 'Grapes', korean1: '포도'),
    ];
    final engine = GameEngine(words, random: Random(1));
    VocabEntry? wordOf(Object r) => r is ChoiceRound
        ? r.word
        : r is TypingRound
        ? r.word
        : null;
    for (var g = 1; g <= 6; g++) {
      final r = legacyRound(engine, g);
      expect(words, contains(wordOf(r)), reason: 'game $g');
    }
    for (var i = 0; i < 10; i++) {
      expect(wordOf(engine.newRound(7)), isNull);
      expect(wordOf(engine.newRound(8)), isNull);
    }
    expect(engine.newRound(9), isA<ColorRound>());
  });

  testWidgets('winning a round in a game credits its word\'s packs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await _load(tester);
    GameEngine.pickKoreanFormat = true; // old 2️⃣: 1️⃣ in its pick-the-Korean format
    addTearDown(() => GameEngine.pickKoreanFormat = null);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
    await tester.pump();
    final r = (tester.state(find.byType(GameScreen)) as dynamic).currentRound as ChoiceRound;
    final w = r.word!;
    final before = {for (final p in appState.packsOfWord(w)) p: _session(p)};
    await tester.tap(find.text(r.correctAnswer).last);
    await tester.pump();
    for (final p in before.keys) {
      expect(_session(p), before[p]! + 1, reason: p);
      expect(appState.packAllTime(p), 1, reason: p);
    }
    expect(appState.wonWords, {w.sectionName});
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('decoys in a won round never count: only the target word and its packs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await _load(tester);
    for (final game in [1, 2, 1, 2, 1, 2]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: _legacy(game)),
        ),
      );
      await tester.pump();
      final r = (tester.state(find.byType(GameScreen)) as dynamic).currentRound as ChoiceRound;
      final target = r.word!;
      final targetPacks = appState.packsOfWord(target);
      // The words shown as wrong options in this round.
      bool shows(String o, VocabEntry e) {
        final en = e.english1.split(' (').first.trim();
        return o == e.korean1.trim() ||
            (e.korean2.isNotEmpty && o == e.korean2.trim()) ||
            (e.emoji.isNotEmpty && o == e.emoji) ||
            (en.isNotEmpty && o.startsWith(en));
      }

      final decoys = appState.effectiveBuiltIn
          .where(
            (e) =>
                e.sectionName != target.sectionName &&
                r.options.any((o) => o != r.correctAnswer && shows(o, e)),
          )
          .toList();
      expect(decoys, isNotEmpty, reason: 'game $game has decoys');
      final wonBefore = Set.of(appState.wonWords);
      final allBefore = {for (final p in appState.statsPackIds) p: appState.packAllTime(p)};
      await tester.tap(find.text(r.correctAnswer).last);
      await tester.pump();
      expect(appState.wonWords.difference(wonBefore), {target.sectionName}, reason: 'game $game');
      for (final d in decoys) {
        if (!wonBefore.contains(d.sectionName)) {
          expect(appState.wonWords, isNot(contains(d.sectionName)), reason: d.english1);
        }
      }
      for (final p in appState.statsPackIds) {
        expect(
          appState.packAllTime(p),
          allBefore[p]! + (targetPacks.contains(p) ? 1 : 0),
          reason: 'game $game pack $p',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('📊 Stats ▸ 📦 Word Pack Stats lists every pack with its numbers and ⭐', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await _load(tester);
    // Some packs switched off: they're still listed.
    await appState.setAllPacks(false);
    final id = _smallestPack();
    for (final w in appState.wordsInPack(id)) {
      await appState.recordWin(1, word: w);
    }
    final n = appState.wordsInPack(id).length;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await appState.recordWin(1, word: appState.wordsInPack(id).first, now: yesterday);

    await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
    await tester.pump();
    expect(find.text('Word Pack Stats'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pack_stats_entry')));
    await tester.pumpAndSettle();
    expect(find.byType(PackStatsScreen), findsOneWidget);
    expect(find.text('📦 Word Pack Stats'), findsOneWidget);

    final ids = appState.statsPackIds;
    expect(ids.last, customBundleId);
    expect(ids.toSet(), {...appState.builtInPackIds, customBundleId});
    final list = find
        .descendant(of: find.byType(PackStatsScreen), matching: find.byType(Scrollable))
        .first;
    for (final p in ids) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('pack_stats_$p')), 50, scrollable: list);
      final label = appState.packLabel(p);
      final row = find.byKey(ValueKey('pack_stats_$p'));
      expect(find.descendant(of: row, matching: find.text(label.name)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(label.emoji)), findsOneWidget);
      // The star slot is always there and the same width.
      final slot = find.byKey(ValueKey('pack_star_slot_$p'));
      expect(tester.getSize(slot).width, 30);
      expect(
        find.descendant(of: row, matching: find.byKey(const ValueKey('pack_star'))),
        p == id ? findsOneWidget : findsNothing,
        reason: p,
      );
      if (p == id) {
        String num(String k) => tester.widget<Text>(find.byKey(ValueKey('pack_${k}_$p'))).data!;
        expect(num('today'), '$n');
        expect(num('alltime'), '${n + 1}');
        expect(int.parse(num('session')), greaterThanOrEqualTo(n + 1));
        expect(
          tester.widget<Text>(find.byKey(ValueKey('pack_progress_$p'))).data,
          '$n/$n words won',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}

/// Old 2️⃣ 🎯 Pick the Korean is 1️⃣ in its Korean-answer format now.
int _legacy(int game) {
  GameEngine.pickKoreanFormat = game == 2 ? true : null;
  addTearDown(() => GameEngine.pickKoreanFormat = null);
  return game == 2 ? 1 : game;
}
