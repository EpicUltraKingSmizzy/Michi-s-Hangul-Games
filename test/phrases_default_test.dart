import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> fresh([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState();
  await s.load();
  return s;
}

Future<List<String>?> savedPacks() async =>
    (await SharedPreferences.getInstance()).getStringList('enabled_bundles');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🗣️ Handy Phrases off by default', () {
    test('fresh install: Handy Phrases and Who\'s Who start off', () async {
      final s = await fresh();
      expect(defaultOffBundles, containsAll(['phrases', 'whos-who']));
      expect(s.enabledBundles, isNot(contains('phrases')));
      expect(s.enabledBundles, isNot(contains('whos-who')));
      expect(s.enabledBundles, contains('people'));
      expect(s.activeVocab().any((e) => e.packId == 'phrases'), isFalse);
      expect(s.activeVocab().length, 544); // 568 − 24 Handy Phrases
    });

    test('existing player who never touched a pack switch keeps Handy Phrases on', () async {
      final s = await fresh({
        'known_bundles': builtInBundles.map((b) => b.id).toList(),
        AppState.kVibration: true,
      });
      expect(s.enabledBundles, contains('phrases'));
      expect(s.enabledBundles, isNot(contains('whos-who')));
      expect(await savedPacks(), contains('phrases'), reason: 'saved, so it sticks');
      // and it stays on after another restart
      final again = AppState();
      await again.load();
      expect(again.enabledBundles, contains('phrases'));
    });

    test('a saved choice is kept either way', () async {
      final ids = builtInBundles.map((b) => b.id).toList();
      final on = await fresh({
        'known_bundles': ids,
        'enabled_bundles': ['phrases', 'food'],
      });
      expect(on.enabledBundles, containsAll(['phrases', 'food']));
      final off = await fresh({
        'known_bundles': ids,
        'enabled_bundles': ['food'],
      });
      expect(off.enabledBundles, isNot(contains('phrases')));
      expect(await savedPacks(), isNot(contains('phrases')));
    });

    test('the in-play count drops by exactly the Handy Phrases words', () async {
      final ids = builtInBundles.map((b) => b.id).toList();
      final old = await fresh({'known_bundles': ids});
      final s = await fresh();
      final phrasesOnly = old.activeVocab().where((e) => e.packId == 'phrases').length;
      expect(phrasesOnly, greaterThan(0));
      expect(s.activeVocab().length, old.activeVocab().length - phrasesOnly);
    });
  });

  testWidgets('⚙️ Options: 📳 and 🔥 are title-only, 🔥 Streak sits right above 🏆 Win', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(appState.load);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    final vib = find.byKey(const ValueKey('opt_vibration'));
    final streak = find.byKey(const ValueKey('opt_show_streak'));
    final wins = find.byKey(const ValueKey('opt_show_wins'));
    expect(find.descendant(of: vib, matching: find.byType(Text)), findsNWidgets(2)); // 📳 + title
    expect(find.descendant(of: streak, matching: find.byType(Text)), findsNWidgets(2));
    expect(find.descendant(of: wins, matching: find.byType(Text)), findsNWidgets(3));
    expect(find.textContaining('A buzz for right answers'), findsNothing);
    expect(find.textContaining('combo counter'), findsNothing);
    final vibR = tester.getRect(vib),
        streakR = tester.getRect(streak),
        winsR = tester.getRect(wins);
    expect(vibR.top, lessThan(streakR.top));
    expect(streakR.top, lessThan(winsR.top));
    // directly above: nothing between them but the cards' margins
    expect(winsR.top - streakR.bottom, lessThan(20));
    // title-only cards stay a comfortable tap target, shorter than a card with a blurb
    expect(vibR.height, lessThan(winsR.height));
    expect(streakR.height, greaterThanOrEqualTo(56));
  });
}
