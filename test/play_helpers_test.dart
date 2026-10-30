import 'package:hangul_hooray/data/bundles.dart';

import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/play_helpers.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/custom_words_screen.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:hangul_hooray/screens/home_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:hangul_hooray/widgets/number_keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';

TypingRound _round({List<String> buttons = const [], String a1 = '고양이', bool korean = true}) =>
    TypingRound(
      prompt: 'Cat',
      promptIsKorean: !korean,
      answer1: a1,
      answer2: '',
      answerIsKorean: korean,
      showHintAtStart: false,
      repetitions: 1,
      charButtons: buttons,
      alsoAccepted: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('keypad', () {
    test('phone layout 1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ✔', () {
      expect(keypadRows, [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['⌫', '0', '✔'],
      ]);
    });

    testWidgets('keys sit in a grid and report taps', (tester) async {
      final typed = <String>[];
      var back = 0, ok = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumberKeypad(onDigit: typed.add, onBackspace: () => back++, onSubmit: () => ok++),
          ),
        ),
      );
      Offset c(String k) => tester.getCenter(find.byKey(ValueKey('key_$k')));
      expect(c('1').dy, c('3').dy);
      expect(c('1').dx, lessThan(c('2').dx));
      expect(c('2').dx, lessThan(c('3').dx));
      expect(c('1').dy, lessThan(c('4').dy));
      expect(c('4').dy, lessThan(c('7').dy));
      expect(c('7').dy, lessThan(c('0').dy));
      expect(c('⌫').dx, c('7').dx);
      expect(c('0').dx, c('8').dx);
      expect(tester.getSize(find.byKey(const ValueKey('key_5'))).height, greaterThanOrEqualTo(56));
      for (final k in ['1', '0', '9']) {
        await tester.tap(find.byKey(ValueKey('key_$k')));
      }
      await tester.tap(find.byKey(const ValueKey('key_⌫')));
      await tester.tap(find.byKey(const ValueKey('key_✔')));
      expect(typed, ['1', '0', '9']);
      expect(back, 1);
      expect(ok, 1);
    });

    test('digit rounds get the keypad, letter rounds get slots', () {
      final digits = _round(
        buttons: const ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
        a1: '42',
        korean: false,
      );
      expect(isKeypadRound(digits), isTrue);
      expect(isSlotRound(digits), isFalse);
      final tiles = _round(buttons: const ['이', '고', '양', '개']);
      expect(isKeypadRound(tiles), isFalse);
      expect(isSlotRound(tiles), isTrue);
      expect(slotCount(tiles), 3);
      expect(isSlotRound(_round()), isFalse); // plain typing round
    });
  });

  group('answer slots', () {
    test('tiles fill left to right; text and full', () {
      final s = TileSlots(['이', '고', '양', '개'], 3);
      expect(s.place(1), 0);
      expect(s.place(2), 1);
      expect(s.place(1), -1, reason: 'a tile can only be used once');
      expect(s.isFull, isFalse);
      expect(s.place(0), 2);
      expect(s.isFull, isTrue);
      expect(s.text, '고양이');
      expect(s.place(3), -1, reason: 'no room left');
    });

    test('tapping a middle slot leaves a gap that the next tile fills', () {
      final s = TileSlots(['고', '양', '이', '개'], 3)
        ..place(0)
        ..place(3)
        ..place(2); // 고 개 이
      s.removeAt(1);
      expect(s.isUsed(3), isFalse, reason: '개 is back in the pile');
      expect([s.charAt(0), s.charAt(1), s.charAt(2)], ['고', null, '이']);
      expect(s.text, '고이');
      expect(s.place(1), 1, reason: 'next tile goes into the gap');
      expect(s.text, '고양이');
    });

    test('⌫ empties the right-most filled slot', () {
      final s = TileSlots(['고', '양', '이'], 3)
        ..place(0)
        ..place(1)
        ..place(2);
      s.removeAt(0);
      s.backspace();
      expect([s.charAt(0), s.charAt(1), s.charAt(2)], [null, '양', null]);
      s.backspace();
      expect(s.isEmpty, isTrue);
      s.backspace(); // no-op
      expect(s.isEmpty, isTrue);
    });
  });

  group('streak', () {
    test('counts hits, resets on a miss, labels from 2', () {
      final s = Streak();
      expect(s.label, isNull);
      s.hit();
      expect(s.label, isNull);
      s.hit();
      expect(s.label, '🔥×2');
      s.hit();
      s.hit();
      s.hit();
      expect(s.isMilestone, isTrue);
      expect(s.label, '🔥×5');
      s.miss();
      expect(s.count, 0);
      expect(s.best, 5);
      expect(s.label, isNull);
      expect(s.isMilestone, isFalse);
    });
  });

  group('win pause', () {
    // Fake engine: start / finish are driven by the test.
    late Completer<void> started;
    late Completer<bool> finished;
    var spoke = false;
    SpeechTracking fake() {
      spoke = true;
      return SpeechTracking(started.future, finished.future);
    }

    Future<bool Function()> runPause(WidgetTester tester, {bool spokenAnswer = true}) async {
      // Created inside the test's fake-async zone so their callbacks run on pump.
      started = Completer<void>();
      finished = Completer<bool>();
      spoke = false;
      var done = false;
      unawaited(WinPause.run(spokenAnswer: spokenAnswer, speak: fake).then((_) => done = true));
      await tester.pump();
      return () => done;
    }

    testWidgets('Spoken Answer off: 300 ms, no speech', (tester) async {
      final done = await runPause(tester, spokenAnswer: false);
      await tester.pump(const Duration(milliseconds: 298));
      expect(done(), isFalse);
      await tester.pump(const Duration(milliseconds: 3));
      expect(done(), isTrue);
      expect(spoke, isFalse);
    });

    testWidgets('speaks at once and moves on as soon as the voice ends (no minimum)', (
      tester,
    ) async {
      final done = await runPause(tester);
      expect(spoke, isTrue, reason: 'speech starts immediately');
      started.complete();
      await tester.pump(const Duration(milliseconds: 700));
      expect(done(), isFalse);
      finished.complete(true);
      await tester.pump();
      expect(done(), isTrue, reason: 'ended at ~0.7 s, well under the old 2 s');
    });

    testWidgets('waits for longer speech to end', (tester) async {
      final done = await runPause(tester);
      started.complete();
      await tester.pump(const Duration(milliseconds: 3200));
      expect(done(), isFalse);
      finished.complete(true);
      await tester.pump();
      expect(done(), isTrue);
    });

    testWidgets('started but never reports completion: capped at 5 s', (tester) async {
      final done = await runPause(tester);
      started.complete();
      await tester.pump(const Duration(milliseconds: 4900));
      expect(done(), isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(done(), isTrue);
    });

    testWidgets('TTS never starts / never answers: ~1.5 s fallback', (tester) async {
      final done = await runPause(tester);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(done(), isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(done(), isTrue);
    });

    testWidgets('TTS fails or is unavailable: ~1.5 s after the win', (tester) async {
      final done = await runPause(tester);
      finished.complete(false); // error / no Korean voice, reported straight away
      await tester.pump(const Duration(milliseconds: 1400));
      expect(done(), isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(done(), isTrue);
    });

    testWidgets('a late failure after 1.5 s ends the pause right away', (tester) async {
      final done = await runPause(tester);
      started.complete();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(done(), isFalse);
      finished.complete(false);
      await tester.pump();
      expect(done(), isTrue);
    });

    testWidgets('speak() throwing still ends after the fallback', (tester) async {
      var done = false;
      unawaited(
        WinPause.run(
          spokenAnswer: true,
          speak: () => throw StateError('no tts'),
        ).then((_) => done = true),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      expect(done, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(done, isTrue);
    });
  });

  group('options', () {
    test('default on and persist across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      expect([a.vibration, a.showWins, a.showStreak, a.spokenAnswer], [true, true, true, true]);
      await a.setVibration(false);
      await a.setShowWins(false);
      await a.setSpokenAnswer(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kVibration), isFalse);
      final b = AppState();
      await b.load();
      expect([b.vibration, b.showWins, b.showStreak, b.spokenAnswer], [false, false, true, false]);
      await b.setShowStreak(false);
      await b.setSpokenAnswer(true);
      final c = AppState();
      await c.load();
      expect(c.showStreak, isFalse);
      expect(c.spokenAnswer, isTrue);
    });

    testWidgets('home has ⚙️ Options (not My Words) and the toggles work', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.text('My Words'), findsNothing);
      await tester.scrollUntilVisible(find.text('Options'), 200);
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      expect(find.byType(OptionsScreen), findsOneWidget);
      for (final t in ['Vibration', 'Win count', 'Streak count', 'Spoken Answer']) {
        expect(find.text(t), findsOneWidget);
      }
      await tester.tap(find.text('Win count'));
      await tester.pump();
      expect(appState.showWins, isFalse);
      await tester.tap(find.text('Win count'));
      await tester.pump();
      expect(appState.showWins, isTrue);
    });
  });

  group('game screen', () {
    Future<void> setUpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
      });
      await tester.runAsync(appState.load);
    }

    testWidgets('5️⃣/6️⃣ show one slot per letter; tap returns a tile', (tester) async {
      await setUpApp(tester);
      for (final game in [5, 6]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: game),
          ),
        );
        await tester.pump();
        expect(find.byType(TextField), findsNothing);
        expect(find.byKey(const ValueKey('slot_0')), findsOneWidget);
        final slot0 = find.descendant(
          of: find.byKey(const ValueKey('slot_0')),
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(slot0).data, '');
        final tile0 = find.descendant(
          of: find.byKey(const ValueKey('tile_0')),
          matching: find.byType(Text),
        );
        final letter = tester.widget<Text>(tile0).data;
        await tester.tap(find.byKey(const ValueKey('tile_0')));
        await tester.pump();
        expect(tester.widget<Text>(slot0).data, letter);
        await tester.tap(find.byKey(const ValueKey('slot_0')));
        await tester.pump();
        expect(tester.widget<Text>(slot0).data, '');
        await tester.tap(find.byKey(const ValueKey('tile_0')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tile_backspace')));
        await tester.pump();
        expect(tester.widget<Text>(slot0).data, '');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }
    });

    testWidgets('7️⃣ digit rounds use the keypad, not the system keyboard', (tester) async {
      await setUpApp(tester);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 7)));
      await tester.pump();
      var tries = 0;
      while (find.byKey(const ValueKey('key_1')).evaluate().isEmpty && tries++ < 200) {
        await tester.tap(find.text('➡️'));
        await tester.pump();
      }
      expect(find.byType(NumberKeypad), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('streak and wins hide with their options', (tester) async {
      await setUpApp(tester);
      await appState.setShowWins(false);
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      expect(find.textContaining('🏆'), findsNothing);
      await appState.setShowWins(true);
      await tester.pump();
      expect(find.textContaining('🏆'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('typing auto-detect and hidden counters', () {
    Future<void> setUpApp(WidgetTester tester, Map<String, Object> prefs) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        AppState.kSpokenAnswer: false,
        AppState.kVibration: false,
        ...prefs,
      });
      await tester.runAsync(appState.load);
    }

    dynamic stateOf(WidgetTester tester) => tester.state(find.byType(GameScreen));

    testWidgets('a right answer in 4️⃣ wins without ✔; wins still logged with Win count off', (
      tester,
    ) async {
      await setUpApp(tester, {AppState.kShowWins: false, AppState.kShowStreak: false});
      expect(appState.showWins, isFalse);
      final todayBefore = appState.winsOnDay(dayKey(DateTime.now()));
      final totalBefore = appState.allTimeTotal;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 4)));
      await tester.pump();
      var r = stateOf(tester).currentRound as TypingRound;

      // Partial input: nothing happens (no red, streak untouched).
      await tester.enterText(find.byType(TextField), 'ㄱ');
      await tester.pump();
      expect(appState.sessionWins[4], 0);

      // Full answer while Gboard is still composing the last syllable.
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: r.answer1,
          selection: TextSelection.collapsed(offset: r.answer1.length),
          composing: TextRange(start: r.answer1.length - 1, end: r.answer1.length),
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.value.composing.isValid, isFalse, reason: 'composition ended');
      expect(field.controller!.text, r.answer1, reason: 'text untouched');
      expect(appState.sessionWins[4], 1);
      expect(appState.winsOnDay(dayKey(DateTime.now())), todayBefore + 1);
      expect(appState.allTimeTotal, totalBefore + 1);
      expect(stateOf(tester).streakCount, 1, reason: 'streak counted while hidden');
      expect(find.textContaining('🏆'), findsNothing);
      expect(find.textContaining('🔥'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wins_by_day'), contains('"4":'));

      // Next round; a wrong ✔ submit is still marked wrong.
      await tester.pump(const Duration(milliseconds: 400));
      r = stateOf(tester).currentRound as TypingRound;
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(stateOf(tester).streakCount, 1, reason: 'typing alone never marks wrong');
      await tester.tap(find.text('✔'));
      await tester.pump();
      expect(stateOf(tester).streakCount, 0);
      expect(appState.sessionWins[4], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Spoken Answer on, no TTS in tests: ~1.5 s fallback, ➡️ skips the pause', (
      tester,
    ) async {
      await setUpApp(tester, {AppState.kSpokenAnswer: true});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 4)));
      await tester.pump();
      var r = stateOf(tester).currentRound;
      await tester.enterText(find.byType(TextField), (r as TypingRound).answer1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(identical(stateOf(tester).currentRound, r), isTrue, reason: 'still pausing');
      await tester.tap(find.text('➡️'));
      await tester.pump();
      expect(identical(stateOf(tester).currentRound, r), isFalse, reason: '➡️ skipped ahead');
      expect(stateOf(tester).streakCount, 1, reason: 'skip during the win pause keeps streak');

      // Let the next win run its full fallback pause.
      r = stateOf(tester).currentRound;
      await tester.enterText(find.byType(TextField), (r as TypingRound).answer1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      expect(identical(stateOf(tester).currentRound, r), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(identical(stateOf(tester).currentRound, r), isFalse, reason: 'moved on at ~1.5 s');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('3️⃣ auto-detects every repetition', (tester) async {
      await setUpApp(tester, {});
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 3)));
      await tester.pump();
      final r = stateOf(tester).currentRound as TypingRound;
      expect(r.repetitions, GameEngine.defaultGame3Repetitions);
      for (var i = 1; i <= r.repetitions; i++) {
        await tester.enterText(find.byType(TextField), r.answer1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        if (i < r.repetitions) {
          expect(find.textContaining('$i / ${r.repetitions}'), findsOneWidget);
          expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
        }
      }
      expect(appState.sessionWins[3], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('every screen asks for dark status-bar icons', (tester) async {
    SharedPreferences.setMockInitialValues({AppState.kSpokenAnswer: false});
    await tester.runAsync(appState.load);
    final screens = <Widget>[
      const HomeScreen(),
      const BundlesScreen(),
      const CustomWordsScreen(),
      const StatsScreen(),
      const OptionsScreen(),
      for (var g = 1; g <= GameEngine.gameCount; g++) GameScreen(key: UniqueKey(), game: g),
      GameScreen.shuffle(key: UniqueKey()),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
      final regions = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .toList();
      expect(regions, isNotEmpty, reason: '${screen.runtimeType}');
      for (final r in regions) {
        expect(r.value.statusBarIconBrightness, Brightness.dark, reason: '${screen.runtimeType}');
        expect(r.value.statusBarBrightness, Brightness.light);
        expect(r.value.statusBarColor, Colors.transparent);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  group('home fits one screen', () {
    final sizes = {360.0: 800.0, 412.0: 915.0};
    for (final entry in sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        for (final bars in [false, true]) {
          final w = entry.key, h = entry.value;
          testWidgets(
            '${w.toInt()}x${h.toInt()}, font scale $scale${bars ? ', with system bars' : ''}',
            (tester) async {
              const dpr = 2.625;
              tester.view.physicalSize = Size(w * dpr, h * dpr);
              tester.view.devicePixelRatio = dpr;
              if (bars) {
                // Typical status bar + gesture nav bar.
                tester.view.padding = const FakeViewPadding(top: 24 * dpr, bottom: 24 * dpr);
              }
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.reset);
              addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
              SharedPreferences.setMockInitialValues({});
              await tester.runAsync(appState.load);
              for (var g = 1; g <= GameEngine.gameCount; g++) {
                appState.sessionWins[g] = g * 11; // badges showing too
              }
              appState.shuffleSessionWins = 123;
              await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
              await tester.pump();
              expect(tester.takeException(), isNull, reason: 'no overflow');

              final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
              if (scale == 1.0) {
                expect(scroll.position.maxScrollExtent, 0, reason: 'everything on one screen');
                for (final label in ['Word Packs', 'Options', 'Stats']) {
                  final r = tester.getRect(find.text(label));
                  expect(r.bottom, lessThanOrEqualTo(h), reason: '$label visible');
                }
              }

              // Uniform game tiles: same width and height, a 2x5 grid of
              // the 10 games, then 🔀 Shuffle as a full-width, shorter bar.
              final rects = [
                for (final g in gameOrder) tester.getRect(find.byKey(ValueKey('tile_$g'))),
              ];
              expect(find.byKey(const ValueKey('tile_12')), findsNothing);
              expect(gameOrder, [1, 9, 3, 4, 5, 6, 7, 8, 2, 10]);
              final bar = tester.getRect(find.byKey(const ValueKey('tile_11')));
              expect(bar.left, closeTo(rects[0].left, 0.01));
              expect(bar.right, closeTo(rects[1].right, 0.01));
              expect(bar.top, greaterThan(rects[9].bottom));
              expect(bar.height, lessThan(rects[0].height));
              expect(bar.height, greaterThan(rects[0].height * 0.4));
              for (var g = 0; g < 10; g += 2) {
                expect(rects[g].top, closeTo(rects[g + 1].top, 0.01), reason: 'row ${g ~/ 2}');
                expect(rects[g].left, lessThan(rects[g + 1].left));
              }
              for (final r in rects) {
                expect(r.width, closeTo(rects.first.width, 0.01));
                expect(r.height, closeTo(rects.first.height, 0.01));
              }
              expect(rects.first.height, lessThan(rects.first.width), reason: 'shorter than wide');

              for (var g = 1; g <= 10; g++) {
                await tester.scrollUntilVisible(
                  find.byKey(ValueKey('tile_text_$g')),
                  200,
                  scrollable: find.byType(Scrollable).first,
                );
                expect(tester.takeException(), isNull);
                final text = tester.widget<Text>(find.byKey(ValueKey('tile_text_$g')));
                expect(text.data, gameInfos[g - 1].subtitle);
                final emoji = tester.widget<Text>(find.byKey(ValueKey('tile_emoji_$g')));
                expect(emoji.data, gameInfos[g - 1].emoji, reason: 'no keycap number');
              }
              expect(
                tester.widget<Text>(find.byKey(const ValueKey('tile_text_11'))).data,
                'Shuffle',
              );
              expect(tester.widget<Text>(find.byKey(const ValueKey('tile_emoji_11'))).data, '🔀');
              expect(
                tester.widget<Text>(find.byKey(const ValueKey('tile_text_10'))).data,
                'Link Up',
              );
              expect(tester.widget<Text>(find.byKey(const ValueKey('tile_emoji_10'))).data, '🔗');
              expect(
                find.byWidgetPredicate(
                  (w) => w is Text && RegExp('\u20E3|🔟').hasMatch(w.data ?? ''),
                ),
                findsNothing,
                reason: 'no keycap numbers on the home screen',
              );
              expect(tester.widget<Text>(find.byKey(const ValueKey('tile_emoji_1'))).data, '🔍');
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(seconds: 1));
            },
          );
        }
      }
    }
  });

  group('All packs master switch', () {
    test('turns every pack on/off, never My Words, and is restored', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppState();
      await a.load();
      final ids = a.builtInPackIds.toList();
      expect(ids, isNotEmpty);
      expect(a.allPacksOn, isTrue);

      await a.setAllPacks(false);
      expect(ids.where(a.enabledBundles.contains), isEmpty);
      expect(a.enabledBundles, contains(customBundleId), reason: 'My Words untouched');
      expect(a.allPacksOn, isFalse);
      // Only the seeded family names in My Words are left in play.
      expect(a.activeVocab().map((e) => e.english1), ['Michi', 'Michel-André', 'Nicole']);

      // Restart: everything off is restored, master off.
      var b = AppState();
      await b.load();
      expect(b.allPacksOn, isFalse);
      expect(ids.where(b.enabledBundles.contains), isEmpty);
      expect(b.enabledBundles, contains(customBundleId));

      // One pack on -> master shows on (mixed state = on).
      await b.setBundleEnabled(ids.first, true);
      expect(b.allPacksOn, isTrue);
      // Turning that one off again -> all off -> master off.
      await b.setBundleEnabled(ids.first, false);
      expect(b.allPacksOn, isFalse);

      // My Words off, then master on: built-ins on, My Words stays off.
      await b.setBundleEnabled(customBundleId, false);
      await b.setAllPacks(true);
      expect(ids.every(b.enabledBundles.contains), isTrue);
      expect(b.enabledBundles, isNot(contains(customBundleId)));

      // Individual pack changes persist too.
      await b.setBundleEnabled(ids.last, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kAllPacks), isTrue);
      b = AppState();
      await b.load();
      expect(b.enabledBundles, isNot(contains(ids.last)));
      expect(ids.take(ids.length - 1).every(b.enabledBundles.contains), isTrue);
      expect(b.enabledBundles, isNot(contains(customBundleId)));
      expect(b.allPacksOn, isTrue);
    });

    testWidgets('Word Packs screen: the master switch flips the packs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(appState.load);
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      expect(find.text('All packs'), findsNothing, reason: 'no label, just a switch');
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byKey(const ValueKey('all_packs'))),
        findsOneWidget,
      );
      expect(find.textContaining('463 words in play'), findsOneWidget); // 🗣️ off by default
      await tester.tap(find.byKey(const ValueKey('all_packs')));
      await tester.pump();
      expect(appState.allPacksOn, isFalse);
      // My Words (still on) keeps the 3 seeded family names in play.
      expect(find.textContaining('3 words in play'), findsOneWidget);
      expect(appState.builtInPackIds.where(appState.enabledBundles.contains), isEmpty);
      expect(appState.enabledBundles, contains(customBundleId), reason: 'My Words still on');
      expect(tester.widget<Switch>(find.byKey(const ValueKey('all_packs'))).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('all_packs')));
      await tester.pump();
      expect(appState.allPacksOn, isTrue);
      expect(appState.builtInPackIds.every(appState.enabledBundles.contains), isTrue);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('all_packs'))).value, isTrue);
    });
  });

  group('7️⃣/8️⃣ need no words', () {
    test('every number format plays with an empty vocab list', () {
      final engine = GameEngine([], random: Random(7));
      for (var g = 1; g <= 6; g++) {
        if (g == GameEngine.timeGame) continue; // 🕒 needs no words
        expect(engine.canPlay(g), isFalse, reason: 'game $g needs 3 words');
      }
      expect(engine.canPlay(GameEngine.timeGame), isTrue);
      for (final g in [7, 8]) {
        expect(engine.canPlay(g), isTrue);
        final formats = <String>{};
        for (var i = 0; i < 400; i++) {
          final r = engine.newRound(g);
          if (r is ChoiceRound) {
            expect(r.options.toSet().length, 3);
            expect(r.options, contains(r.correctAnswer));
            formats.add(r.optionsAreKorean ? 'pick korean' : 'pick number');
          } else {
            r as TypingRound;
            expect(r.answer1, isNotEmpty);
            expect(r.alsoAccepted, isEmpty);
            if (r.charButtons.isEmpty) {
              expect(r.answerIsKorean, isTrue);
              formats.add('type korean');
            } else {
              expect(r.charButtons, List.generate(10, (d) => '$d'));
              expect(isKeypadRound(r), isTrue);
              formats.add('digit keypad');
            }
          }
        }
        expect(formats, {'pick korean', 'pick number', 'type korean', 'digit keypad'});
      }
    });

    testWidgets('with every pack off, 7️⃣/8️⃣ play and 1️⃣ shows the friendly error', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({AppState.kSpokenAnswer: false});
      await tester.runAsync(appState.load);
      await appState.setAllPacks(false);
      await appState.setBundleEnabled(customBundleId, false);
      expect(appState.activeVocab(), isEmpty);
      for (final g in [7, 8, 9]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: g),
          ),
        );
        await tester.pump();
        expect(find.text('Not enough words to play!'), findsNothing, reason: 'game $g');
        expect((tester.state(find.byType(GameScreen)) as dynamic).currentRound, isNotNull);
        // Play through a bunch of rounds via ➡️.
        for (var i = 0; i < 30; i++) {
          await tester.tap(find.text('➡️'));
          await tester.pump();
          expect(find.text('Not enough words to play!'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 1)));
      await tester.pump();
      expect(find.text('Not enough words to play!'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      expect(find.text('0 words in play'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
