import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

import 'support/vocab.dart';

TypingRound typing(String a1, [String a2 = '']) => TypingRound(
  prompt: 'x',
  promptIsKorean: false,
  answer1: a1,
  answer2: a2,
  answerIsKorean: true,
  showHintAtStart: false,
  repetitions: 1,
  charButtons: const [],
);

void main() {
  final vocab = diskVocab();

  group('answer checking', () {
    test('spaces are ignored and Korean2 is accepted', () {
      final r = typing('저는갑니다', '제가갑니다');
      expect(isTypedAnswerCorrect('저는 갑니다', r), isTrue);
      expect(isTypedAnswerCorrect(' 저는갑니다 ', r), isTrue);
      expect(isTypedAnswerCorrect('제가 갑니다', r), isTrue);
      expect(isTypedAnswerCorrect('저는 가요', r), isFalse);
      expect(isTypedAnswerCorrect('', r), isFalse);
      expect(isTypedAnswerCorrect('   ', typing('가', '')), isFalse);
    });
    test('helper buttons must build Item1', () {
      final r = typing('고양이', '냥이');
      expect(isHelperAnswerComplete('고양', r), isFalse);
      expect(isHelperAnswerComplete('고양이', r), isTrue);
      expect(isHelperAnswerComplete('냥이', r), isFalse);
    });
  });

  test('typing round answers come from Korean1/Korean2 with spaces removed (swap uses tmp)', () {
    const e = VocabEntry(sectionName: 's', english1: 'I go', korean1: '저는 갑니다', korean2: '제가 가요');
    final seen = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      final eng = GameEngine([e, e, e], random: Random(seed));
      final r = eng.createTextBoxGame(e);
      expect({r.answer1, r.answer2}, {'저는갑니다', '제가가요'});
      seen.add(r.answer1);
    }
    expect(seen.length, 2, reason: 'both answers should sometimes be the official one');
  });

  test('scramble targets (5 & 6) respect the 2..10 length filter incl. Korean2', () {
    final list = [
      const VocabEntry(sectionName: 'a', english1: 'long', korean1: '가나다라마바사아자차카타', korean2: '가나'),
      const VocabEntry(sectionName: 'b', english1: 'short', korean1: '가'),
      const VocabEntry(
        sectionName: 'c',
        english1: 'longer',
        korean1: '가나다라마바사아자차카타파',
        korean2: '가나다라마바사아자차카타하',
      ),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final eng = GameEngine(list, random: Random(seed));
      final r = eng.newRound(5) as TypingRound;
      // Only entry 'a' qualifies (via its Korean2).
      expect(r.prompt, 'long');
    }
  });

  test('getWrongCharacters: intended count, no answer chars, never hangs', () {
    final eng = GameEngine(vocab, random: Random(3));
    final target = vocab.firstWhere((e) => e.korean1 == '고양이');
    final wrong = eng.getWrongCharacters('고양이', target, vocab);
    expect(wrong.length, 3);
    for (final c in wrong) {
      expect('고양이'.contains(c), isFalse);
    }
    final long = eng.getWrongCharacters('그녀는요리합니다', target, vocab);
    expect(long.length, 8);
    expect(long.toSet().length, long.length);

    // Tiny vocabulary: returns what it can instead of looping forever.
    const tiny = [
      VocabEntry(sectionName: '1', english1: 'a', korean1: '가'),
      VocabEntry(sectionName: '2', english1: 'b', korean1: '나'),
      VocabEntry(sectionName: '3', english1: 'c', korean1: '가나'),
    ];
    final eng2 = GameEngine(tiny, random: Random(1));
    expect(eng2.getWrongCharacters('가나', tiny[2], tiny), isEmpty);
    final r = eng2.newRound(6) as TypingRound;
    expect(r.charButtons, isNotEmpty);
  });

  test('decoys prefer the same Word Pack and phrase-ness', () {
    final eng = GameEngine(vocab, random: Random(5));
    final target = vocab.firstWhere((e) => e.packId == 'food' && e.alsoPacks.isEmpty);
    for (var i = 0; i < 20; i++) {
      final wrong = eng.getWrongAnswers(target, vocab);
      expect(wrong.length, 2);
      expect(wrong.every((w) => w.inPack('food') && w.sectionName != target.sectionName), isTrue);
    }
    final phrase = vocab.firstWhere((e) => e.isFullPhrase);
    final pw = eng.getWrongAnswers(phrase, vocab);
    expect(pw.every((w) => w.isFullPhrase), isTrue);
  });

  test('multiple choice never shows two identical or two correct options', () {
    final eng = GameEngine(vocab, random: Random(11));
    final leg = vocab.firstWhere((e) => e.english1 == 'Leg');
    final arm = vocab.firstWhere((e) => e.english1 == 'Arm');
    for (var i = 0; i < 200; i++) {
      for (final t in [leg, arm]) {
        final wrong = eng.getWrongAnswers(t, vocab);
        expect(wrong.length, 2);
        expect(wrong.any((w) => GameEngine.entriesClash(w, t)), isFalse);
      }
    }
    for (final game in [1, 2]) {
      for (var i = 0; i < 2000; i++) {
        final r = legacyRound(eng, game) as ChoiceRound;
        expect(r.options.toSet().length, 3, reason: '${r.prompt} ${r.options}');
      }
    }
  });

  test('Sino and native numbers never appear as twin options; typing accepts both', () {
    final eng = GameEngine(vocab, random: Random(5));
    final nums = vocab.where((e) => e.english1 == '4').toList();
    expect(nums.length, 2);
    for (var i = 0; i < 300; i++) {
      for (final t in nums) {
        expect(
          eng.getWrongAnswers(t, vocab).any((w) => w.english1 == '4' || w.english1 == 'Yes'),
          isFalse,
        );
      }
    }
    final native4 = nums.firstWhere((e) => e.packId == 'native');
    final r = eng.createTextBoxGame(native4, showHintAtStart: false);
    expect(isTypedAnswerCorrect('넷', r), isTrue);
    expect(isTypedAnswerCorrect('네', r), isTrue);
    expect(isTypedAnswerCorrect('사', r), isTrue); // the prompt "4" is genuinely ambiguous
    expect(isTypedAnswerCorrect('오', r), isFalse);
  });

  test('no target repeats within the last 5 rounds of a game', () {
    final eng = GameEngine(vocab.take(8).toList(), random: Random(9));
    final recent = <String>[];
    for (var i = 0; i < 100; i++) {
      final t = (eng..currentGame = 3).getGameTarget();
      expect(recent.contains(t.sectionName), isFalse);
      recent.add(t.sectionName);
      if (recent.length > 5) recent.removeAt(0);
    }
  });

  test('every game produces sensible rounds over the real vocab', () {
    final eng = GameEngine(vocab, random: Random(42));
    for (var game = 1; game <= 8; game++) {
      for (var i = 0; i < 300; i++) {
        final r = legacyRound(eng, game);
        if (r is ChoiceRound) {
          expect(r.options.length, 3);
          expect(r.options, contains(r.correctAnswer));
        } else {
          r as TypingRound;
          expect(r.answer1, isNotEmpty);
          if (game == 3) expect(r.repetitions, GameEngine.defaultGame3Repetitions);
          if (game == 5) {
            expect(r.charButtons.length, r.answer1.replaceAll(' ', '').length);
          }
          if (game == 6) {
            expect(r.charButtons.length, greaterThan(r.answer1.length));
          }
        }
      }
    }
  });

  test('number games stay within their ranges', () {
    final eng = GameEngine(vocab, random: Random(7));
    for (var i = 0; i < 300; i++) {
      final r = eng.newRound(8);
      final digits = r is ChoiceRound
          ? (r.promptIsKorean ? r.correctAnswer : r.prompt)
          : ((r as TypingRound).answerIsKorean ? r.prompt : r.answer1);
      final n = int.parse(digits);
      expect(n, inInclusiveRange(1, 99));
    }
    for (var i = 0; i < 300; i++) {
      final r = eng.newRound(7);
      final digits = r is ChoiceRound
          ? (r.promptIsKorean ? r.correctAnswer : r.prompt)
          : ((r as TypingRound).answerIsKorean ? r.prompt : r.answer1);
      expect(int.parse(digits), inInclusiveRange(1, 999999));
    }
  });
}
