import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en, [String emoji = '']) => VocabEntry(
  sectionName: '$ko|$en',
  packId: 'test',
  korean1: ko,
  english1: en,
  emoji: emoji,
  isFullPhrase: false,
);

final _words = [
  _w('사과', 'Apple', '🍎'),
  _w('개', 'Dog', '🐶'),
  _w('물', 'Water', '💧'),
  _w('집', 'House', '🏠'),
  _w('책', 'Book', '📚'),
  _w('달', 'Moon', '🌙'),
  _w('냉장고', 'Refrigerator', '🧊'),
  _w('텔레비전', 'Television', '📺'),
  _w('빨간색', 'Red', '🔴'),
  _w('파란색', 'Blue', '🔵'),
];

Future<void> _setUp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  double w = 1080,
}) async {
  tester.view.physicalSize = Size(w, 2400);
  tester.view.devicePixelRatio = w == 1080 ? 2.5 : 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({AppState.kVibration: false, ...prefs});
  await tester.runAsync(appState.load);
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

double? _size(WidgetTester t, Finder f) => t.widget<Text>(f).style?.fontSize;

void main() {
  test('sizes sit between 🔍 (24) and 🕒 (28) at Medium', () {
    expect(AppState.buttonFontSizes, [22.0, 26.0, 30.0, 36.0]);
    expect(AppState.buttonFontLabels, ['Small', 'Medium', 'Large', 'Huge']);
  });

  testWidgets('defaults to Large and persists', (tester) async {
    await _setUp(tester);
    expect(appState.buttonFont, 2);
    expect(appState.buttonFontSize, 30);
    await tester.runAsync(() => appState.setButtonFont(3));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppState.kButtonFont), 3);
    await tester.runAsync(appState.load);
    expect(appState.buttonFontSize, 36);
    await tester.runAsync(() => appState.setButtonFont(9));
    expect(appState.buttonFont, 3);
  });

  testWidgets('saved choices keep their meaning', (tester) async {
    for (final (i, size) in [(0, 22.0), (1, 26.0), (2, 30.0), (3, 36.0)]) {
      await _setUp(tester, prefs: {AppState.kButtonFont: i});
      expect(appState.buttonFontSize, size);
    }
  });

  testWidgets('options slider sits right above Shuffle games', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('opt_shuffle_games')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('opt_button_font')),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Button Font Size'), findsOneWidget);
    expect(find.text('🔠'), findsOneWidget);
    final slider = tester.getRect(find.byKey(const ValueKey('opt_button_font')));
    final shuffle = tester.getRect(find.byKey(const ValueKey('opt_shuffle_games')));
    // Directly above: nothing fits in the gap between the two cards.
    expect(shuffle.top - slider.bottom, inInclusiveRange(0, 30));
    expect(find.text('Huge'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    final s = find.byKey(const ValueKey('opt_button_font_slider'));
    await tester.tapAt(tester.getTopRight(s) - const Offset(30, -20));
    await tester.pump();
    expect(appState.buttonFont, 3);
    expect(find.text('H'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('size applies to 🔍 and 🕒 buttons', (tester) async {
    for (final step in [0, 1, 2, 3]) {
      await _setUp(tester, prefs: {AppState.kButtonFont: step});
      final want = AppState.buttonFontSizes[step];

      GameEngine.pickKoreanFormat = true;
      appState.engine = GameEngine(_words, random: Random(1));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      final opt = find.byKey(const ValueKey('option_text_0'));
      expect(opt, findsOneWidget);
      expect(_size(tester, find.descendant(of: opt, matching: find.byType(Text))), want);
      GameEngine.pickKoreanFormat = null;

      appState.engine = GameEngine(_words, random: Random(1));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      final tile = find.descendant(
        of: find.byKey(const ValueKey('tile_0')),
        matching: find.byType(Text),
      );
      expect(_size(tester, tile.first), want);
      expect(
        _size(
          tester,
          find.descendant(
            of: find.byKey(const ValueKey('tile_backspace')),
            matching: find.byType(Text),
          ),
        ),
        want,
      );
      await _done(tester);
    }
  });

  testWidgets('Huge fits at 320dp in every game', (tester) async {
    await _setUp(tester, prefs: {AppState.kButtonFont: 3}, w: 320);
    for (var g = 1; g <= GameEngine.gameCount; g++) {
      for (final seed in [1, 2, 3]) {
        appState.engine = GameEngine(_words, random: Random(seed));
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: g),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'game $g seed $seed');
      }
    }
    await _done(tester);
  });
}
