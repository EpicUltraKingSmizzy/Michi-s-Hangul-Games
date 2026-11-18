import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/custom_words_screen.dart';
import 'package:hangul_hooray/screens/emoji_picker_screen.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/screens/pack_stats_screen.dart';
import 'package:hangul_hooray/screens/shuffle_games_screen.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:hangul_hooray/widgets/app_frame.dart';
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

/// Small and odd windows: browser windows, browser zoom, phone split view.
const _sizes = [
  Size(412, 915), // a normal phone
  Size(360, 640),
  Size(300, 500), // small window
  Size(412, 420), // phone split view, top half
  Size(800, 360), // short, wide browser window
  Size(1280, 600), // zoomed-in desktop browser
  Size(240, 900), // very narrow window
];

Widget _framed(Widget screen, {bool business = false}) => MaterialApp(
  builder: (_, child) => AppFrame(businessMode: business, child: child!),
  home: screen,
);

void main() {
  test('scale: only windows smaller than the phone layout shrink', () {
    expect(ShrinkToFit.scaleFor(const Size(412, 915)), 1);
    expect(ShrinkToFit.scaleFor(const Size(1920, 1080)), 1);
    expect(ShrinkToFit.scaleFor(const Size(180, 900)), 0.5);
    expect(ShrinkToFit.scaleFor(const Size(800, 300)), 0.5);
  });

  for (final size in _sizes) {
    testWidgets('every screen fits ${size.width}x${size.height} without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({AppState.kVibration: false});
      await tester.runAsync(appState.load);

      Future<void> check(String name, Widget screen) async {
        await tester.pumpWidget(_framed(KeyedSubtree(key: UniqueKey(), child: screen)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: '$name at $size');
        // The app is laid out at least as big as the phone layout needs.
        final mq = MediaQuery.of(tester.element(find.byWidget(screen)));
        expect(mq.size.width, greaterThanOrEqualTo(ShrinkToFit.minWidth - 0.01), reason: name);
        expect(mq.size.height, greaterThanOrEqualTo(ShrinkToFit.minHeight - 0.01), reason: name);
        // ...and everything drawn stays inside the real window.
        final screenRect = Offset.zero & size;
        final r = tester.getRect(find.byWidget(screen));
        expect(
          screenRect.inflate(0.5).contains(r.topLeft) &&
              screenRect.inflate(0.5).contains(r.bottomRight),
          isTrue,
          reason: '$name drawn at $r, window $screenRect',
        );
      }

      await check('home', const HomeScreen());
      await check('options', const OptionsScreen());
      await check('shuffle games', const ShuffleGamesScreen());
      await check('word packs', const BundlesScreen());
      await check('verb packs', const VerbPacksScreen());
      await check('my words', const CustomWordsScreen());
      await check('edit word', const EditWordScreen());
      await check('emoji picker', const EmojiPickerScreen(packName: 'Test'));
      await check('stats', const StatsScreen());
      await check('pack stats', const PackStatsScreen());

      final verbs = appState.engine.verbWords;
      for (var g = 1; g <= GameEngine.gameCount; g++) {
        appState.engine =
            GameEngine([
                ..._words,
                if (g == GameEngine.sentenceGame) ...verbs.values,
              ], random: Random(g))
              ..sentenceBank = appState.sentenceBank
              ..verbWords = verbs;
        await check('game $g', GameScreen(game: g));
      }
      await check('shuffle', const GameScreen.shuffle());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('a shrunk app still takes taps where they are drawn', (tester) async {
    tester.view.physicalSize = const Size(300, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({AppState.kVibration: false});
    await tester.runAsync(appState.load);
    await tester.pumpWidget(const HangulHoorayApp());
    await tester.pump();
    expect(find.byKey(const ValueKey('shrink_to_fit')), findsOneWidget);
    await tester.tap(find.text('Options'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(OptionsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
