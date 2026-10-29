import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/color_game.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/emoji_peek.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

dynamic _state(WidgetTester tester) => tester.state(find.byType(GameScreen));

Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
  });
  await tester.runAsync(appState.load);
}

Future<void> _tapOption(WidgetTester tester, ColorRound r, {required bool right}) async {
  final i = r.options.indexWhere((c) => (c.id == r.target.id) == right);
  await tester.tap(find.byKey(ValueKey('color_option_$i')));
  await tester.pump();
}

/// Plays right answers until the round is a colour-box round.
Future<ColorRound> _boxRound(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    final r = _state(tester).currentRound as ColorRound;
    if (r.colorInBox) return r;
    final right = r.options.indexWhere((c) => c.id == r.target.id);
    await tester.tap(find.byKey(ValueKey('color_option_$right')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  fail('no colour-box round');
}

void main() {
  test('every colour has its English name', () {
    expect(gameColors.map((c) => c.english).toList(), [
      'Red',
      'Orange',
      'Yellow',
      'Green',
      'Teal',
      'Blue',
      'Purple',
      'Pink',
      'Brown',
      'White',
      'Gray',
      'Black',
    ]);
  });

  test('the peek text colour is readable on every colour (WCAG AA, ≥ 4.5:1)', () {
    for (final c in gameColors) {
      final text = c.wantsDarkText ? Colors.black : Colors.white;
      expect(_contrast(Color(c.argb), text), greaterThanOrEqualTo(4.5), reason: c.id);
    }
    bool dark(String id) => gameColors.firstWhere((c) => c.id == id).wantsDarkText;
    expect(dark('white'), isTrue);
    expect(dark('yellow'), isTrue);
    expect(dark('black'), isFalse);
    expect(dark('blue'), isFalse);
    expect(dark('purple'), isFalse);
  });

  for (final notes in [false, true]) {
    testWidgets('tap the colour box: English flips on, tap again: off (bracket notes $notes)', (
      tester,
    ) async {
      await _setUp(tester);
      await appState.setShowBracketNotes(notes);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
      await tester.pump();
      final r = await _boxRound(tester);
      final english = appState.displayEnglish(r.target.english);
      final streak = _state(tester).streakCount as int;
      final wins = appState.sessionWins[9];
      expect(find.text(english), findsNothing);
      expect(_state(tester).peeking, isFalse);

      await tester.tap(find.byKey(const ValueKey('color_box')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(_state(tester).peeking, isTrue);
      expect(find.byKey(const ValueKey('color_box_english')), findsOneWidget);
      expect(find.text(english), findsOneWidget);
      final style = tester.widget<Text>(find.text(english)).style!;
      expect(
        _contrast(Color(r.target.argb), style.color!),
        greaterThanOrEqualTo(4.5),
        reason: 'readable on ${r.target.id}',
      );
      // A peek is not an answer.
      expect(identical(_state(tester).currentRound, r), isTrue);
      expect(_state(tester).streakCount, streak);
      expect(appState.sessionWins[9], wins);

      await tester.tap(find.byKey(const ValueKey('color_box')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(_state(tester).peeking, isFalse);
      expect(find.text(english), findsNothing);
      expect(find.byKey(const ValueKey('color_box_english')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('answers still work while peeking, and the next round starts hidden', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
    await tester.pump();
    var r = await _boxRound(tester);
    await tester.tap(find.byKey(const ValueKey('color_box')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(_state(tester).peeking, isTrue);
    final streak = _state(tester).streakCount as int;
    final wins = appState.sessionWins[9]!;
    await _tapOption(tester, r, right: true);
    expect(_state(tester).streakCount, streak + 1);
    expect(appState.sessionWins[9], wins + 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(identical(_state(tester).currentRound, r), isFalse);
    expect(_state(tester).peeking, isFalse, reason: 'every round starts on the colour');
    expect(find.byKey(const ValueKey('color_box_english')), findsNothing);

    // A wrong answer while peeking still resets the streak.
    r = await _boxRound(tester);
    await tester.tap(find.byKey(const ValueKey('color_box')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await _tapOption(tester, r, right: false);
    expect(_state(tester).streakCount, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('colour answer buttons are answers, not peeks', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      final r = _state(tester).currentRound as ColorRound;
      if (!r.colorInBox) {
        expect(find.byKey(const ValueKey('color_box')), findsNothing);
        final wins = appState.sessionWins[9]!;
        await _tapOption(tester, r, right: true);
        expect(_state(tester).peeking, isFalse);
        expect(appState.sessionWins[9], wins + 1);
        for (final c in gameColors) {
          expect(find.text(c.english), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        return;
      }
      await _tapOption(tester, r, right: true);
      await tester.pump(const Duration(milliseconds: 400));
    }
    fail('no colour-button round');
  });

  testWidgets('ColorPeek keeps the box look and shows the given English', (tester) async {
    var taps = 0;
    Widget box(bool show, String english) => MaterialApp(
      home: Scaffold(
        body: ColorPeek(
          color: const Color(0xFFFFFFFF),
          english: english,
          darkText: true,
          outlined: true,
          showEnglish: show,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpWidget(box(false, 'White'));
    final c = tester.widget<Container>(find.byKey(const ValueKey('color_box')));
    final d = c.decoration! as BoxDecoration;
    expect(d.color, const Color(0xFFFFFFFF));
    expect(d.border, isNotNull, reason: 'light colours keep their outline');
    expect(d.borderRadius, BorderRadius.circular(28));
    expect(tester.getSize(find.byKey(const ValueKey('color_box'))).height, 150 + 34 + 8);
    expect(find.text('White'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('color_box')));
    expect(taps, 1);
    await tester.pumpWidget(box(true, 'White'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('White'), findsOneWidget);
    expect(tester.widget<Text>(find.text('White')).style!.color, Colors.black);
    expect(tester.getSize(find.byKey(const ValueKey('color_box'))).height, 150 + 34 + 8);
  });
}
