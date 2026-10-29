import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'pick_format.dart';

import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

String? subj(VocabEntry e) => GameEngine.actionHeroSubject(e);

/// The English subject word an Action Heroes button shows (I / He / She).
String enSubject(String shown) => shown.trim().split(' ').first;

const enFor = {'저는': 'I', '그는': 'He', '그녀는': 'She'};

void main() {
  final vocab = parseIni(File('assets/korean_vocab.ini').readAsStringSync());
  final heroes = vocab.where((e) => e.inPack(actionHeroesBundleId)).toList();

  test('🏃 Action Heroes: 27 cards per pronoun, every card has one', () {
    final counts = <String?, int>{};
    for (final e in heroes) {
      counts[subj(e)] = (counts[subj(e)] ?? 0) + 1;
    }
    expect(counts, {'저는': 27, '그는': 27, '그녀는': 27});
    for (final e in heroes) {
      expect(enSubject(e.english1), enFor[subj(e)], reason: e.english1);
    }
    // Only Action Heroes cards get a subject (the plain 저는 "I" word does not).
    expect(vocab.where((e) => !e.inPack(actionHeroesBundleId)).map(subj).toSet(), {null});
  });

  test('every Action Heroes target gets same-pronoun decoys, in every display mode', () {
    for (final useEmoji in [true, false]) {
      for (final notes in [true, false]) {
        final eng = GameEngine(vocab, random: Random(7))
          ..useEmoji = useEmoji
          ..showBracketNotes = notes;
        for (var round = 0; round < 3; round++) {
          for (final t in heroes) {
            final wrong = eng.getWrongAnswers(t, eng.playList);
            expect(wrong, hasLength(2));
            expect(wrong.map(subj).toSet(), {subj(t)}, reason: t.english1);
            final all = [t, ...wrong];
            for (var i = 0; i < 3; i++) {
              for (var j = i + 1; j < 3; j++) {
                expect(
                  GameEngine.entriesClash(
                    all[i],
                    all[j],
                    useEmoji: useEmoji,
                    showBracketNotes: notes,
                  ),
                  isFalse,
                );
              }
            }
          }
        }
      }
    }
  });

  test('1️⃣ and 2️⃣ rounds (and so 🔀 Shuffle) only differ by the verb', () {
    final hits = {1: 0, 2: 0};
    for (var seed = 0; seed < 300; seed++) {
      final eng = GameEngine(vocab, random: Random(seed));
      for (final game in [1, 2]) {
        final r = legacyRound(eng, game) as ChoiceRound;
        expect(r.options.toSet(), hasLength(3));
        if (game == 1) {
          // Korean prompt, English buttons.
          final p = r.prompt.split(' ').first;
          if (!enFor.containsKey(p) ||
              !heroes.any((h) => h.korean1 == r.prompt || h.korean2 == r.prompt)) {
            continue;
          }
          hits[1] = hits[1]! + 1;
          expect(r.options.map(enSubject).toSet(), {enFor[p]}, reason: '${r.prompt} ${r.options}');
        } else {
          // English prompt, Korean buttons.
          if (!heroes.any((h) => h.english1 == r.prompt)) continue;
          hits[2] = hits[2]! + 1;
          final want = enFor.entries.firstWhere((e) => e.value == enSubject(r.prompt)).key;
          expect(r.options.map((o) => o.split(' ').first).toSet(), {want}, reason: '${r.options}');
        }
      }
    }
    expect(hits[1], greaterThan(5));
    expect(hits[2], greaterThan(5));
  });

  group('fallback when few same-pronoun cards are in play', () {
    VocabEntry hero(String id, String en, String ko) =>
        VocabEntry(sectionName: id, packId: actionHeroesBundleId, english1: en, korean1: ko);
    VocabEntry noun(String id, String en, String ko) =>
        VocabEntry(sectionName: id, packId: 'food', english1: en, korean1: ko, emoji: '');
    final heGoes = hero('h1', 'He Goes', '그는 갑니다');
    final heEats = hero('h2', 'He Eats', '그는 먹습니다');
    final sheGoes = hero('s1', 'She Goes', '그녀는 갑니다');
    final sheEats = hero('s2', 'She Eats', '그녀는 먹습니다');
    final nouns = [noun('n1', 'Apple', '사과'), noun('n2', 'Pear', '배'), noun('n3', 'Rice', '밥')];

    test('one same-pronoun card, then another Action Heroes card', () {
      for (var seed = 0; seed < 50; seed++) {
        final eng = GameEngine([], random: Random(seed));
        final w = eng.getWrongAnswers(heGoes, [heGoes, heEats, sheGoes, sheEats, ...nouns]);
        expect(w.first, heEats);
        expect(subj(w.last), '그녀는');
      }
    });

    test('no other He card: other Action Heroes cards', () {
      final eng = GameEngine([], random: Random(1));
      final w = eng.getWrongAnswers(heGoes, [heGoes, sheGoes, sheEats, ...nouns]);
      expect(w.toSet(), {sheGoes, sheEats});
    });

    test('no other Action Heroes at all: anything in play', () {
      final eng = GameEngine([], random: Random(1));
      final w = eng.getWrongAnswers(heGoes, [heGoes, ...nouns]);
      expect(w, hasLength(2));
      expect(w.every(nouns.contains), isTrue);
    });

    test('other cards are unaffected (still same pack first)', () {
      for (var seed = 0; seed < 30; seed++) {
        final eng = GameEngine([], random: Random(seed));
        final w = eng.getWrongAnswers(nouns[0], [heGoes, heEats, sheGoes, ...nouns]);
        expect(w.toSet(), {nouns[1], nouns[2]});
      }
    });
  });
}
