import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared 🧩/🌀 home tile: a tap pops both bubbles, fully on screen and
/// tappable, and each opens its game (phone sizes, big system font, and the
/// shrunk-to-fit home page).
void main() {
  const cases = [
    (Size(1080, 2400), 2.75, 1.0),
    (Size(1080, 2340), 2.75, 1.3),
    (Size(1080, 2400), 2.75, 1.6),
    (Size(720, 1280), 2.75, 1.0),
    (Size(1440, 3200), 3.5, 1.0),
  ];
  for (final (size, dpr, text) in cases) {
    for (final game in [5, 6]) {
      testWidgets('$size ×$dpr text $text: 🧩 tile → bubbles → game $game', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        tester.platformDispatcher.textScaleFactorTestValue = text;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({AppState.kVibration: false});
        await tester.runAsync(appState.load);
        await tester.pumpWidget(const HangulHoorayApp());
        await tester.pump();

        Future<void> settle() async {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        expect(find.byKey(const ValueKey('bubble_5')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tile_5')));
        await settle();
        final screen = Offset.zero & (size / dpr);
        for (final g in [5, 6]) {
          final b = find.byKey(ValueKey('bubble_$g'));
          expect(b, findsOneWidget);
          final r = tester.getRect(b);
          expect(
            screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
            reason: 'bubble $g at $r is off screen $screen',
          );
          // The bubble itself is what a tap at its centre hits.
          final hit = tester.hitTestOnBinding(r.center);
          final bubbleBox = tester.renderObject(b);
          expect(
            hit.path.any((e) => e.target == bubbleBox),
            isTrue,
            reason: 'bubble $g not hittable',
          );
        }
        expect(find.text('🧩 Syllable scramble'), findsOneWidget);
        expect(find.text('🌀 Scramble + decoys'), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);

        await tester.tap(find.byKey(ValueKey('bubble_$game')));
        await settle();
        expect(find.byType(GameScreen), findsOneWidget);
        expect((tester.state(find.byType(GameScreen)) as dynamic).currentGame, game);
        expect(find.byKey(const ValueKey('bubble_5')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}
