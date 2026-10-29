import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/custom_words_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔊 Spoken Answer is OFF here: explicit taps still speak.
Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: false,
    AppState.kVibration: false,
  });
  await tester.runAsync(appState.load);
  Speaker.debugSpoken = [];
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

final _speak = find.byKey(const ValueKey('speak_korean1'));
Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  tearDown(() => Speaker.debugSpoken = null);

  testWidgets('Edit Word: 🔊 sits in the Korean 1 field and reads what is typed', (tester) async {
    await _setUp(tester);
    final w = appState.wordsInPack('food').first;
    await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: w)));
    await tester.pump();
    expect(_speak, findsOneWidget);
    expect(
      find.descendant(of: _field('Korean 1 *'), matching: _speak),
      findsOneWidget,
      reason: 'beside the main Korean field',
    );
    expect(
      find.descendant(of: _field('Korean 2 (another accepted answer)'), matching: _speak),
      findsNothing,
    );
    expect(appState.spokenAnswer, isFalse);

    await tester.tap(_speak);
    await tester.pump();
    expect(Speaker.debugSpoken, [w.korean1]);

    // Reads the current text, not the saved word.
    await tester.enterText(_field('Korean 1 *'), ' 고양이 ');
    await tester.pump();
    await tester.tap(_speak);
    await tester.pump();
    expect(Speaker.debugSpoken, [w.korean1, '고양이']);
    await _tearDown(tester);
  });

  testWidgets('Edit Word: 🔊 is disabled when Korean 1 is empty or has no Hangul', (tester) async {
    await _setUp(tester);
    final w = appState.wordsInPack('food').first;
    await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: w)));
    await tester.pump();
    bool enabled() => tester.widget<SpeakButton>(_speak).enabled;
    expect(enabled(), isTrue);
    for (final t in ['', '   ', 'cat', '123 !']) {
      await tester.enterText(_field('Korean 1 *'), t);
      await tester.pump();
      expect(enabled(), isFalse, reason: '"$t"');
      await tester.tap(_speak, warnIfMissed: false);
      await tester.pump();
    }
    expect(Speaker.debugSpoken, isEmpty);
    await tester.enterText(_field('Korean 1 *'), 'ㄱ');
    await tester.pump();
    expect(enabled(), isTrue);
    await _tearDown(tester);
  });

  testWidgets('New Word: no 🔊 on the form', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: EditWordScreen()));
    await tester.pump();
    expect(find.text('➕ New Word'), findsOneWidget);
    await tester.enterText(_field('Korean 1 *'), '고양이');
    await tester.pump();
    expect(_speak, findsNothing);
    expect(find.byType(SpeakButton), findsNothing);
    await _tearDown(tester);
  });

  testWidgets('"Plays when … is on." is gone from Edit and New Word', (tester) async {
    await _setUp(tester);
    final custom = const VocabEntry(english1: 'Cat', korean1: '고양이');
    await tester.runAsync(() => appState.saveWord(custom, packChoice: appState.resolvePack('')));
    for (final entry in <VocabEntry?>[
      appState.wordsInPack('food').first, // built-in
      appState.customWords.last, // custom
      null, // New Word
    ]) {
      await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: entry)));
      await tester.pump();
      for (final pack in ['', 'My Words', 'Food']) {
        await tester.enterText(find.byKey(const ValueKey('pack_field')), pack);
        await tester.pump();
        expect(find.textContaining('Plays when'), findsNothing, reason: '$entry / "$pack"');
        expect(find.textContaining('both on'), findsNothing);
        expect(find.byKey(const ValueKey('pack_note')), findsNothing);
      }
      // A brand-new pack name still says its emoji is picked next.
      await tester.enterText(find.byKey(const ValueKey('pack_field')), 'Dinos');
      await tester.pump();
      expect(find.textContaining('New pack "Dinos"'), findsOneWidget);
      await _tearDown(tester);
    }
  });

  testWidgets('Word Packs: tap a chip speaks it; long press is silent and opens Edit', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
    await tester.pump();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    final words = appState.wordsInPack('food');
    final a = find.byKey(ValueKey('word_${words[0].sectionName}'));
    final b = find.byKey(ValueKey('word_${words[1].sectionName}'));

    await tester.tap(a);
    await tester.pump();
    expect(Speaker.debugSpoken, [words[0].korean1]);
    expect(find.text('✏️ Edit Word'), findsNothing, reason: 'tap does not open Edit');
    await tester.tap(b);
    await tester.pump();
    await tester.tap(a);
    await tester.pump();
    expect(Speaker.debugSpoken, [words[0].korean1, words[1].korean1, words[0].korean1]);

    Speaker.debugSpoken = [];
    await tester.longPress(a);
    await tester.pumpAndSettle();
    expect(Speaker.debugSpoken, isEmpty, reason: 'long press must not speak');
    expect(find.text('✏️ Edit Word'), findsOneWidget, reason: 'long press still edits');
    await _tearDown(tester);
  });
}
