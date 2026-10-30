import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/bundles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vocab.dart';

const _verbPacks = {
  'daily-grind': ('🌅', 'Daily Grind', 24),
  'on-the-move': ('🚶', 'On the Move', 25),
  'talk-and-think': ('💬', 'Talk & Think', 24),
  'give-and-take': ('🤝', 'Give & Take', 24),
  'life-happens': ('🎢', 'Life Happens', 24),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = diskVocab();

  test(
    '5 Verb Packs, 121 dictionary-form verbs, no emojis, off by default',
    () {
      for (final MapEntry(key: id, value: (emoji, name, n))
          in _verbPacks.entries) {
        final b = builtInBundleById(id)!;
        expect(
          (b.emoji, b.name, b.isVerbPack, b.defaultOn),
          (emoji, name, true, false),
        );
        final words = all.where((e) => e.packId == id).toList();
        expect(words, hasLength(n), reason: id);
        for (final w in words) {
          expect(w.korean1.endsWith('다'), isTrue, reason: w.korean1);
          expect(w.english1.startsWith('to '), isTrue, reason: w.english1);
          expect((w.emoji, w.korean2), ('', ''));
        expect(w.alsoPacks, isEmpty);
        }
      }
      final verbs = all.where((e) => isVerbPackId(e.packId)).toList();
      expect(verbs, hasLength(121));
      expect(verbs.map((e) => e.korean1).toSet(), hasLength(121));
      for (final gone in ['지내다', '노력하다', '가지다', '죽다']) {
        expect(verbs.where((e) => e.korean1 == gone), isEmpty);
      }
      expect(
        builtInBundleById('verbs'),
        isNull,
        reason: 'no pack reuses the old Action Heroes id',
      );
      expect(
        builtInBundles.where((b) => !b.isVerbPack).map((b) => b.id),
        isNot(contains('daily-grind')),
      );
    },
  );

  test('verb words are never in play, even with their packs on', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    for (final id in _verbPacks.keys) {
      await s.setBundleEnabled(id, true);
    }
    expect(s.activeVocab().where((e) => isVerbPackId(e.packId)), isEmpty);
    expect(
      s.builtInPackIds.toSet().intersection(_verbPacks.keys.toSet()),
      isEmpty,
    );
    expect(s.verbPackIds.toList(), _verbPacks.keys.toList());
    expect(s.wordsInPack('daily-grind'), hasLength(24));
  });

  test('old Action Heroes saves load cleanly', () async {
    SharedPreferences.setMockInitialValues({
      'enabled_bundles': ['verbs', 'food', 'custom'],
      AppState.kOverrides: '{"Entry_00309":{"english1":"He Goes","korean1":"그는 가요","packId":"verbs"}}',
      AppState.kPackWins: '{"2026-10-01":{"verbs":3,"food":1}}',
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.contains('verbs'), isFalse);
    expect(s.overrides, isEmpty);
    expect(s.statsPackIds, isNot(contains('verbs')));
  });

  testWidgets('Word Packs: Verb Packs button opens the verb pack list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(appState.load);
    await tester.pumpWidget(const MaterialApp(home: BundlesScreen()));
    await tester.pump();
    expect(find.byKey(const ValueKey('pack_daily-grind')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('verb_packs_button')));
    await tester.pumpAndSettle();
    expect(find.byType(VerbPacksScreen), findsOneWidget);
    for (final id in _verbPacks.keys) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('pack_$id')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ValueKey('pack_$id')), findsOneWidget);
    }
  });
}
