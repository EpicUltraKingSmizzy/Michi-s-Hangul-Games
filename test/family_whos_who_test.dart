import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// t46u (v11): 👨‍👩‍👧 Family and 🧑‍🤝‍🧑 Who's Who no longer overlap; the
/// abstract people words moved out; Orange (fruit) / Orange (color).
final _all = parseIni(File('assets/korean_vocab.ini').readAsStringSync());

VocabEntry _k(String korean) => _all.singleWhere((e) => e.korean1 == korean);

Set<String> _members(String pack) =>
    _all.where((e) => e.inPack(pack)).map((e) => e.korean1).toSet();

const _family = {
  '가족', '아들', '딸', '어머니', '아버지', '엄마', '아빠', '남편', '아내', '형', //
  '누나', '남동생', '여동생', '동생', '형제', '자매', '부모', '부모님', '할머니', '할아버지',
  '자식', '결혼', '부부', '아기', '가정',
  // v13: 미시, 미셸안드레, 다정전 moved to My Words (seeded, not built in).
};

const _whosWho = {
  '종업원', '팬', '아이돌', '모델', '스타일리스트', '디자이너', '시민', '경찰', '농민', '노동자', //
  '주민', '주인', '손님', '이웃', '친구', '사람', '남자', '여자', '남자들', '남성',
  '여성', '남녀', '아이', '어린이', '소년', '소녀', '청소년', '어른', '노인', '아저씨',
  '인간', '인물',
};

const _abstract = {
  '인류': 'big-brain-ideas',
  '개인': 'big-brain-ideas',
  '자신': 'big-brain-ideas',
  '남': 'big-brain-ideas',
  '출신': 'big-brain-ideas',
  '혼자': 'how-things-are',
  '나이': 'how-things-are',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data', () {
    test('Family and Who\'s Who: names, blurbs, ids and defaults', () {
      final family = builtInBundleById('people')!;
      expect((family.emoji, family.name), ('👨‍👩‍👧', 'Family'));
      expect(family.blurb, 'Mom, dad, siblings, grandparents & the whole crew.');
      final who = builtInBundleById('whos-who')!;
      expect((who.emoji, who.name), ('🧑‍🤝‍🧑', "Who's Who"));
      expect(who.blurb, 'Jobs, friends, strangers & everyone outside the family.');
      expect(defaultOffBundles.contains('people'), isFalse);
      expect(defaultOffBundles.contains('whos-who'), isTrue);
    });

    test('each people word is in exactly one of the two packs', () {
      expect(_members('people'), _family);
      expect(_members('whos-who'), _whosWho);
      expect(_family.intersection(_whosWho), isEmpty);
      for (final e in _all) {
        expect(e.inPack('people') && e.inPack('whos-who'), isFalse, reason: e.korean1);
      }
      // Other shared packs are untouched: 시민 Citizen is still in Big Words.
      expect(_k('시민').packIds, ['whos-who', 'big-words']);
    });

    test('the abstract words moved out of the people packs', () {
      _abstract.forEach((ko, pack) {
        final e = _k(ko);
        expect(e.packId, pack, reason: ko);
        expect(e.alsoPacks, isEmpty, reason: ko);
      });
    });

    test('the Family emoji is no word\'s emoji (가족 has 👨‍👩‍👧‍👦)', () {
      expect(_all.where((e) => e.emoji.replaceAll('\uFE0F', '') == '👨‍👩‍👧'), isEmpty);
      expect(_k('가족').emoji, '👨‍👩‍👧‍👦');
    });

    test('Orange (fruit) and Orange (color)', () {
      final fruit = _k('오렌지');
      final colour = _k('주황색');
      expect((fruit.english1, fruit.emoji), ('Orange (fruit)', '🍊'));
      expect((colour.english1, colour.emoji), ('Orange (color)', '🟧'));
      expect(stripBracketNotes(fruit.english1), stripBracketNotes(colour.english1));
      for (final notes in [true, false]) {
        for (final emoji in [true, false]) {
          expect(
            GameEngine.entriesClash(fruit, colour, useEmoji: emoji, showBracketNotes: notes),
            !notes && !emoji,
            reason: 'notes $notes emoji $emoji',
          );
        }
      }
      final words = [fruit, colour, _k('정부'), _k('사회'), _k('바다')];
      for (var seed = 0; seed < 200; seed++) {
        final e = GameEngine(words, random: Random(seed))
          ..useEmoji = false
          ..showBracketNotes = false;
        expect(e.getWrongAnswers(fruit, words), isNot(contains(colour)), reason: 'seed $seed');
        expect(e.getWrongAnswers(colour, words), isNot(contains(fruit)), reason: 'seed $seed');
      }
    });
  });

  group('saved data', () {
    final keep = {
      'known_bundles': [...builtInBundles.map((b) => b.id), 'custom'],
    };

    test('a player with Family on: family words in, the moved ones out', () async {
      SharedPreferences.setMockInitialValues({
        'enabled_bundles': ['people'],
        ...keep,
      });
      final s = AppState();
      await s.load();
      expect(s.activeVocab().map((e) => e.korean1).toSet(), _family);
      await s.setBundleEnabled('whos-who', true);
      expect(s.activeVocab().map((e) => e.korean1).toSet(), {..._family, ..._whosWho});
    });
  });
}
