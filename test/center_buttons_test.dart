import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameEngine _engine(int seed) => GameEngine(appState.activeVocab(), random: Random(seed))
  ..useEmoji = appState.useEmoji
  ..showBracketNotes = appState.showBracketNotes;

void main() {
  for (final game in [1, 2, 9]) {
    testWidgets('$game: answer text is centred on its button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      await tester.runAsync(appState.load);
      // 9️⃣: a round with Korean name buttons (not colour buttons).
      var seed = 0;
      while (game == 9 && !(_engine(seed).newRound(9) as ColorRound).colorInBox) {
        seed++;
      }
      appState.engine = _engine(seed);
      await tester.pumpWidget(MaterialApp(home: GameScreen(game: _legacy(game))));
      await tester.pump();

      final buttons = find.byType(BouncyButton);
      final texts = <String>[];
      for (final b in buttons.evaluate()) {
        final t = find.descendant(of: find.byWidget(b.widget), matching: find.byType(Text));
        for (final e in t.evaluate()) {
          final w = e.widget as Text;
          final r = e.renderObject! as RenderBox;
          // The invisible sizing 'A' in 1️⃣ is skipped.
          if (w.data == null || w.data == 'A' || !r.hasSize) continue;
          final box = tester.getRect(find.byWidget(b.widget));
          if (box.width < 200) continue; // ➡️ / ↩️ controls
          texts.add(w.data!);
          expect(w.textAlign, TextAlign.center, reason: w.data);
          expect(
            tester.getCenter(find.byWidget(w)).dx,
            moreOrLessEquals(box.center.dx, epsilon: 1),
            reason: w.data,
          );
        }
      }
      expect(texts.length, 3, reason: '$texts');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}

/// Old 2️⃣ 🎯 Pick the Korean is 1️⃣ in its Korean-answer format now.
int _legacy(int game) {
  GameEngine.pickKoreanFormat = game == 2 ? true : null;
  addTearDown(() => GameEngine.pickKoreanFormat = null);
  return game == 2 ? 1 : game;
}
