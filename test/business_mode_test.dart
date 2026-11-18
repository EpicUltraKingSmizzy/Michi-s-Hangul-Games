import 'dart:math';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/widgets/app_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabEntry _w(String ko, String en, [String emoji = '']) =>
    VocabEntry(sectionName: '$ko|$en', packId: 't', korean1: ko, english1: en, emoji: emoji);

final _words = [
  _w('사과', 'Apple', '🍎'),
  _w('개', 'Dog', '🐶'),
  _w('물', 'Water', '💧'),
  _w('집', 'House', '🏠'),
];

Future<void> _load(WidgetTester tester, {bool? business}) async {
  SharedPreferences.setMockInitialValues({
    AppState.kVibration: false,
    AppState.kBusinessMode: ?business,
  });
  await tester.runAsync(appState.load);
}

/// RGBA of the pixel at [p] in [image].
Future<List<int>> _pixel(WidgetTester tester, ui.Image image, Offset p) async {
  final data = (await tester.runAsync(() => image.toByteData()))!;
  final i = (p.dy.toInt() * image.width + p.dx.toInt()) * 4;
  return [for (var k = 0; k < 4; k++) data.getUint8(i + k)];
}

void main() {
  testWidgets('💼 Business mode: off by default, saved, and loaded', (tester) async {
    await _load(tester);
    expect(appState.businessMode, isFalse);
    await tester.runAsync(() => appState.setBusinessMode(true));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppState.kBusinessMode), isTrue);
    await tester.runAsync(appState.load);
    expect(appState.businessMode, isTrue, reason: 'saved');
  });

  testWidgets('Options tile: 💼 on the left, title and "No silly colors."', (tester) async {
    await _load(tester);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    final tile = find.byKey(const ValueKey('opt_business_mode'));
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    final sw = tester.widget<SwitchListTile>(
      find.descendant(of: tile, matching: find.byType(SwitchListTile)),
    );
    expect((sw.secondary as Text).data, '💼');
    expect((sw.title as Text).data, 'Business mode');
    expect((sw.subtitle as Text).data, 'No silly colors.');
    expect(sw.value, isFalse);
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pump();
    expect(appState.businessMode, isTrue);
  });

  testWidgets('greyscale layer only while on; the 🇰🇷 keeps still', (tester) async {
    await _load(tester, business: false);
    await tester.pumpWidget(const HangulHoorayApp());
    await tester.pump();
    expect(find.byKey(const ValueKey('business_greyscale')), findsNothing);

    double flagAngle() {
      final t = tester.widget<Transform>(
        find.ancestor(of: find.text('🇰🇷'), matching: find.byType(Transform)).first,
      );
      return atan2(t.transform.entry(1, 0), t.transform.entry(0, 0));
    }

    await tester.pump(const Duration(milliseconds: 200));
    expect(flagAngle().abs(), greaterThan(0.01), reason: 'dancing when off');

    await tester.runAsync(() => appState.setBusinessMode(true));
    await tester.pump();
    expect(find.byKey(const ValueKey('business_greyscale')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 170));
      expect(flagAngle(), 0, reason: 'still in Business mode');
    }
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no animation running');

    await tester.runAsync(() => appState.setBusinessMode(false));
    await tester.pump();
    expect(find.byKey(const ValueKey('business_greyscale')), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(flagAngle().abs(), greaterThan(0.01), reason: 'dancing again');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pixels turn grey, except under KeepColor', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shot = GlobalKey();
    Widget app(bool on) => RepaintBoundary(
      key: shot,
      child: MaterialApp(
        builder: (_, child) => AppFrame(businessMode: on, child: child!),
        home: Scaffold(
          body: Column(
            children: [
              Container(height: 100, color: const Color(0xFFFF0000)),
              const SizedBox(height: 50),
              const KeepColor(
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Future<(List<int>, List<int>)> sample() async {
      await tester.pump();
      await tester.pump();
      final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      return (
        await _pixel(tester, image, const Offset(200, 50)),
        await _pixel(tester, image, const Offset(200, 200)),
      );
    }

    await tester.pumpWidget(app(false));
    var (plain, kept) = await sample();
    expect(plain.sublist(0, 3), [255, 0, 0]);
    expect(kept.sublist(0, 3), [255, 0, 0]);

    await tester.pumpWidget(app(true));
    (plain, kept) = await sample();
    expect(plain[0], plain[1], reason: 'grey: $plain');
    expect(plain[1], plain[2], reason: 'grey: $plain');
    expect(kept.sublist(0, 3), [255, 0, 0], reason: 'KeepColor stays red');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('🎨 Color match marks only its colours to keep', (tester) async {
    await _load(tester, business: true);
    var boxes = 0, buttons = 0;
    for (var seed = 1; seed <= 8; seed++) {
      appState.engine = GameEngine(_words, random: Random(seed));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 9)));
      await tester.pump();
      final kept = find.byType(KeepColor);
      if (find.byKey(const ValueKey('color_box')).evaluate().isNotEmpty) {
        boxes++;
        expect(kept, findsOneWidget, reason: 'just the colour box');
      } else {
        buttons++;
        final options = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('color_option_'),
        );
        expect(kept.evaluate().length, options.evaluate().length, reason: 'one per colour button');
      }
    }
    expect(boxes, greaterThan(0));
    expect(buttons, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final business in [false, true]) {
    testWidgets(
      'victory confetti ${business ? 'off' : 'on'} with Business mode ${business ? 'on' : 'off'}',
      (tester) async {
        await _load(tester, business: business);
        for (final shuffle in [false, true]) {
          appState.engine = GameEngine(_words, random: Random(3));
          await tester.pumpWidget(
            MaterialApp(
              home: shuffle
                  ? GameScreen.shuffle(key: UniqueKey())
                  : GameScreen(key: UniqueKey(), game: 1),
            ),
          );
          await tester.pump();
          expect(find.byType(ConfettiWidget), business ? findsNothing : findsOneWidget);
          if (shuffle) continue;
          // Tap the answers in turn until one wins.
          final winsBefore = appState.sessionWins[1] ?? 0;
          var played = false;
          for (var i = 0; i < 3 && !played; i++) {
            await tester.tap(find.byKey(ValueKey('option_text_$i')));
            await tester.pump(const Duration(milliseconds: 50));
            final c = find.byType(ConfettiWidget);
            played =
                c.evaluate().isNotEmpty &&
                tester.widget<ConfettiWidget>(c).confettiController.state ==
                    ConfettiControllerState.playing;
            if (business) expect(c, findsNothing, reason: 'no confetti after a win');
          }
          if (business) await tester.pump(const Duration(milliseconds: 50));
          expect(appState.sessionWins[1] ?? 0, winsBefore + 1, reason: 'a round was won');
          expect(played, !business);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        }
      },
    );
  }
}
