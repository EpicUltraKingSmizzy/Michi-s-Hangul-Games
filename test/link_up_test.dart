import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:hangul_hooray/widgets/emoji_peek.dart';
import 'package:hangul_hooray/widgets/link_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en, [String emoji = '', bool phrase = false]) => VocabEntry(
  sectionName: '$ko|$en',
  packId: 'test',
  korean1: ko,
  english1: en,
  emoji: emoji,
  isFullPhrase: phrase,
);

final _six = [
  _w('사과', 'Apple', '🍎'),
  _w('개', 'Dog', '🐶'),
  _w('물', 'Water', '💧'),
  _w('집', 'House', '🏠'),
  _w('책', 'Book', '📚'),
  _w('달', 'Moon', '🌙'),
];

LinkRound _round() => LinkRound(
  pairs: [for (final w in _six) LinkPair(word: w, korean: w.korean1, english: w.emoji)],
  rightOrder: [3, 0, 5, 1, 4, 2],
);

/// Haptic calls on the vibrate channel (buzz length in ms).
final _buzzes = <int>[];

Future<void> _setUp(WidgetTester tester, {bool vibration = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: vibration,
  });
  await tester.runAsync(appState.load);
  _buzzes.clear();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('michi/vibrate'),
    (call) async {
      _buzzes.add((call.arguments as Map)['ms'] as int);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('michi/vibrate'),
      null,
    ),
  );
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

Finder _card(bool left, int row) => find.byKey(ValueKey('link_${left ? 'left' : 'right'}_$row'));

/// Draws a line by dragging from one card to another.
Future<void> _drag(WidgetTester tester, Finder from, Finder to) async {
  final g = await tester.startGesture(tester.getCenter(from));
  await g.moveTo(Offset.lerp(tester.getCenter(from), tester.getCenter(to), 0.5)!);
  await g.moveTo(tester.getCenter(to));
  await g.up();
  await tester.pump();
}

bool _confettiPlaying(WidgetTester tester) =>
    tester.widget<ConfettiWidget>(find.byType(ConfettiWidget)).confettiController.state ==
    ConfettiControllerState.playing;

Color? _textColor(WidgetTester tester, bool left, int row) => tester
    .widget<FitText>(find.byKey(ValueKey('link_text_${left ? 'left' : 'right'}_$row')))
    .style
    .color;

