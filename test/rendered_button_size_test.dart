import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en, [String emoji = '']) =>
    VocabEntry(sectionName: '$ko|$en', packId: 't', korean1: ko, english1: en, emoji: emoji);

final _words = [
  _w('사과', 'Apple', '🍎'),
  _w('개', 'Dog', '🐶'),
  _w('물', 'Water', '💧'),
  _w('집', 'House', '🏠'),
  _w('책', 'Book', '📚'),
  _w('달', 'Moon', '🌙'),
  _w('고양이', 'Cat', '🐱'),
  _w('빨간색', 'Red', '🔴'),
];

/// Every Text drawn on screen is no taller than its own font allows: nothing
/// is blown up by a FittedBox (rendered height ≤ fontSize × 1.6).
void _noUpscaledText(WidgetTester tester, String why) {
  // The ✍️ voice-to-text tip is a paragraph, not button text.
  final tip = find.descendant(of: find.byKey(const ValueKey('typing_tip')), matching: find.byType(Text));
  final tipTexts = tip.evaluate().toSet();
  for (final e in find.byType(Text).evaluate().where((e) => !tipTexts.contains(e))) {
    final t = e.widget as Text;
    final fs = t.style?.fontSize ?? DefaultTextStyle.of(e).style.fontSize ?? 14;
    final rendered = tester.getRect(find.byWidget(t).first).height;
    final natural = (e.renderObject as RenderBox).size.height;
    expect(rendered, lessThanOrEqualTo(natural + 0.5), reason: '$why: "${t.data}" scaled up');
    expect(natural, lessThanOrEqualTo(fs * 1.6 * 3 + 1), reason: '$why: "${t.data}"');
  }
}

void main() {
  for (final size in const [Size(412, 915), Size(360, 640), Size(320, 640)]) {
    testWidgets('no button text renders above its size at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final step in [0, 1, 2, 3]) {
        SharedPreferences.setMockInitialValues({
          AppState.kVibration: false,
          AppState.kButtonFont: step,
        });
        await tester.runAsync(appState.load);
        for (var g = 1; g <= GameEngine.gameCount; g++) {
          appState.engine = GameEngine(_words, random: Random(g));
          await tester.pumpWidget(
            MaterialApp(
              home: GameScreen(key: UniqueKey(), game: g),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          _noUpscaledText(tester, 'game $g step $step');
          if (g == GameEngine.timeGame) {
            final want = AppState.buttonFontSizes[step];
            final tile = find.descendant(
              of: find.byKey(const ValueKey('tile_0')),
              matching: find.byType(Text),
            );
            // Glyph line height at the chosen size, tile not stretched.
            expect(tester.getRect(tile).height, lessThanOrEqualTo(want * 1.6));
            expect(tester.getRect(tile).height, greaterThan(want * 0.8));
            expect(
              tester.getSize(find.byKey(const ValueKey('tile_0'))).height,
              lessThanOrEqualTo(want * 1.6 + 30),
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
