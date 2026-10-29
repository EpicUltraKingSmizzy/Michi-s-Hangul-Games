import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const firstRelease = [
    'phrases',
    'food',
    'home',
    'outside',
    'critters',
    'words',
    'verbs',
    'numbers',
    'grabbag',
    'custom',
  ];

  test('upgrade: new packs start on, switched-off packs stay off', () async {
    SharedPreferences.setMockInitialValues({
      'enabled_bundles': [...firstRelease]..remove('words'),
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.contains('words'), isFalse);
    expect(s.enabledBundles.contains('emotions'), isTrue);
    expect(
      s.enabledBundles.containsAll(['time', 'native', 'colours', 'people', 'animals', 'body']),
      isTrue,
    );
    expect(s.enabledBundles.contains('critters'), isFalse);
    await s.setBundleEnabled('colours', false);
    final again = AppState();
    await again.load();
    expect(again.enabledBundles.contains('colours'), isFalse);
    expect(again.enabledBundles.contains('animals'), isTrue);
  });

  test('upgrade: an old Critters off-switch carries over to its three new packs', () async {
    SharedPreferences.setMockInitialValues({
      'enabled_bundles': [...firstRelease]..remove('critters'),
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.intersection({'people', 'animals', 'body'}), isEmpty);
    expect(s.enabledBundles.containsAll(['time', 'food', 'home', 'numbers']), isTrue);
  });

  test('upgrade: Words & Feelings on keeps its words in play via Grab Bag + Emotions', () async {
    SharedPreferences.setMockInitialValues({
      'enabled_bundles': [...firstRelease]..remove('grabbag'),
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.containsAll(['grabbag', 'emotions']), isTrue);
    expect(s.enabledBundles.contains('words'), isFalse);
    final again = AppState();
    await again.load();
    expect(again.enabledBundles.contains('words'), isFalse);
    expect(again.enabledBundles.contains('grabbag'), isTrue);
  });

  test('upgrade: Words & Feelings off and Grab Bag off stay off; Emotions starts on', () async {
    SharedPreferences.setMockInitialValues({
      'enabled_bundles': [...firstRelease]..removeWhere((x) => x == 'words' || x == 'grabbag'),
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.contains('grabbag'), isFalse);
    expect(s.enabledBundles.contains('emotions'), isTrue);
  });

  test('saved words and edits in Words & Feelings move to Emotions or Grab Bag', () async {
    SharedPreferences.setMockInitialValues({
      'custom_words': jsonEncode([
        {'sectionName': 'Custom_1', 'packId': 'words', 'english1': 'Angry', 'korean1': '화나다'},
        {'sectionName': 'Custom_2', 'packId': 'words', 'english1': 'Kite', 'korean1': '연'},
        {'sectionName': 'Custom_3', 'categoryName': 'Vocab', 'english1': 'Rope', 'korean1': '밧줄'},
        {'sectionName': 'Custom_4', 'categoryName': 'Emotion', 'english1': 'Joy', 'korean1': '기쁨'},
        {
          'sectionName': 'Custom_5',
          'categoryName': 'Words & Feelings',
          'english1': 'Love',
          'korean1': '사랑',
        },
      ]),
      'builtin_overrides': jsonEncode({
        'Entry_00453': {
          'sectionName': 'Entry_00453',
          'packId': 'words',
          'english1': 'Lock it',
          'korean1': '잠그다',
        },
        'Entry_00295': {
          'sectionName': 'Entry_00295',
          'packId': 'words',
          'english1': 'Mad',
          'korean1': '화나다',
        },
      }),
    });
    final s = AppState();
    await s.load();
    String pack(String id) => s.customWords.singleWhere((e) => e.sectionName == id).packId;
    expect(
      [for (var i = 1; i <= 5; i++) pack('Custom_$i')],
      ['emotions', 'grabbag', 'grabbag', 'emotions', 'emotions'],
    );
    expect(s.overrides['Entry_00453']!.packId, 'grabbag');
    expect(s.overrides['Entry_00295']!.packId, 'emotions');
    // The move is saved, so a second launch sees the same thing.
    final again = AppState();
    await again.load();
    expect(again.customWords.map((e) => e.packId), s.customWords.map((e) => e.packId));
    expect(again.overrides['Entry_00453']!.packId, 'grabbag');
  });

  test('fresh install: everything on except the new noun packs', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    expect(s.enabledBundles, {
      ...builtInBundles.map((b) => b.id).where((id) => !defaultOffBundles.contains(id)),
      'custom',
    });
  });
}
