import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';

import 'support/vocab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = diskVocab();
  final bank = diskSentences();
  final verbWords = {
    for (final e in all)
      if (isVerbPackId(e.packId)) e.sectionName: e,
  };

  /// Many 🏗️ Master sentences, from every verb.
  List<Sentence> samples() {
    final m = SentenceMaker(Random(5), verbs: bank.verbs);
    return [
      for (var i = 0; i < 20; i++)
        for (final v in bank.verbs) ?m.make(v, sentenceMaster),
    ];
  }

  test('sample sentences use natural word spacing', () {
    final s = samples();
    Sentence find(bool Function(Sentence) f, String what) =>
        s.firstWhere(f, orElse: () => fail('no $what sentence'));
    final past = find((x) => x.tense == Tense.past && !x.negated, 'past');
    final future = find((x) => x.tense == Tense.future, 'future');
    final neg = find((x) => x.negated && x.verbChip != '해요' && !x.korean.contains(' 안 해'), 'neg');
    final hada = find((x) => x.negated && x.fixedBeforeNegation.isNotEmpty, '하다');
    for (final x in [past, future, neg, hada]) {
      // ignore: avoid_print
      print(x.korean);
      expect(x.korean, isNot(contains('  ')));
      expect(x.korean.split(' ').length, greaterThan(1), reason: x.korean);
      // What the slots show, joined by their spacing, is the sentence.
      expect(x.spaced(x.answerTiles), x.korean);
    }
    expect(past.korean, endsWith(past.verb.conj.form(Tense.past)));
    expect(past.korean, isNot(contains(' ${splitVerbForm(past.verbChip).last}')));
    expect(future.korean, endsWith(' 거예요'));
    expect(neg.korean, contains(' 안 '));
    expect(hada.korean, contains('${hada.fixedBeforeNegation} 안 '));
  });

  test('particles stay on their noun; units are separated by spaces', () {
    for (final x in samples()) {
      final words = x.korean.split(' ');
      for (final u in x.units) {
        expect(words, contains(u.join()), reason: x.korean);
      }
      expect(x.joins('안', x.verbPieces.first), isFalse);
    }
  });

  test('fixed examples', () {
    final s = samples();
    for (final want in ['도서관에서', '먹을 거예요', '안 해요']) {
      expect(s.any((x) => x.korean.contains(want)), isTrue, reason: want);
    }
  });

  test('✍️/🧠/🧩/🌀 show the sentence spaced; typing still ignores spaces', () {
    final e =
        GameEngine([
            for (final x in all)
              if (x.packId == 'food' || x.packId == 'daily-grind') x,
          ], random: Random(2))
          ..sentenceBank = bank
          ..verbWords = verbWords
          ..sentenceLevel = sentenceMaster;
    var seen = 0;
    for (final g in [3, 4, 5, 6]) {
      for (var i = 0; i < 200; i++) {
        final t = e.newRound(g) as TypingRound;
        if (!isVerbPackId(t.word!.packId)) continue;
        seen++;
        expect(t.answer1, t.word!.korean1);
        expect(t.answer1, contains(' '));
        expect(isTypedAnswerCorrect(t.answer1, t), isTrue);
        expect(isTypedAnswerCorrect(stripSpaces(t.answer1), t), isTrue);
        if (g >= 5) {
          expect(
            stripSpaces(t.answer1).length,
            lessThanOrEqualTo(GameEngine.maxSentenceSyllables),
            reason: 'syllables, not spaces: ${t.answer1}',
          );
          expect(t.charButtons, isNot(contains(' ')));
        }
      }
    }
    expect(seen, greaterThan(20));
  });
}
