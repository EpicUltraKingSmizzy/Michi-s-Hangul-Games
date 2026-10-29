import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/emoji_peek.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apple = VocabEntry(sectionName: 'a', english1: 'Apple', emoji: '🍎', korean1: '사과');
const _plain = VocabEntry(sectionName: 'b', english1: 'Hello', korean1: '안녕하세요');
const _same = VocabEntry(sectionName: 'c', english1: '🐶', emoji: '🐶', korean1: '개');

const _fruit = [
  _apple,
  VocabEntry(sectionName: 'd', english1: 'Banana', emoji: '🍌', korean1: '바나나'),
  VocabEntry(sectionName: 'e', english1: 'Grapes', emoji: '🍇', korean1: '포도'),
  VocabEntry(sectionName: 'f', english1: 'Strawberry', emoji: '🍓', korean1: '딸기'),
  VocabEntry(sectionName: 'g', english1: 'Watermelon', emoji: '🍉', korean1: '수박'),
];

String _peekOf(Object? r) =>
    r is ChoiceRound ? r.promptEnglish : (r is TypingRound ? r.promptEnglish : '');
String _promptOf(Object r) => r is ChoiceRound ? r.prompt : (r as TypingRound).prompt;

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

Future<void> _setUp(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  double dpr = 2.5,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
  });
  await tester.runAsync(appState.load);
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

/// Skips until the round has an emoji with an English word behind it.
Future<void> _toPeekable(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    final r = _state(tester).currentRound;
    if (_peekOf(r).isNotEmpty) return;
    await tester.tap(find.text('➡️'));
    await tester.pump();
  }
  fail('no emoji round found');
}