void main() {
  group('LinkBoard', () {
    test('right lines lock in; wrong and already-linked ends do not', () {
      final r = _round();
      final b = LinkBoard(r);
      expect(r.matches(0, 1), isTrue);
      expect(r.rightText(0), '🏠');
      expect(b.tryLink(0, 0), LinkResult.wrong);
      expect(b.locked, <int, int>{});
      expect(b.tryLink(0, 1), LinkResult.linked);
      expect(b.leftLocked(0), isTrue);
      expect(b.rightLocked(1), isTrue);
      expect(b.tryLink(0, 1), LinkResult.ignored, reason: 'already linked');
      expect(b.tryLink(3, 1), LinkResult.ignored, reason: 'right end taken');
      expect(b.tryLink(3, 0), LinkResult.linked);
      expect(b.lockOrder(3), 1);
      expect(b.lockOrder(0), 0);
      expect(b.lockOrder(5), isNull);
      expect(b.complete, isFalse);
      for (var left = 0; left < 6; left++) {
        b.tryLink(left, r.rightOrder.indexOf(left));
      }
      expect(b.complete, isTrue);
      expect(r.words, _six);
    });
  });

  group('words on a board', () {
    test('no two clash: same emoji, same English, notes hidden, shared Korean', () {
      final pool = [
        _w('사과', 'Apple', '🍎'),
        _w('빨간 사과', 'Red apple', '🍎'), // same emoji
        _w('차', 'Tea', '🍵'),
        _w('차', 'Car', '🚗'), // same Korean
        _w('밥', 'Rice (meal)'),
        _w('쌀', 'Rice (uncooked)'), // same English once notes are hidden
        _w('개', 'Dog', '🐶'),
        _w('강아지', 'dog'), // same English (one shows English)
        _w('물', 'Water', '💧'),
        _w('집', 'House', '🏠'),
      ];
      final e = GameEngine(pool, random: Random(1))..showBracketNotes = false;
      final words = e.linkWords(pool);
      expect(words.map((w) => w.korean1), ['사과', '차', '밥', '개', '물', '집']);
      for (final a in words) {
        for (final b in words) {
          if (!identical(a, b)) expect(GameEngine.entriesClash(a, b), isFalse);
        }
      }
      // With the notes shown, both rice words fit.
      e.showBracketNotes = true;
      expect(e.linkWords(pool).map((w) => w.korean1), contains('쌀'));
      // With emoji off, the two apples show different English: no clash.
      e.useEmoji = false;
      expect(e.linkWords(pool).map((w) => w.korean1), contains('빨간 사과'));
    });

    test('canPlay: 🔟 needs 6 words that cannot be mixed up', () {
      expect(GameEngine(_six).canPlay(GameEngine.linkUpGame), isTrue);
      expect(GameEngine(_six.take(5).toList()).canPlay(GameEngine.linkUpGame), isFalse);
      final clash = [..._six.take(5), _w('사과나무', 'Apple tree', '🍎')];
      expect(GameEngine(clash).canPlay(GameEngine.linkUpGame), isFalse);
      expect(GameEngine(clash).canPlay(1), isTrue, reason: 'other games still play');
      expect(GameEngine([]).canPlay(GameEngine.linkUpGame), isFalse);
    });

    test('a board: 6 pairs, right side shuffled, follows Emoji and Bracket notes', () {
      final pool = [..._six.take(5), _w('밥', 'Rice (meal)')];
      final e = GameEngine(pool, random: Random(7))
        ..useEmoji = true
        ..showBracketNotes = false;
      final r = e.newRound(GameEngine.linkUpGame) as LinkRound;
      expect(r.pairs.length, 6);
      expect(r.rightOrder.toSet(), {0, 1, 2, 3, 4, 5});
      expect(r.words.toSet(), pool.toSet());
      final right = {for (var s = 0; s < 6; s++) r.rightText(s)};
      expect(right, containsAll(['🍎', '🐶', 'Rice']));
      e
        ..useEmoji = false
        ..showBracketNotes = true;
      final r2 = e.newRound(GameEngine.linkUpGame) as LinkRound;
      expect({for (var s = 0; s < 6; s++) r2.rightText(s)}, containsAll(['Apple', 'Rice (meal)']));
    });
  });

  group('🔟 board word choice: one pack, one kind', () {
    var n = 0;
    VocabEntry p(String pack, bool phrase, {List<String> also = const [], String emoji = ''}) {
      n++;
      return VocabEntry(
        sectionName: 'w$n',
        packId: pack,
        korean1: '단어$n',
        english1: phrase ? 'Phrase number $n' : 'Word$n',
        emoji: emoji,
        isFullPhrase: phrase,
        alsoPacks: also,
      );
    }

    List<VocabEntry> many(String pack, int words, int phrases, {List<String> also = const []}) => [
      for (var i = 0; i < words; i++) p(pack, false, also: also),
      for (var i = 0; i < phrases; i++) p(pack, true, also: also),
    ];

    List<LinkRound> boards(List<VocabEntry> vocab, {int count = 120}) => [
      for (var seed = 0; seed < count; seed++)
        GameEngine(vocab, random: Random(seed)).newRound(GameEngine.linkUpGame) as LinkRound,
    ];

    bool oneKind(LinkRound r) => r.words.map((w) => w.isFullPhrase).toSet().length == 1;
    Set<String> sharedPacks(LinkRound r) =>
        r.words.map((w) => w.packIds.toSet()).reduce((a, b) => a.intersection(b));

    test('every board comes from one pack and never mixes words and phrases', () {
      final vocab = [...many('A', 8, 8), ...many('B', 7, 0), ...many('C', 2, 7)];
      final used = <String>{};
      for (final r in boards(vocab, count: 200)) {
        expect(r.words.length, 6);
        expect(oneKind(r), isTrue);
        final shared = sharedPacks(r);
        expect(shared, hasLength(1));
        used.add('${shared.single}${r.words.first.isFullPhrase ? 'P' : 'W'}');
      }
      // Packs picked at random; B can only be words, C only phrases.
      expect(used, {'AW', 'AP', 'BW', 'CP'});
    });

    test('a pack with 6+ words and 6+ phrases flips a coin', () {
      final vocab = many('A', 8, 8);
      final phrases = boards(vocab, count: 400).where((r) => r.words.first.isFullPhrase).length;
      expect(phrases, inInclusiveRange(150, 250), reason: 'about half of 400');
    });

    test('phrase-only pack, or under 6 words: all phrases', () {
      for (final r in boards(many('A', 0, 7))) {
        expect(r.words.every((w) => w.isFullPhrase), isTrue);
      }
      for (final r in boards(many('A', 5, 7))) {
        expect(r.words.every((w) => w.isFullPhrase), isTrue);
      }
    });

    test('6+ words but under 6 phrases: all words', () {
      for (final r in boards(many('A', 7, 5))) {
        expect(r.words.every((w) => !w.isFullPhrase), isTrue);
      }
    });

    test("a pack that can't fill a board is passed over for another", () {
      final small = many('X', 5, 5);
      final vocab = [...small, ...many('Y', 6, 0)];
      for (final r in boards(vocab)) {
        expect(sharedPacks(r), {'Y'});
        expect(r.words.toSet().intersection(small.toSet()), isEmpty);
      }
    });

    test('AlsoPacks words count toward the extra pack', () {
      // A has 4 of its own words + 2 shared from B; B alone can't fill.
      final vocab = [
        ...many('A', 4, 0),
        ...many('B', 2, 0, also: const ['A']),
      ];
      for (final r in boards(vocab, count: 30)) {
        expect(r.words.length, 6);
        expect(r.words.every((w) => w.inPack('A')), isTrue);
      }
    });

    test('no pack can fill one: all packs pooled, still one kind', () {
      final vocab = [...many('X', 3, 4), ...many('Y', 3, 4), ...many('Z', 1, 0)];
      final kinds = <bool>{};
      for (final r in boards(vocab, count: 100)) {
        expect(r.words.length, 6);
        expect(oneKind(r), isTrue);
        expect(sharedPacks(r), isEmpty, reason: 'spans packs');
        kinds.add(r.words.first.isFullPhrase);
      }
      expect(kinds, {true, false}, reason: '7 words and 8 phrases: either kind');
      expect(GameEngine(vocab).canPlay(GameEngine.linkUpGame), isTrue);
      // 5 words + 5 phrases can't make a single-kind board: no 🔟.
      expect(GameEngine(many('X', 5, 5)).canPlay(GameEngine.linkUpGame), isFalse);
      expect(GameEngine(many('X', 3, 3)).canPlay(1), isTrue);
    });

    test('collisions still respected inside the chosen pack', () {
      // Pack A: 6 words but two share an emoji, so it holds only 5 that
      // can't be mixed up; with a 7th it can fill a board again.
      final clashing = [...many('A', 4, 0), p('A', false, emoji: '🍎'), p('A', false, emoji: '🍎')];
      final b = many('B', 6, 0);
      for (final r in boards([...clashing, ...b], count: 40)) {
        expect(sharedPacks(r), {'B'});
      }
      final extra = p('A', false);
      for (final r in boards([...clashing, extra], count: 40)) {
        expect(r.words.length, 6);
        expect(r.words.where((w) => w.emoji == '🍎'), hasLength(1));
        for (final a in r.words) {
          for (final c in r.words) {
            if (!identical(a, c)) expect(GameEngine.entriesClash(a, c), isFalse);
          }
        }
      }
    });

    testWidgets('in the app: only switched-on packs count (✏️ My Words too)', (tester) async {
      await _setUp(tester);
      final e = appState.engine;
      expect(e.linkPacksOf, isNotNull);
      for (var i = 0; i < 40; i++) {
        final r = e.newRound(GameEngine.linkUpGame) as LinkRound;
        expect(r.words.length, 6);
        expect(oneKind(r), isTrue);
        final shared = r.words
            .map((w) => appState.packsOfWord(w).where(appState.enabledBundles.contains).toSet())
            .reduce((a, b) => a.intersection(b));
        expect(shared, isNotEmpty, reason: 'one switched-on pack holds all 6');
      }
    });
  });

  group('playing 🔟 🔗 Link Up', () {
    testWidgets('wrong line flashes red 1 s and buzzes; right lines lock in; confetti at 6/6', (
      tester,
    ) async {
      await _setUp(tester, vibration: true);
      appState.engine = GameEngine(_six, random: Random(3));
      final winsBefore = appState.sessionWins[GameEngine.linkUpGame] ?? 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: GameEngine.linkUpGame),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Draw a line to link each pair! ✏️'), findsOneWidget);
      final r = _state(tester).currentRound as LinkRound;
      int slotOf(int left) => r.rightOrder.indexOf(left);

      // Wrong line: red for a second, a short buzz, then it's gone.
      final wrongSlot = (slotOf(0) + 1) % 6;
      await _drag(tester, _card(true, 0), _card(false, wrongSlot));
      expect(_state(tester).wrongLine, (0, wrongSlot));
      expect(_state(tester).linkBoard.locked, isEmpty);
      expect(_buzzes, [25]);
      await tester.pump(const Duration(milliseconds: 200));
      final box = tester.widget<AnimatedContainer>(_card(true, 0)).decoration as BoxDecoration;
      expect((box.border as Border).top.color, linkWrongColor);
      await tester.pump(const Duration(milliseconds: 750));
      expect(_state(tester).wrongLine, isNotNull, reason: 'still red just before 1 s');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_state(tester).wrongLine, isNull, reason: 'gone after 1 s');
      expect(_state(tester).linkBoard.locked, isEmpty);

      // Right lines (dragged from either side) lock in, in their own colour.
      await _drag(tester, _card(true, 2), _card(false, slotOf(2)));
      expect(_state(tester).linkBoard.locked, {2: slotOf(2)});
      expect(_buzzes, [25, 70]);
      final c0 = Color.lerp(linkPairColors[0], Colors.black, 0.3);
      expect(_textColor(tester, true, 2), c0);
      expect(_textColor(tester, false, slotOf(2)), c0);
      expect(find.byKey(const ValueKey('link_progress')), findsNothing, reason: 'no pair counter');
      // A locked line stays put: dragging from it again does nothing.
      await _drag(tester, _card(true, 2), _card(false, slotOf(3)));
      expect(_state(tester).linkBoard.locked.length, 1);
      expect(_state(tester).wrongLine, isNull);

      await _drag(tester, _card(false, slotOf(5)), _card(true, 5)); // right → left
      expect(_state(tester).linkBoard.locked[5], slotOf(5));
      // Tap-tap works too.
      await tester.tap(_card(true, 1));
      await tester.pump();
      await tester.tap(_card(false, slotOf(1)));
      await tester.pump();
      expect(_state(tester).linkBoard.locked[1], slotOf(1));
      await _drag(tester, _card(true, 3), _card(false, slotOf(3)));
      await _drag(tester, _card(true, 4), _card(false, slotOf(4)));
      expect(_state(tester).linkBoard.locked.length, 5);
      expect(_confettiPlaying(tester), isFalse, reason: 'no confetti before 6/6');
      expect(appState.sessionWins[GameEngine.linkUpGame] ?? 0, winsBefore);
      expect(_state(tester).streakCount, 0);

      await _drag(tester, _card(true, 0), _card(false, slotOf(0)));
      expect(_state(tester).linkBoard.complete, isTrue);
      expect(_confettiPlaying(tester), isTrue, reason: 'confetti at 6/6');
      expect(_state(tester).streakCount, 1);
      expect(appState.sessionWins[GameEngine.linkUpGame], winsBefore + 1, reason: 'one win');
      expect(appState.wonWords, containsAll(_six.map((w) => w.sectionName)));

      // Next board; a wrong line breaks the streak like any wrong answer.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      final r2 = _state(tester).currentRound as LinkRound;
      expect(identical(r2, r), isFalse);
      expect(_state(tester).linkBoard.locked, isEmpty);
      await _drag(tester, _card(true, 0), _card(false, (r2.rightOrder.indexOf(0) + 1) % 6));
      expect(_state(tester).streakCount, 0);
      expect(tester.takeException(), isNull);
      await _done(tester);
    });

    testWidgets('no buzz with Vibration off', (tester) async {
      await _setUp(tester);
      appState.engine = GameEngine(_six, random: Random(4));
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: GameEngine.linkUpGame),
        ),
      );
      await tester.pump();
      final r = _state(tester).currentRound as LinkRound;
      final slot = r.rightOrder.indexOf(0);
      await _drag(tester, _card(true, 0), _card(false, (slot + 1) % 6));
      expect(_state(tester).wrongLine, isNotNull);
      await _drag(tester, _card(true, 0), _card(false, slot));
      expect(_state(tester).linkBoard.locked, {0: slot});
      expect(_buzzes, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await _done(tester);
    });

    testWidgets('fewer than 6 usable words: a friendly message, no board', (tester) async {
      await _setUp(tester);
      appState.engine = GameEngine(_six.take(5).toList(), random: Random(1));
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: GameEngine.linkUpGame),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('link_board')), findsNothing);
      expect(find.textContaining('You need at least 6 words'), findsOneWidget);
      await _done(tester);
    });
  });

  group('stats', () {
    testWidgets('a board is one win; each pack counts once; all 6 words won', (tester) async {
      await _setUp(tester);
      final e = GameEngine(appState.activeVocab(), random: Random(9));
      final words = e.linkWords(appState.activeVocab());
      expect(words.length, 6);
      final packs = {for (final w in words) ...appState.packsOfWord(w)};
      final before = {for (final p in packs) p: appState.packSessionWins[p] ?? 0};
      final today = dayKey(DateTime.now());
      final dayBefore = appState.winsOnDay(today);
      await appState.recordWin(GameEngine.linkUpGame, words: words);
      expect(appState.winsOnDay(today), dayBefore + 1);
      for (final p in packs) {
        expect(appState.packSessionWins[p], before[p]! + 1, reason: p);
      }
      expect(appState.wonWords, containsAll(words.map((w) => w.sectionName)));
    });

    test('🔟 tile info', () {
      expect(GameEngine.gameCount, 11);
      final info = gameInfos[GameEngine.linkUpGame - 1];
      expect(info.keycap, '🔟', reason: 'internal only');
      expect(info.tileName, '🔗 Link Up');
      expect(info.emoji, '🔗');
      expect(info.subtitle, 'Link Up');
      final others = [...gameInfos.where((g) => g != info).map((g) => g.color), shuffleInfo.color];
      expect(others, isNot(contains(info.color)), reason: 'its own colour');
    });
  });
}
