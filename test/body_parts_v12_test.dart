import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// t53u (v12): every body part left 💓 Heart & Body for 🦵 Body Parts.
final _all = parseIni(File('assets/korean_vocab.ini').readAsStringSync());

VocabEntry _s(String section) => _all.singleWhere((e) => e.sectionName == section);

Set<String> _members(String pack) =>
    _all.where((e) => e.inPack(pack)).map((e) => e.korean1).toSet();

/// Were home in Heart & Body; now home in Body Parts.
const _moved = {'Entry_00675': '몸', 'Entry_00683': '고개', 'Entry_00700': '등', 'Entry_00703': '허리'};

/// Already Body Parts words that were also shared into Heart & Body.
const _unshared = {'눈', '귀', '팔', '다리', '발', '입', '손', '머리', '얼굴', '어깨', '가슴'};

const _heartAndBody = {
  '사랑', '웃음', '힘', '마음', '생활', '삶', '생명', '정신', '의식', '표정', //
  '느낌', '성격', '분위기', '목소리', '기분', '꿈', '자세', '잠', '건강', '환자',
  '태도', '눈물', '감정', '인생', '죽음', '고통', '의지', '신경', '시선', '키',
  '걱정', '숨',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data', () {
    test('the 4 moved words live only in Body Parts', () {
      _moved.forEach((section, korean) {
        final e = _s(section);
        expect((e.korean1, e.packId), (korean, 'body'), reason: korean);
        expect(e.alsoPacks, isEmpty, reason: korean);
      });
    });

    test('Body Parts words are no longer shared into Heart & Body', () {
      final body = _members('body');
      expect(body, containsAll({..._unshared, ..._moved.values}));
      expect(body.intersection(_members('heart-and-body')), isEmpty);
      expect(
        _all.where((e) => e.alsoPacks.contains('heart-and-body')).map((e) => e.korean1).toSet(),
        {'사랑', '웃음', '힘'},
      );
      expect(_all.where((e) => e.packId == 'body'), hasLength(29));
    });

    test('Heart & Body keeps the feelings, states & life words (32)', () {
      expect(_members('heart-and-body'), _heartAndBody);
      expect(_all.where((e) => e.inPack('heart-and-body')), hasLength(32));
    });

    test('new Heart & Body blurb; name unchanged; Body Parts on, Heart & Body off', () {
      final b = builtInBundles.singleWhere((b) => b.id == 'heart-and-body');
      expect(
        (b.emoji, b.name, b.blurb),
        ('💓', 'Heart & Body', 'Moods, dreams, sleep, health & the big stuff of life.'),
      );
      expect(defaultOffBundles, contains('heart-and-body'));
      expect(defaultOffBundles, isNot(contains('body')));
    });
  });

  group('app state', () {
    final keep = {
      'known_bundles': [...builtInBundles.map((b) => b.id), 'custom'],
    };

    test('fresh install: the moved words are in play with Body Parts', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      final live = s.activeVocab().map((e) => e.korean1).toSet();
      expect(live, containsAll(_moved.values));
      expect(live.intersection(_heartAndBody.difference({'사랑', '웃음', '힘'})), isEmpty);
      expect(s.activeVocab().length, 544);
    });

    test('a player with only Heart & Body on no longer gets body parts', () async {
      SharedPreferences.setMockInitialValues({
        'enabled_bundles': ['heart-and-body'],
        ...keep,
      });
      final s = AppState();
      await s.load();
      expect(s.activeVocab().map((e) => e.korean1).toSet(), _heartAndBody);
    });
  });
}
