import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tip = find.byKey(const ValueKey('typing_tip'));

Future<void> _setUp(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
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

Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('✍️ tip shows on open, hides after first input, returns on reopen', (tester) async {
    await _setUp(tester);
    await _open(tester, GameScreen(key: UniqueKey(), game: 3));
    expect(_tip, findsOneWidget);
    expect(
      find.text(
        'Tip: Use voice-to-text on your phone keyboard to turn this into speaking practice. '
        'I use Gboard with the Korean language installed.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'ㄱ');
    await tester.pump();
    expect(_tip, findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(_tip, findsNothing, reason: 'stays hidden for the rest of the session');

    await _open(tester, GameScreen(key: UniqueKey(), game: 3));
    expect(_tip, findsOneWidget, reason: 'back after exit + reopen');
    await _tearDown(tester);
  });

  testWidgets('✍️ tip only in Typing practice, never in Shuffle', (tester) async {
    await _setUp(tester);
    await tester.runAsync(() async {
      for (var g = 1; g <= GameEngine.gameCount; g++) {
        if (g != 3) await appState.setShuffleGame(g, false);
      }
    });
    await _open(tester, GameScreen.shuffle(key: UniqueKey()));
    expect(find.byType(TextField), findsOneWidget, reason: 'Shuffle is showing ✍️');
    expect(_tip, findsNothing);
    await _open(tester, GameScreen(key: UniqueKey(), game: 4));
    expect(_tip, findsNothing);
    await _tearDown(tester);
  });
}
