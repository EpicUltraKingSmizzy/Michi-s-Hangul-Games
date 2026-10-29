import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/widgets/number_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({AppState.kSpokenAnswer: false});
  await tester.runAsync(appState.load);
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('number_help_close')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('number_help_dialog')), findsNothing);
}

void main() {
  group('❓ number explainers', () {
    test('content matches the requested explainers', () {
      final sino = sinoNumberHelp.allText.join('\n');
      final native = nativeNumberHelp.allText.join('\n');
      expect(sinoNumberHelp.title, '🔢 Sino-Korean Numbers');
      expect(nativeNumberHelp.title, '🖐️ Native Korean Numbers');
      final sinoTable = sinoNumberHelp.blocks.whereType<NumberHelpTable>().single;
      expect(sinoTable.korean.join(' '), '일 이 삼 사 오 육 칠 팔 구 십');
      expect(sinoTable.numerals.join(' '), '1 2 3 4 5 6 7 8 9 10');
      for (final s in ['11 is 십일 (10 + 1)', '20 is 이십 (2 × 10)', '25 is 이십오 (2 × 10 + 5)']) {
        expect(sino, contains(s));
      }
      expect(sino, contains('100,000 is 십만 (10 × 10,000)'));
      expect(sino, contains('Zero is 영, or 공 in phone numbers.'));
      final nativeTables = nativeNumberHelp.blocks.whereType<NumberHelpTable>().toList();
      expect(nativeTables, hasLength(2));
      expect(nativeTables[0].korean.join(' '), '하나 둘 셋 넷 다섯 여섯 일곱 여덟 아홉 열');
      expect(nativeTables[1].korean.join(' '), '열 스물 서른 마흔 쉰 예순 일흔 여든 아흔');
      expect(nativeTables[1].numerals.join(' '), '10 20 30 40 50 60 70 80 90');
      for (final s in ['11 is 열하나', '23 is 스물셋', '스물 becomes 스무', '스무 살 is 20 years old']) {
        expect(native, contains(s));
      }
      // No emoji outside the titles.
      final emoji = RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{20E3}]', unicode: true);
      for (final h in [sinoNumberHelp, nativeNumberHelp]) {
        expect(emoji.hasMatch(h.allText.skip(1).join()), isFalse, reason: h.title);
      }
    });

    testWidgets('🔢 pack: 0s first, numeric order, no 53 or 75', (tester) async {
      await _setUp(tester);
      final words = appState.wordsInPack('numbers');
      expect(words.take(2).map((w) => (w.korean1, w.english1)), [
        ('영', '0'),
        ('공', '0 (phone numbers)'),
      ]);
      final values = [for (final w in words) int.parse(w.english1.split(' ').first)];
      expect(values, [...values]..sort());
      expect(values, isNot(contains(53)));
      expect(values, isNot(contains(75)));
    });

    testWidgets('pack words agree with the explainers', (tester) async {
      await _setUp(tester);
      final sino = sinoNumberHelp.allText.join(' ');
      final native = nativeNumberHelp.allText.join(' ');
      for (final w in appState.effectiveBuiltIn.where((e) => e.inPack('numbers'))) {
        final n = int.tryParse(w.english1);
        if (n != null && n <= 10) expect(sino, contains(w.korean1), reason: w.english1);
      }
      for (final w in appState.effectiveBuiltIn.where((e) => e.inPack('native'))) {
        final n = int.tryParse(w.english1);
        if (n != null && (n <= 10 || n % 10 == 0)) {
          expect(native, contains(w.korean1), reason: w.english1);
        }
        if (w.korean2.isNotEmpty && (n == null || n <= 4 || n == 20)) {
          expect(native, contains(w.korean2), reason: 'short form ${w.english1}');
        }
      }
    });

    testWidgets('Word Packs: ❓ on both number packs; no toggle, no word list', (tester) async {
      await _setUp(tester);
      await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
      await tester.pump();
      for (final (id, help) in [('numbers', sinoNumberHelp), ('native', nativeNumberHelp)]) {
        final card = find.byKey(ValueKey('pack_$id'));
        final button = find.byKey(ValueKey('pack_help_$id'));
        await tester.scrollUntilVisible(
          button,
          300,
          scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(find.descendant(of: card, matching: button), findsOneWidget);
        final wasOn = appState.enabledBundles.contains(id);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('number_help_dialog')), findsOneWidget);
        expect(find.text(help.title), findsOneWidget);
        await _close(tester);
        expect(appState.enabledBundles.contains(id), wasOn, reason: 'not toggled');
        expect(
          find.descendant(of: card, matching: find.byKey(const ValueKey('long_press_hint'))),
          findsNothing,
          reason: 'word list stays closed',
        );
      }
      // Only the number packs get one.
      expect(find.byKey(const ValueKey('pack_help_colours')), findsNothing);
      await _done(tester);
    });

    for (final (game, help) in [(7, sinoNumberHelp), (8, nativeNumberHelp)]) {
      testWidgets('game $game header ❓ opens ${help.title}; round and streak untouched', (
        tester,
      ) async {
        await _setUp(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: game),
          ),
        );
        await tester.pump();
        final state = tester.state(find.byType(GameScreen)) as dynamic;
        final round = state.currentRound;
        final streak = state.streakCount;
        final wins = appState.sessionWins[game] ?? 0;
        final button = find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const ValueKey('number_help')),
        );
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text(help.title), findsOneWidget);
        await _close(tester);
        expect(identical(state.currentRound, round), isTrue);
        expect(state.streakCount, streak);
        expect(appState.sessionWins[game] ?? 0, wins);
        expect(tester.takeException(), isNull);
        await _done(tester);
      });
    }

    testWidgets('other games have no ❓', (tester) async {
      await _setUp(tester);
      for (final game in [1, 9]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(key: UniqueKey(), game: game),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('number_help')), findsNothing);
      }
      await _done(tester);
    });
  });
}
