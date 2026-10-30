import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _load(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
}

void main() {
  testWidgets('best streaks are kept per game, Shuffle on its own, and survive a restart', (
    tester,
  ) async {
    await _load(tester);
    expect(appState.bestStreaks, isEmpty);
    await appState.recordStreak(1, 3);
    await appState.recordStreak(1, 2);
    await appState.recordStreak(0, 7);
    expect(appState.bestStreaks, {1: 3, 0: 7});
    final saved = (await SharedPreferences.getInstance()).getString(AppState.kBestStreaks)!;
    await _load(tester, {AppState.kBestStreaks: saved});
    expect(appState.bestStreaks, {1: 3, 0: 7});
  });

  testWidgets('📊 Highest Streak sits under All-time wins, only with Streak count on', (
    tester,
  ) async {
    await _load(tester, {AppState.kBestStreaks: '{"1":4,"0":9}'});
    await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
    await tester.pump();
    expect(find.text('Highest Streak'), findsOneWidget);
    final wins = tester.getTopLeft(find.text('All-time wins by game')).dy;
    final best = tester.getTopLeft(find.text('Highest Streak')).dy;
    expect(best, greaterThan(wins));
    final perDay = find.text('Wins per day (last 14 days)', skipOffstage: false);
    if (perDay.evaluate().isNotEmpty) expect(best, lessThan(tester.getTopLeft(perDay).dy));
    final box = find.byKey(const ValueKey('highest_streak'));
    expect(find.descendant(of: box, matching: find.text('🔀')), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('9')), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('4')), findsOneWidget);

    await appState.setShowStreak(false);
    await tester.pump();
    expect(find.text('Highest Streak'), findsNothing);
  });
}
