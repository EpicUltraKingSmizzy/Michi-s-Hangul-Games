import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vocab.dart';

final _all = diskVocab();
final _talk = _all.where((e) => e.packId == 'everyday-talk').toList();

VocabEntry _byKorean(String k, [String? pack]) =>
    _all.singleWhere((e) => e.korean1 == k && (pack == null || e.packId == pack));

Future<AppState> _fresh([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState();
  await s.load();
  return s;
}

/// A typing round (✍️ / 🧠 / scramble style) whose English prompt is [target].
TypingRound _typing(GameEngine g, VocabEntry target) {
  g.useEmoji = false;
  return g.createTextBoxGame(target, showHintAtStart: false);
}

/// Checks a look-alike pair [a] / [b] (same English once notes are hidden).
void _checkPair(VocabEntry a, VocabEntry b) {
  final both = [a, b];
  // Notes off: either Korean (any form) is right for either prompt.
  final off = GameEngine(both, random: Random(1))..showBracketNotes = false;
  expect(off.shownEnglish(a), off.shownEnglish(b));
  for (final t in both) {
    final r = _typing(off, t);
    for (final k in [a.korean1, a.korean2, b.korean1, b.korean2].where((k) => k.isNotEmpty)) {
      expect(isTypedAnswerCorrect(k, r), isTrue, reason: '${t.english1}: $k');
    }
  }
  // Notes on: only the matching card's Korean.
  final on = GameEngine(both, random: Random(1))..showBracketNotes = true;
  for (final t in both) {
    final other = t == a ? b : a;
    final r = _typing(on, t);
    expect(isTypedAnswerCorrect(t.korean1, r), isTrue);
    expect(isTypedAnswerCorrect(other.korean1, r), isFalse, reason: t.english1);
  }
  // Multiple choice / 🔗 Link Up: never both in one round with notes off.
  for (final emoji in [true, false]) {
    expect(
      GameEngine.entriesClash(a, b, useEmoji: emoji, showBracketNotes: false),
      isTrue,
      reason: 'emoji $emoji',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🗨️ Everyday Talk', () {
    test('pack: 24 full phrases, appended ids, no emoji', () {
      final b = builtInBundleById('everyday-talk')!;
      expect((b.emoji, b.name), ('🗨️', 'Everyday Talk'));
      expect(b.blurb, 'Handy everyday phrases for meals, shops & chatting.');
      expect(_talk, hasLength(24));
      expect(_talk.every((e) => e.isFullPhrase && e.emoji.isEmpty), isTrue);
      expect(_talk.first.sectionName, 'Entry_00980');
      expect(_talk.last.sectionName, 'Entry_01003');
      expect(_byKorean('더워요').korean2, '덥습니다');
      // 🗨️ is nobody else's emoji.
      expect(builtInBundles.where((x) => x.emoji == '🗨️'), hasLength(1));
      expect(_all.where((e) => e.emoji.contains('🗨')), isEmpty);
    });

    test('no Korean or English overlaps anything already in the INI', () {
      final others = _all.where((e) => e.packId != 'everyday-talk');
      final ko = {
        for (final e in others) ...[e.korean1, e.korean2].map(stripSpaces),
      }..remove('');
      final en = {for (final e in others) stripBracketNotes(e.english1).toLowerCase()};
      for (final e in _talk) {
        expect(ko.intersection({stripSpaces(e.korean1), stripSpaces(e.korean2)}), isEmpty);
        expect(
          en.contains(stripBracketNotes(e.english1).toLowerCase()),
          isFalse,
          reason: e.english1,
        );
      }
    });

    test('off on fresh installs and for players updating', () async {
      expect(defaultOffBundles, contains('everyday-talk'));
      final s = await _fresh();
      expect(s.enabledBundles, isNot(contains('everyday-talk')));
      final old = builtInBundles.map((b) => b.id).where((id) => id != 'everyday-talk').toList();
      final upd = await _fresh({
        'known_bundles': old,
        'enabled_bundles': ['food', 'phrases'],
      });
      expect(upd.enabledBundles, isNot(contains('everyday-talk')));
      expect(upd.enabledBundles, containsAll(['food', 'phrases']));
      expect(upd.wordsInPack('everyday-talk'), hasLength(24));
    });
  });

  group('look-alikes with 📑 Bracket notes off', () {
    test('잘 먹겠습니다 / 잘 먹었습니다: "Thank you for the meal"', () {
      final a = _byKorean('잘 먹겠습니다'), b = _byKorean('잘 먹었습니다');
      expect(stripBracketNotes(a.english1), 'Thank you for the meal');
      _checkPair(a, b);
    });

    test('안녕히 가세요 / 안녕히 계세요: "Goodbye"', () {
      _checkPair(_byKorean('안녕히 가세요'), _byKorean('안녕히 계세요'));
    });

    test('영 / 공: "0"', () {
      _checkPair(_byKorean('영'), _byKorean('공', 'numbers'));
    });
  });
}
