import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/logic/link_game.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

import 'support/vocab.dart';

void main() {
  final all = diskVocab();
  final home = all.where((e) => e.packId == 'home').toList();
  final shirt = all.singleWhere((e) => e.korean1 == '셔츠');
  final tee = all.singleWhere((e) => e.korean1 == '티셔츠');
  bool both(Iterable<VocabEntry> ws) =>
      ws.any((w) => w.sectionName == shirt.sectionName) &&
      ws.any((w) => w.sectionName == tee.sectionName);

  setUp(() {
    GameEngine.notTogether = {
      for (final id in parsePackIndex(readVocabIndex())) ...parseNotWith(readPackFile(id)),
    };
  });
  tearDown(() => GameEngine.notTogether = {});

  test('NotWith in home.ini pairs 셔츠 Shirt with 티셔츠 T-shirt; the files validate', () {
    expect(shirt.english1, 'Shirt');
    expect(tee.english1, 'T-shirt');
    expect(GameEngine.notTogether, contains(notWithKey(tee.sectionName, shirt.sectionName)));
    expect(GameEngine.neverTogether(tee, shirt), isTrue);
    expect(GameEngine.neverTogether(shirt, tee), isTrue);
    expect(GameEngine.entriesClash(shirt, tee), isTrue);
    expect(validateVocab(readVocabIndex(), readPackFile), isEmpty);
    expect(
      validateVocab(readVocabIndex(), (id) {
        final t = readPackFile(id);
        return id == 'home' ? t.replaceFirst('NotWith = Entry_00187', 'NotWith = Nope_1') : t;
      }),
      contains(contains('unknown NotWith section Nope_1')),
    );
  });

  test('🔗 Link Up: Shirt and T-shirt are never on the same board', () {
    for (var seed = 0; seed < 300; seed++) {
      final r = GameEngine(home, random: Random(seed)).newRound(GameEngine.linkUpGame) as LinkRound;
      expect(both(r.words), isFalse, reason: 'seed $seed');
    }
    // Small pool: both would fit, one is left out instead.
    final others = home.where((e) => e != shirt && e != tee && e.emoji.isNotEmpty).take(5);
    final small = [shirt, tee, ...others];
    for (var seed = 0; seed < 50; seed++) {
      final e = GameEngine(small, random: Random(seed));
      expect(both(e.linkWords([shirt, tee, ...others])), isFalse);
      expect(both((e.newRound(GameEngine.linkUpGame) as LinkRound).words), isFalse);
    }
  });

  test('choice games: one is never a decoy for the other, even in a tiny vocabulary', () {
    for (var seed = 0; seed < 200; seed++) {
      final e = GameEngine(home, random: Random(seed));
      for (final t in [shirt, tee]) {
        expect(both([t, ...e.getWrongAnswers(t, home)]), isFalse);
      }
      GameEngine.pickKoreanFormat = true;
      final r = e.newRound(1) as ChoiceRound;
      GameEngine.pickKoreanFormat = null;
      expect(r.options.contains('셔츠') && r.options.contains('티셔츠'), isFalse);
    }
    final tiny = [shirt, tee, home.firstWhere((x) => x != shirt && x != tee)];
    for (var seed = 0; seed < 50; seed++) {
      final e = GameEngine(tiny, random: Random(seed));
      expect(both([shirt, ...e.getWrongAnswers(shirt, tiny)]), isFalse);
    }
  });
}
