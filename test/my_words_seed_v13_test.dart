import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// t54u (v13): Michi, Michel-André and Nicole left the built-in 👨‍👩‍👧 Family
/// pack and are seeded once into ✏️ My Words, spelled the family's way.
const _names = [('Michi', '미시'), ('Michel-André', '미셸안드레'), ('Nicole', '다정전')];

Future<AppState> _load(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState();
  await s.load();
  return s;
}

Future<AppState> _reload() async {
  final s = AppState();
  await s.load();
  return s;
}

List<(String, String)> _customNames(AppState s) =>
    s.customWords.map((e) => (e.english1, e.korean1)).toList();

String _override(String section, VocabEntry e) =>
    jsonEncode({section: e.copyWith(sectionName: section).toJson()});

/// An existing install: something is saved (here, a switched-off option).
const _existing = <String, Object>{AppState.kVibration: false};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data', () {
    test('the names are gone from the INI and Family', () {
      final all = parseIni(File('assets/korean_vocab.ini').readAsStringSync());
      for (final (en, _) in _names) {
        expect(all.where((e) => e.english1 == en), isEmpty, reason: en);
      }
      for (final k in ['미시', '미셸안드레', '미셸앙드레', '다정전', '니콜']) {
        expect(all.where((e) => e.korean1 == k || e.korean2 == k), isEmpty, reason: k);
      }
      for (final section in retiredNameEntries) {
        expect(all.where((e) => e.sectionName == section), isEmpty, reason: section);
        expect(movedWords.containsKey(section), isFalse);
      }
      expect(all.where((e) => e.inPack('people')), hasLength(25));
    });

    test('seeds: exact spellings, no emoji, My Words, unique sections', () {
      expect(seededMyWords.map((e) => (e.english1, e.korean1)), _names);
      for (final e in seededMyWords) {
        expect((e.packId, e.emoji, e.korean2), (customBundleId, '', ''));
        expect(e.alsoPacks, isEmpty);
        expect(e.sectionName, startsWith('Custom_'));
      }
      expect(seededMyWords.map((e) => e.sectionName).toSet(), hasLength(3));
      expect(wrongNameSpellings, {'미셸앙드레': '미셸안드레', '니콜': '다정전'});
    });

    test('My Words is on by default', () {
      expect(defaultOffBundles.contains(customBundleId), isFalse);
    });

    test('apply_vocab_fixes.py can no longer respell the names', () {
      final src = File('/workspace/tools/apply_vocab_fixes.py').readAsStringSync();
      expect(src, isNot(contains("'니콜')")));
      expect(src, isNot(contains("'미셸앙드레')")));
      expect(src, contains('NEVER_TOUCH'));
    }, skip: !File('/workspace/tools/apply_vocab_fixes.py').existsSync());
  });

  group('fresh install', () {
    test('starts with the 3 names in My Words, in play', () async {
      final s = await _load({});
      expect(_customNames(s), _names);
      expect(s.enabledBundles, contains(customBundleId));
      final inPlay = s.activeVocab().map((e) => e.english1).toSet();
      expect(inPlay, containsAll(_names.map((n) => n.$1)));
      expect(s.activeVocab(), hasLength(544), reason: 'Family −3, My Words +3');
      expect(s.wordsInPack(customBundleId).map((e) => e.english1), _names.map((n) => n.$1));
      expect(s.wordsInPack('people').map((e) => e.english1), isNot(contains('Michi')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kSeededMyWords), isTrue);
      expect(_customNames(await _reload()), _names, reason: 'saved, seeded once');
    });

    test('they are real custom words: edit and delete stick', () async {
      final s = await _load({});
      final nicole = s.customWords.firstWhere((e) => e.english1 == 'Nicole');
      await s.saveWord(nicole.copyWith(emoji: '👩'), packChoice: s.resolvePack(''));
      final michi = s.customWords.firstWhere((e) => e.english1 == 'Michi');
      await s.deleteCustomWord(michi);
      var t = await _reload();
      expect(_customNames(t), [('Michel-André', '미셸안드레'), ('Nicole', '다정전')]);
      expect(t.customWords.last.emoji, '👩');
      for (final e in [...t.customWords]) {
        await t.deleteCustomWord(e);
      }
      t = await _reload();
      expect(t.customWords, isEmpty, reason: 'deleted names never come back');
    });
  });

  group('update from an older version', () {
    test('adds the 3 once, after the player\'s own words', () async {
      final s = await _load({
        ..._existing,
        'custom_words': jsonEncode([
          const VocabEntry(
            sectionName: 'Custom_1',
            packId: 'custom',
            english1: 'Fox',
            korean1: '여우',
          ).toJson(),
        ]),
      });
      expect(_customNames(s), [('Fox', '여우'), ..._names]);
      expect(_customNames(await _reload()), [('Fox', '여우'), ..._names]);
    });

    test('an edit is carried over, with the right spelling back', () async {
      final s = await _load({
        ..._existing,
        AppState.kOverrides: _override(
          'Entry_00263',
          const VocabEntry(
            packId: 'people',
            english1: 'Michel-André (dad)',
            emoji: '🧔',
            korean1: '미셸앙드레',
          ),
        ),
      });
      final m = s.customWords.firstWhere((e) => e.sectionName == 'Custom_seed_michel_andre');
      expect(
        (m.english1, m.korean1, m.emoji, m.packId),
        ('Michel-André (dad)', '미셸안드레', '🧔', customBundleId),
      );
      expect(s.overrides.keys.where(retiredNameEntries.contains), isEmpty);
      final saved = jsonDecode(
        (await SharedPreferences.getInstance()).getString(AppState.kOverrides)!,
      ) as Map;
      expect(saved.keys.where(retiredNameEntries.contains), isEmpty);
      expect(s.customWords, hasLength(3));
    });

    test('Korean the player typed is theirs; a pack they picked is kept', () async {
      final s = await _load({
        ..._existing,
        AppState.kOverrides: jsonEncode({
          ...jsonDecode(
            _override(
              'Entry_00264',
              const VocabEntry(packId: 'people', english1: 'Nicole', korean1: '니콜이'),
            ),
          ) as Map,
          ...jsonDecode(
            _override(
              'Entry_00262',
              const VocabEntry(packId: 'whos-who', english1: 'Michi', korean1: '미시'),
            ),
          ) as Map,
        }),
      });
      expect(s.customWords.map((e) => (e.english1, e.korean1, e.packId)), [
        ('Michi', '미시', 'whos-who'),
        ('Michel-André', '미셸안드레', customBundleId),
        ('Nicole', '니콜이', customBundleId),
      ]);
    });

    test('no duplicates of custom words with the same Korean', () async {
      final s = await _load({
        ..._existing,
        'custom_words': jsonEncode([
          const VocabEntry(
            sectionName: 'Custom_1',
            packId: 'custom',
            english1: 'Mom',
            korean1: '다정전',
          ).toJson(),
          const VocabEntry(
            sectionName: 'Custom_2',
            packId: 'custom',
            english1: 'Me',
            korean1: '미 시',
          ).toJson(),
          const VocabEntry(
            sectionName: 'Custom_3',
            packId: 'custom',
            english1: 'Dad',
            korean1: '미셸앙드레',
          ).toJson(),
        ]),
      });
      expect(_customNames(s), [('Mom', '다정전'), ('Me', '미 시'), ('Dad', '미셸앙드레')]);
      expect(_customNames(await _reload()), hasLength(3));
    });

    test('already seeded: nothing is added again', () async {
      final s = await _load({..._existing, AppState.kSeededMyWords: true});
      expect(s.customWords, isEmpty);
    });
  });
}