void main() {
  group('engine', () {
    test('peekEnglish: English behind an emoji, else empty', () {
      expect(GameEngine.peekEnglish(_apple), 'Apple');
      expect(GameEngine.peekEnglish(_plain), '', reason: 'prompt is already English');
      expect(GameEngine.peekEnglish(_same), '', reason: 'English is just the emoji');
      expect(GameEngine.peekEnglish(const VocabEntry(emoji: '🍎', english1: '  ')), '');
    });

    test('2️⃣–6️⃣ carry the English for emoji prompts; 1️⃣ 7️⃣ 8️⃣ never do', () {
      final words = [
        for (var i = 0; i < 6; i++)
          VocabEntry(
            sectionName: 's$i',
            english1: 'Word $i',
            emoji: i.isEven ? '🍎' : '',
            korean1: '사과$i',
          ),
      ];
      final engine = GameEngine(words, random: Random(4));
      for (final game in [2, 3, 4, 5, 6]) {
        var withEmoji = 0, without = 0;
        for (var i = 0; i < 120; i++) {
          final r = legacyRound(engine, game);
          final prompt = _promptOf(r);
          if (prompt == '🍎') {
            expect(_peekOf(r), startsWith('Word '), reason: 'game $game');
            withEmoji++;
          } else {
            expect(_peekOf(r), '', reason: 'game $game, prompt "$prompt"');
            without++;
          }
        }
        expect(withEmoji, greaterThan(0), reason: 'game $game');
        expect(without, greaterThan(0), reason: 'game $game');
      }
      for (final game in [1, 7, 8]) {
        for (var i = 0; i < 60; i++) {
          final r = legacyRound(engine, game);
          expect(_peekOf(r), '', reason: 'game $game');
        }
      }
    });

    test('fitFontSize shrinks long words to the width', () {
      const style = TextStyle(fontWeight: FontWeight.w900);
      expect(fitFontSize('Cat', style, 280, base: 60), 60);
      final s = fitFontSize('Supercalifragilisticexpialidocious', style, 220, base: 24);
      expect(s, lessThan(24));
    });
  });

  testWidgets('2️⃣: tap flips emoji → English → emoji; streak untouched; new round resets', (
    tester,
  ) async {
    await _setUp(tester);
    appState.engine = GameEngine(_fruit, random: Random(2));
    GameEngine.pickKoreanFormat = true; // old 2️⃣: 1️⃣ in its pick-the-Korean format
    addTearDown(() => GameEngine.pickKoreanFormat = null);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
    await tester.pump();
    final r = _state(tester).currentRound as ChoiceRound;
    expect(r.promptEnglish, isNotEmpty);
    // Build a streak of one first so we can see peeking doesn't touch it.
    await tester.tap(find.text(r.correctAnswer).last);
    await tester.pump();
    expect(_state(tester).streakCount, 1);
    await tester.pump(const Duration(seconds: 3));
    final r2 = _state(tester).currentRound as ChoiceRound;
    expect(find.byKey(const ValueKey('peek_emoji')), findsOneWidget);
    expect(find.text(r2.promptEnglish), findsNothing);

    await tester.tap(find.byKey(const ValueKey('prompt_peek')));
    await tester.pump();
    await tester.pump(EmojiPeek.duration);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_state(tester).peeking, isTrue);
    expect(find.text(r2.promptEnglish), findsOneWidget);
    expect(find.byKey(const ValueKey('peek_emoji')), findsNothing);
    expect(_state(tester).streakCount, 1, reason: 'peeking is free');
    expect(identical(_state(tester).currentRound, r2), isTrue, reason: 'same round');

    await tester.tap(find.byKey(const ValueKey('prompt_peek')));
    await tester.pump();
    await tester.pump(EmojiPeek.duration);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_state(tester).peeking, isFalse);
    expect(find.byKey(const ValueKey('peek_emoji')), findsOneWidget);
    expect(find.text(r2.promptEnglish), findsNothing);

    // Peek, then win: the next round starts on the emoji again.
    await tester.tap(find.byKey(const ValueKey('prompt_peek')));
    await tester.pump(EmojiPeek.duration);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(r2.correctAnswer).last);
    await tester.pump();
    expect(_state(tester).streakCount, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(identical(_state(tester).currentRound, r2), isFalse);
    expect(_state(tester).peeking, isFalse);
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('3️⃣–6️⃣ emoji prompts flip too; ➡️ resets to the emoji', (tester) async {
    await _setUp(tester);
    for (final game in [3, 4, 5, 6]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: _legacy(game)),
        ),
      );
      await tester.pump();
      await _toPeekable(tester);
      final r = _state(tester).currentRound as TypingRound;
      await tester.tap(find.byKey(const ValueKey('prompt_peek')));
      await tester.pump(EmojiPeek.duration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(r.promptEnglish), findsOneWidget, reason: 'game $game');
      await tester.tap(find.text('➡️'));
      await tester.pump();
      expect(_state(tester).peeking, isFalse, reason: 'game $game');
      expect(tester.takeException(), isNull);
      await _done(tester);
    }
  });

  testWidgets('🔀 Shuffle: peek works and each game change starts on the emoji', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen.shuffle(key: UniqueKey())));
    await tester.pump();
    for (var n = 0; n < 3; n++) {
      await _toPeekable(tester);
      final game = _state(tester).currentGame as int;
      expect([1, 3, 4, 5, 6], contains(game));
      await tester.tap(find.byKey(const ValueKey('prompt_peek')));
      await tester.pump(EmojiPeek.duration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_state(tester).peeking, isTrue);
      await tester.tap(find.text('➡️'));
      await tester.pump();
      expect(_state(tester).peeking, isFalse);
      if (_peekOf(_state(tester).currentRound).isNotEmpty) {
        expect(find.byKey(const ValueKey('peek_emoji')), findsOneWidget);
      }
    }
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('1️⃣ options are answers, not peeks', (tester) async {
    await _setUp(tester);
    GameEngine.pickKoreanFormat = false;
    addTearDown(() => GameEngine.pickKoreanFormat = null);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
    await tester.pump();
    expect(find.byKey(const ValueKey('prompt_peek')), findsNothing);
    await _done(tester);
  });

  testWidgets('every built-in English fits a 360px-wide phone when peeked', (tester) async {
    await _setUp(tester, size: const Size(360 * 3, 760 * 3), dpr: 3);
    final peekable = appState.builtIn.where((e) => GameEngine.peekEnglish(e).isNotEmpty).toList()
      ..sort((a, b) => b.english1.length.compareTo(a.english1.length));
    expect(peekable, isNotEmpty);
    // The longest few words, played through 2️⃣ with only them active.
    final longest = peekable.take(6).toList();
    appState.engine = GameEngine(longest, random: Random(1));
    GameEngine.pickKoreanFormat = true; // old 2️⃣: 1️⃣ in its pick-the-Korean format
    addTearDown(() => GameEngine.pickKoreanFormat = null);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
    await tester.pump();
    final seen = <String>{};
    for (var i = 0; i < 30 && seen.length < longest.length; i++) {
      final r = _state(tester).currentRound as ChoiceRound;
      await tester.tap(find.byKey(const ValueKey('prompt_peek')));
      await tester.pump(EmojiPeek.duration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: r.promptEnglish);
      final box = tester.getRect(find.byKey(const ValueKey('prompt_card')));
      final text = tester.getRect(find.byKey(const ValueKey('peek_english_text')));
      expect(text.left, greaterThanOrEqualTo(box.left), reason: r.promptEnglish);
      expect(text.right, lessThanOrEqualTo(box.right), reason: r.promptEnglish);
      expect(box.right, lessThanOrEqualTo(360));
      seen.add(r.promptEnglish);
      await tester.tap(find.text('➡️'));
      await tester.pump();
    }
    expect(seen, isNotEmpty);
    await _done(tester);
  });
}

/// Old 2️⃣ 🎯 Pick the Korean is 1️⃣ in its Korean-answer format now.
int _legacy(int game) {
  GameEngine.pickKoreanFormat = game == 2 ? true : null;
  addTearDown(() => GameEngine.pickKoreanFormat = null);
  return game == 2 ? 1 : game;
}
