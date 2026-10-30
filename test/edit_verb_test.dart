import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/packs.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:hangul_hooray/screens/custom_words_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(appState.load);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a verb opens Edit Verb: no Emoji / Korean 2, Korean read-only, Verb Packs only', (
    tester,
  ) async {
    await _setUp(tester);
    final v = appState.wordsInPack('daily-grind').first;
    await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: v)));
    await tester.pump();
    expect(find.text('✏️ Edit Verb'), findsOneWidget);
    expect(_field('Emoji'), findsNothing);
    expect(_field('Korean 2 (another accepted answer)'), findsNothing);
    expect(_field('Verb Pack'), findsOneWidget);
    expect(_field('Word Pack'), findsNothing);
    final korean = tester.widget<TextField>(
      find.descendant(of: _field('Korean 1 *'), matching: find.byType(TextField)),
    );
    expect(korean.readOnly, isTrue);
    for (final id in appState.verbPackIds) {
      expect(find.byKey(ValueKey('pack_pick_$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('pack_pick_food')), findsNothing);
    expect(find.byKey(const ValueKey('pack_pick_custom')), findsNothing);
  });

  testWidgets('Edit Word still has Emoji / Word Pack and no Verb Packs', (tester) async {
    await _setUp(tester);
    final w = appState.wordsInPack('food').first;
    await tester.pumpWidget(MaterialApp(home: EditWordScreen(entry: w)));
    await tester.pump();
    expect(find.text('✏️ Edit Word'), findsOneWidget);
    expect(_field('Emoji'), findsOneWidget);
    expect(_field('Word Pack'), findsOneWidget);
    for (final id in appState.verbPackIds) {
      expect(find.byKey(ValueKey('pack_pick_$id')), findsNothing);
    }
  });

  testWidgets('long press on a verb in the Verb Packs list opens Edit Verb', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const MaterialApp(home: VerbPacksScreen()));
    await tester.pump();
    await tester.tap(find.text('Daily Grind'));
    await tester.pumpAndSettle();
    final v = appState.wordsInPack('daily-grind').first;
    await tester.longPress(find.byKey(ValueKey('word_${v.sectionName}')));
    await tester.pumpAndSettle();
    expect(find.text('✏️ Edit Verb'), findsOneWidget);
  });

  test('a new Verb Pack: verb type saved + loaded, keeps grammar, not a Word Pack', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    final v = s.wordsInPack('daily-grind').first;
    final grammar = s.engine.verbOf(v);
    expect(grammar, isNotNull);
    final choice = s.resolvePack('🧪 Lab Verbs', verbs: true);
    expect(choice.kind, PackKind.newPack);
    await s.saveWord(v, packChoice: choice, newPackEmoji: '🧪', verb: true);
    final id = s.userVerbPacks.single.id;
    expect(s.userWordPacks, isEmpty);
    expect(s.isVerbPack(id), isTrue);
    expect(s.resolvePack('Lab Verbs', verbs: true).id, id);
    expect(s.resolvePack('Lab Verbs').kind, PackKind.newPack, reason: 'not a Word Pack');
    expect(s.resolvePack('', verbs: true).name, isEmpty, reason: 'blank is refused');

    final moved = s.activeVocab().singleWhere((e) => e.sectionName == v.sectionName);
    expect(moved.packId, id);
    expect(s.engine.verbOf(moved), same(grammar), reason: 'moved verb keeps its grammar');
    expect(s.engine.verbWords.containsKey(v.sectionName), isTrue);

    final again = AppState();
    await again.load();
    expect(again.userVerbPacks.single.id, id);
    expect(again.userVerbPacks.single.emoji, '🧪');
    expect(again.isVerbPack(id), isTrue);
  });

  testWidgets('a user Verb Pack is listed on the Verb Packs screen, not Word Packs', (
    tester,
  ) async {
    await _setUp(tester);
    final v = appState.wordsInPack('daily-grind').first;
    await tester.runAsync(
      () => appState.saveWord(
        v,
        packChoice: appState.resolvePack('Lab Verbs', verbs: true),
        newPackEmoji: '🧪',
        verb: true,
      ),
    );
    final id = appState.userVerbPacks.single.id;
    await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
    await tester.pump();
    expect(find.byKey(ValueKey('pack_$id')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('verb_packs_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verb_packs_note')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('pack_$id')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(ValueKey('pack_$id')), findsOneWidget);
  });
}
