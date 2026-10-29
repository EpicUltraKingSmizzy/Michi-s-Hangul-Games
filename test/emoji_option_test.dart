import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Dart supports this property at runtime; the analyzer's checker does not.
// ignore: valid_regexps
final _emoji = RegExp(r'\p{Extended_Pictographic}', unicode: true);

List<VocabEntry> _builtIn() => parseIni(File('assets/korean_vocab.ini').readAsStringSync());

List<String> _shown(Object r) => switch (r) {
  ChoiceRound c => [c.prompt, ...c.options],
  TypingRound t => [t.prompt],
  _ => const [],
};

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

Future<void> _setUp(
  WidgetTester tester, {
  bool emoji = true,
  Size size = const Size(1080, 2400),
  double dpr = 2.5,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    AppState.kUseEmoji: emoji,
  });
  await tester.runAsync(appState.load);
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  group('data', () {
    test('every built-in word has real English (no emoji-only or empty English1)', () {
      final words = _builtIn();
      expect(words.length, greaterThan(500));
      final bad = words.where((e) => !GameEngine.hasPlainEnglish(e) || _emoji.hasMatch(e.english1));
      expect(bad.map((e) => '${e.korean1}=${e.english1}'), isEmpty);
    });

    test('words fixed in t39u keep their emoji and gain English', () {
      final byKo = {for (final e in _builtIn()) e.korean1: e};
      expect(byKo['모자']!.english1, 'Hat');
      expect(byKo['모자']!.emoji, '🎩');
      expect(byKo['생쥐']!.english1, 'Mouse (animal)');
      expect(byKo['아내']!.english1, 'Wife');
      expect(byKo['아내']!.emoji, '⚭🧍‍♀️');
    });
  });

  group('engine with emojis off', () {
    test('no word emoji in any prompt or answer of 1️⃣–8️⃣', () {
      final engine = GameEngine(_builtIn(), random: Random(5))..useEmoji = false;
      for (var game = 1; game <= 8; game++) {
        for (var i = 0; i < 300; i++) {
          final r = legacyRound(engine, game);
          for (final s in _shown(r)) {
            expect(_emoji.hasMatch(s), isFalse, reason: 'game $game: "$s"');
          }
          if (r is ChoiceRound) expect(r.promptEnglish, '');
          if (r is TypingRound) {
            expect(r.promptEnglish, '');
            expect(_emoji.hasMatch(r.answer2), isFalse);
          }
        }
      }
    });

    test('emoji-only English words sit out; with emojis on they play', () {
      const words = [
        VocabEntry(sectionName: 'a', english1: 'Apple', emoji: '🍎', korean1: '사과'),
        VocabEntry(sectionName: 'b', english1: 'Pear', emoji: '🍐', korean1: '배'),
        VocabEntry(sectionName: 'c', english1: 'Grapes', korean1: '포도'),
        VocabEntry(sectionName: 'd', english1: '🍋', korean1: '레몬'),
        VocabEntry(sectionName: 'e', english1: '', emoji: '🍉', korean1: '수박'),
      ];
      final engine = GameEngine(words, random: Random(1));
      expect(engine.playList.length, 5);
      engine.useEmoji = false;
      expect(engine.playList.map((e) => e.sectionName), ['a', 'b', 'c']);
      expect(engine.canPlay(2), isTrue);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final r = legacyRound(engine, 2) as ChoiceRound;
        seen.add(r.prompt);
        expect(r.options, isNot(contains('레몬')));
        expect(r.options, isNot(contains('수박')));
      }
      expect(seen, {'Apple', 'Pear', 'Grapes'});
      engine.useEmoji = true;
      final onPrompts = {
        for (var i = 0; i < 200; i++) (legacyRound(engine, 2) as ChoiceRound).prompt,
      };
      expect(onPrompts, containsAll(['🍎', '🍐', '🍋', '🍉']));
    });

    test('1️⃣ never shows two identical-looking English answers', () {
      const words = [
        VocabEntry(sectionName: 'a', english1: 'Orange', emoji: '🍊', korean1: '오렌지'),
        VocabEntry(sectionName: 'b', english1: 'orange', emoji: '🟧', korean1: '주황색'),
        VocabEntry(sectionName: 'c', english1: 'Cat', emoji: '🐱', korean1: '고양이'),
        VocabEntry(sectionName: 'd', english1: 'Dog', emoji: '🐶', korean1: '개'),
        VocabEntry(sectionName: 'e', english1: 'Cow', emoji: '🐮', korean1: '소'),
      ];
      final engine = GameEngine(words, random: Random(9))..useEmoji = false;
      for (var i = 0; i < 300; i++) {
        final r = engine.newRound(1) as ChoiceRound;
        final keys = r.options.map((o) => o.replaceAll(' ', '').toLowerCase()).toSet();
        expect(keys.length, r.options.length, reason: '${r.options}');
      }
      // The whole built-in list too (1 = 일 / 하나 etc.).
      final all = GameEngine(_builtIn(), random: Random(2))..useEmoji = false;
      for (var i = 0; i < 1500; i++) {
        final r = all.newRound(1) as ChoiceRound;
        final keys = r.options.map((o) => o.replaceAll(' ', '').toLowerCase()).toSet();
        expect(keys.length, r.options.length, reason: '${r.options}');
      }
      expect(
        GameEngine.entriesClash(words[0], words[1]),
        isFalse,
        reason: 'different emojis look different',
      );
      expect(GameEngine.entriesClash(words[0], words[1], useEmoji: false), isTrue);
    });
  });

  testWidgets('⚙️ 😀 Emoji option: on by default, saved, switches the engine', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(appState.load);
    expect(appState.useEmoji, isTrue);
    expect(appState.engine.useEmoji, isTrue);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    final card = find.byKey(const ValueKey('opt_use_emoji'));
    expect(card, findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('😀'), findsOneWidget);
    // Right under 🔊 Spoken Answer.
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('opt_spoken_answer'))).dy),
    );
    await tester.tap(find.descendant(of: card, matching: find.byType(Switch)));
    await tester.pump();
    expect(appState.useEmoji, isFalse);
    expect(appState.engine.useEmoji, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppState.kUseEmoji), isFalse);
    await tester.runAsync(appState.load);
    expect(appState.useEmoji, isFalse, reason: 'saved');
    expect(appState.engine.useEmoji, isFalse);
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('2️⃣–6️⃣ with emojis off: English prompt, no peek, UI emojis stay', (tester) async {
    await _setUp(tester, emoji: false);
    for (final game in [2, 3, 4, 5, 6]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: _legacy(game)),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        final r = _state(tester).currentRound;
        final prompt = r is ChoiceRound ? r.prompt : (r as TypingRound).prompt;
        expect(_emoji.hasMatch(prompt), isFalse, reason: 'game $game: $prompt');
        expect(find.byKey(const ValueKey('prompt_peek')), findsNothing);
        expect(find.byKey(const ValueKey('prompt_text')), findsOneWidget);
        expect(find.text('➡️'), findsOneWidget, reason: 'UI emojis unaffected');
        await tester.tap(find.text('➡️'));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await _done(tester);
    }
  });

  testWidgets('1️⃣ with emojis off: English buttons fit at 360px, same height as emoji ones', (
    tester,
  ) async {
    const words = [
      VocabEntry(sectionName: 'a', english1: 'Apple', emoji: '🍎', korean1: '사과'),
      VocabEntry(sectionName: 'b', english1: 'Red Pepper Paste', emoji: '🌶️🧴', korean1: '고추장'),
      VocabEntry(
        sectionName: 'c',
        english1: 'I would like to order a large coffee please',
        emoji: '☕',
        korean1: '커피',
      ),
    ];
    Future<List<double>> heights(bool emoji) async {
      await _setUp(tester, emoji: emoji, size: const Size(360 * 3, 760 * 3), dpr: 3);
      appState.engine = GameEngine(words, random: Random(3))..useEmoji = emoji;
      GameEngine.pickKoreanFormat = false; // Korean prompt, English buttons
      addTearDown(() => GameEngine.pickKoreanFormat = null);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      final r = _state(tester).currentRound as ChoiceRound;
      for (final o in r.options) {
        expect(_emoji.hasMatch(o), emoji, reason: o);
      }
      expect(tester.takeException(), isNull);
      final hs = [
        for (var i = 0; i < 3; i++)
          tester
              .getSize(
                find.ancestor(
                  of: find.byKey(ValueKey('option_text_$i')),
                  matching: find.byType(BouncyButton),
                ),
              )
              .height,
      ];
      for (var i = 0; i < 3; i++) {
        final t = tester.getRect(find.byKey(ValueKey('option_text_$i')));
        expect(t.right, lessThanOrEqualTo(360));
      }
      await _done(tester);
      return hs;
    }

    final off = await heights(false);
    expect(off.toSet().length, 1, reason: 'all English buttons the same height: $off');
    final on = await heights(true);
    expect(off.first, closeTo(on.first, 1.0), reason: 'same size as the emoji buttons');
  });

  testWidgets('🏠 Korean title is 미시의 한글 게임 and fits one line at 360 and 412', (tester) async {
    for (final w in [360.0, 412.0]) {
      await _setUp(tester, size: Size(w * 3, 800 * 3), dpr: 3);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.text('미시의 한글 게임'), findsOneWidget);
      expect(find.text('미시 교시 게임'), findsNothing);
      final title = tester.widget<Text>(find.byKey(const ValueKey('title_ko')));
      expect(title.style!.fontSize, 38);
      final rect = tester.getRect(find.byKey(const ValueKey('title_ko')));
      expect(rect.right, lessThanOrEqualTo(w));
      expect(tester.takeException(), isNull);
      await _done(tester);
    }
  });
}

/// Old 2️⃣ 🎯 Pick the Korean is 1️⃣ in its Korean-answer format now.
int _legacy(int game) {
  GameEngine.pickKoreanFormat = game == 2 ? true : null;
  addTearDown(() => GameEngine.pickKoreanFormat = null);
  return game == 2 ? 1 : game;
}
