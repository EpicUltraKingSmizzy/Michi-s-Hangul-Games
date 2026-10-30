import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en, String emoji) =>
    VocabEntry(sectionName: '$ko|$en', packId: 'test', korean1: ko, english1: en, emoji: emoji);

final _six = [
  _w('사과', 'Apple', '🍎'),
  _w('개', 'Dog', '🐶'),
  _w('물', 'Water', '💧'),
  _w('집', 'House', '🏠'),
  _w('책', 'Book', '📚'),
  _w('달', 'Moon', '🌙'),
];
const _emojis = ['🍎', '🐶', '💧', '🏠', '📚', '🌙'];
const _english = ['Apple', 'Dog', 'Water', 'House', 'Book', 'Moon'];

final _toggle = find.byKey(const ValueKey('link_emoji_toggle'));

Future<void> _open(WidgetTester tester, {required bool emoji}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    AppState.kUseEmoji: emoji,
  });
  await tester.runAsync(appState.load);
  appState.engine = GameEngine(_six, random: Random(5))..useEmoji = emoji;
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(key: UniqueKey(), game: GameEngine.linkUpGame),
    ),
  );
  await tester.pump();
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

int _shown(List<String> texts) => texts.where((t) => find.text(t).evaluate().isNotEmpty).length;

void main() {
  testWidgets('🔗 😐 / 😶‍🌫️ swaps emojis for English and resets each board', (tester) async {
    await _open(tester, emoji: true);
    expect(_toggle, findsOneWidget);
    expect(find.descendant(of: _toggle, matching: find.text('😐')), findsOneWidget);
    expect(_shown(_emojis), 6);
    expect(_shown(_english), 0);

    await tester.tap(_toggle);
    await tester.pump();
    expect(find.descendant(of: _toggle, matching: find.text('😶‍🌫️')), findsOneWidget);
    expect(_shown(_emojis), 0);
    expect(_shown(_english), 6);

    await tester.tap(_toggle);
    await tester.pump();
    expect(find.descendant(of: _toggle, matching: find.text('😐')), findsOneWidget);
    expect(_shown(_emojis), 6);

    // Hide again, then a new board (➡️) starts back at 😐 with emojis.
    await tester.tap(_toggle);
    await tester.pump();
    await tester.tap(find.text('➡️'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.descendant(of: _toggle, matching: find.text('😐')), findsOneWidget);
    expect(_shown(_emojis), 6);
    expect(_shown(_english), 0);
    await _done(tester);
  });

  testWidgets('🔗 no 😐 button with the Emoji option off', (tester) async {
    await _open(tester, emoji: false);
    expect(_toggle, findsNothing);
    expect(find.text('😐'), findsNothing);
    expect(_shown(_english), 6);
    await _done(tester);
  });
}
