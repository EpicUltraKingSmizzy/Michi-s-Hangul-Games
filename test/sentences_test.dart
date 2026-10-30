import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/logic/sentences.dart';

import 'support/vocab.dart';

/// 해요 present, past, future, and the 안 form ('' = never negated).
const _conjugations = {
  '일어나다': ('일어나요', '일어났어요', '일어날 거예요', '안 일어나요'),
  '씻다': ('씻어요', '씻었어요', '씻을 거예요', '안 씻어요'),
  '닦다': ('닦아요', '닦았어요', '닦을 거예요', '안 닦아요'),
  '입다': ('입어요', '입었어요', '입을 거예요', '안 입어요'),
  '벗다': ('벗어요', '벗었어요', '벗을 거예요', '안 벗어요'),
  '먹다': ('먹어요', '먹었어요', '먹을 거예요', '안 먹어요'),
  '마시다': ('마셔요', '마셨어요', '마실 거예요', '안 마셔요'),
  '쉬다': ('쉬어요', '쉬었어요', '쉴 거예요', '안 쉬어요'),
  '눕다': ('누워요', '누웠어요', '누울 거예요', '안 누워요'),
  '앉다': ('앉아요', '앉았어요', '앉을 거예요', '안 앉아요'),
  '서다': ('서요', '섰어요', '설 거예요', '안 서요'),
  '살다': ('살아요', '살았어요', '살 거예요', '안 살아요'),
  '일하다': ('일해요', '일했어요', '일할 거예요', '일 안 해요'),
  '공부하다': ('공부해요', '공부했어요', '공부할 거예요', '공부 안 해요'),
  '배우다': ('배워요', '배웠어요', '배울 거예요', '안 배워요'),
  '가르치다': ('가르쳐요', '가르쳤어요', '가르칠 거예요', '안 가르쳐요'),
  '읽다': ('읽어요', '읽었어요', '읽을 거예요', '안 읽어요'),
  '쓰다': ('써요', '썼어요', '쓸 거예요', '안 써요'),
  '놀다': ('놀아요', '놀았어요', '놀 거예요', '안 놀아요'),
  '준비하다': ('준비해요', '준비했어요', '준비할 거예요', '준비 안 해요'),
  '썰다': ('썰어요', '썰었어요', '썰 거예요', '안 썰어요'),
  '자르다': ('잘라요', '잘랐어요', '자를 거예요', '안 잘라요'),
  '시작하다': ('시작해요', '시작했어요', '시작할 거예요', '시작 안 해요'),
  '끝나다': ('끝나요', '끝났어요', '끝날 거예요', '안 끝나요'),
  '가다': ('가요', '갔어요', '갈 거예요', '안 가요'),
  '오다': ('와요', '왔어요', '올 거예요', '안 와요'),
  '나오다': ('나와요', '나왔어요', '나올 거예요', '안 나와요'),
  '나가다': ('나가요', '나갔어요', '나갈 거예요', '안 나가요'),
  '들어가다': ('들어가요', '들어갔어요', '들어갈 거예요', '안 들어가요'),
  '들어오다': ('들어와요', '들어왔어요', '들어올 거예요', '안 들어와요'),
  '다니다': ('다녀요', '다녔어요', '다닐 거예요', '안 다녀요'),
  '타다': ('타요', '탔어요', '탈 거예요', '안 타요'),
  '내리다': ('내려요', '내렸어요', '내릴 거예요', '안 내려요'),
  '떠나다': ('떠나요', '떠났어요', '떠날 거예요', '안 떠나요'),
  '돌아오다': ('돌아와요', '돌아왔어요', '돌아올 거예요', '안 돌아와요'),
  '돌아가다': ('돌아가요', '돌아갔어요', '돌아갈 거예요', '안 돌아가요'),
  '걷다': ('걸어요', '걸었어요', '걸을 거예요', '안 걸어요'),
  '달리다': ('달려요', '달렸어요', '달릴 거예요', '안 달려요'),
  '오르다': ('올라요', '올랐어요', '오를 거예요', '안 올라요'),
  '올라가다': ('올라가요', '올라갔어요', '올라갈 거예요', '안 올라가요'),
  '내려가다': ('내려가요', '내려갔어요', '내려갈 거예요', '안 내려가요'),
  '내려오다': ('내려와요', '내려왔어요', '내려올 거예요', '안 내려와요'),
  '지나다': ('지나요', '지났어요', '지날 거예요', ''),
  '지나가다': ('지나가요', '지나갔어요', '지나갈 거예요', '안 지나가요'),
  '움직이다': ('움직여요', '움직였어요', '움직일 거예요', '안 움직여요'),
  '옮기다': ('옮겨요', '옮겼어요', '옮길 거예요', '안 옮겨요'),
  '떨어지다': ('떨어져요', '떨어졌어요', '떨어질 거예요', '안 떨어져요'),
  '돌다': ('돌아요', '돌았어요', '돌 거예요', ''),
  '찾아오다': ('찾아와요', '찾아왔어요', '찾아올 거예요', '안 찾아와요'),
  '보다': ('봐요', '봤어요', '볼 거예요', '안 봐요'),
  '말하다': ('말해요', '말했어요', '말할 거예요', '말 안 해요'),
  '알다': ('알아요', '알았어요', '알 거예요', ''),
  '모르다': ('몰라요', '몰랐어요', '모를 거예요', ''),
  '듣다': ('들어요', '들었어요', '들을 거예요', '안 들어요'),
  '이야기하다': ('이야기해요', '이야기했어요', '이야기할 거예요', '이야기 안 해요'),
  '묻다': ('물어요', '물었어요', '물을 거예요', '안 물어요'),
  '대답하다': ('대답해요', '대답했어요', '대답할 거예요', '대답 안 해요'),
  '부르다': ('불러요', '불렀어요', '부를 거예요', '안 불러요'),
  '설명하다': ('설명해요', '설명했어요', '설명할 거예요', '설명 안 해요'),
  '이해하다': ('이해해요', '이해했어요', '이해할 거예요', ''),
  '믿다': ('믿어요', '믿었어요', '믿을 거예요', '안 믿어요'),
  '느끼다': ('느껴요', '느꼈어요', '느낄 거예요', '안 느껴요'),
  '바라다': ('바라요', '바랐어요', '바랄 거예요', ''),
  '원하다': ('원해요', '원했어요', '원할 거예요', ''),
  '잊다': ('잊어요', '잊었어요', '잊을 거예요', '안 잊어요'),
  '알리다': ('알려요', '알렸어요', '알릴 거예요', '안 알려요'),
  '전하다': ('전해요', '전했어요', '전할 거예요', '안 전해요'),
  '정하다': ('정해요', '정했어요', '정할 거예요', '안 정해요'),
  '결정하다': ('결정해요', '결정했어요', '결정할 거예요', '결정 안 해요'),
  '확인하다': ('확인해요', '확인했어요', '확인할 거예요', '확인 안 해요'),
  '알아보다': ('알아봐요', '알아봤어요', '알아볼 거예요', '안 알아봐요'),
  '찾아보다': ('찾아봐요', '찾아봤어요', '찾아볼 거예요', '안 찾아봐요'),
  '깨닫다': ('깨달아요', '깨달았어요', '깨달을 거예요', ''),
  '주다': ('줘요', '줬어요', '줄 거예요', '안 줘요'),
  '받다': ('받아요', '받았어요', '받을 거예요', '안 받아요'),
  '사다': ('사요', '샀어요', '살 거예요', '안 사요'),
  '팔다': ('팔아요', '팔았어요', '팔 거예요', '안 팔아요'),
  '보내다': ('보내요', '보냈어요', '보낼 거예요', '안 보내요'),
  '찾다': ('찾아요', '찾았어요', '찾을 거예요', '안 찾아요'),
  '잡다': ('잡아요', '잡았어요', '잡을 거예요', '안 잡아요'),
  '넣다': ('넣어요', '넣었어요', '넣을 거예요', '안 넣어요'),
  '빼다': ('빼요', '뺐어요', '뺄 거예요', '안 빼요'),
  '놓다': ('놓아요', '놓았어요', '놓을 거예요', '안 놓아요'),
  '두다': ('둬요', '뒀어요', '둘 거예요', '안 둬요'),
  '담다': ('담아요', '담았어요', '담을 거예요', '안 담아요'),
  '버리다': ('버려요', '버렸어요', '버릴 거예요', '안 버려요'),
  '얻다': ('얻어요', '얻었어요', '얻을 거예요', '안 얻어요'),
  '잃다': ('잃어요', '잃었어요', '잃을 거예요', '안 잃어요'),
  '꺼내다': ('꺼내요', '꺼냈어요', '꺼낼 거예요', '안 꺼내요'),
  '가져오다': ('가져와요', '가져왔어요', '가져올 거예요', '안 가져와요'),
  '모으다': ('모아요', '모았어요', '모을 거예요', '안 모아요'),
  '나누다': ('나눠요', '나눴어요', '나눌 거예요', '안 나눠요'),
  '바꾸다': ('바꿔요', '바꿨어요', '바꿀 거예요', '안 바꿔요'),
  '사용하다': ('사용해요', '사용했어요', '사용할 거예요', '사용 안 해요'),
  '이용하다': ('이용해요', '이용했어요', '이용할 거예요', '이용 안 해요'),
  '구하다': ('구해요', '구했어요', '구할 거예요', '안 구해요'),
  '돕다': ('도와요', '도왔어요', '도울 거예요', '안 도와요'),
  '만나다': ('만나요', '만났어요', '만날 거예요', '안 만나요'),
  '만들다': ('만들어요', '만들었어요', '만들 거예요', '안 만들어요'),
  '기다리다': ('기다려요', '기다렸어요', '기다릴 거예요', '안 기다려요'),
  '좋아하다': ('좋아해요', '좋아했어요', '좋아할 거예요', '안 좋아해요'),
  '사랑하다': ('사랑해요', '사랑했어요', '사랑할 거예요', ''),
  '즐기다': ('즐겨요', '즐겼어요', '즐길 거예요', '안 즐겨요'),
  '싸우다': ('싸워요', '싸웠어요', '싸울 거예요', '안 싸워요'),
  '이기다': ('이겨요', '이겼어요', '이길 거예요', '안 이겨요'),
  '지키다': ('지켜요', '지켰어요', '지킬 거예요', '안 지켜요'),
  '태어나다': ('태어나요', '태어났어요', '태어날 거예요', ''),
  '자라다': ('자라요', '자랐어요', '자랄 거예요', '안 자라요'),
  '결혼하다': ('결혼해요', '결혼했어요', '결혼할 거예요', '결혼 안 해요'),
  '키우다': ('키워요', '키웠어요', '키울 거예요', '안 키워요'),
  '참다': ('참아요', '참았어요', '참을 거예요', '안 참아요'),
  '피하다': ('피해요', '피했어요', '피할 거예요', '안 피해요'),
  '막다': ('막아요', '막았어요', '막을 거예요', '안 막아요'),
  '치다': ('쳐요', '쳤어요', '칠 거예요', '안 쳐요'),
  '열다': ('열어요', '열었어요', '열 거예요', '안 열어요'),
  '걸다': ('걸어요', '걸었어요', '걸 거예요', '안 걸어요'),
  '그리다': ('그려요', '그렸어요', '그릴 거예요', '안 그려요'),
  '짓다': ('지어요', '지었어요', '지을 거예요', '안 지어요'),
  '벌다': ('벌어요', '벌었어요', '벌 거예요', '안 벌어요'),
  '잘하다': ('잘해요', '잘했어요', '잘할 거예요', ''),
  '변하다': ('변해요', '변했어요', '변할 거예요', '안 변해요'),
};

void main() {
  final bank = diskSentences();
  final verbs = {for (final v in bank.verbs) v.dict: v};

  test('sentence data: every noun and verb links to a built-in word', () {
    expect(bank.verbs, hasLength(121));
    expect(bank.nouns.every((n) => n.sections.isNotEmpty), isTrue);
    for (final v in bank.verbs) {
      expect(v.frames, isNotEmpty, reason: v.dict);
      expect(
        SentenceMaker.framesAt(v, sentenceMaster, null),
        isNotEmpty,
        reason: v.dict,
      );
    }
  });

  test('conjugation table: all 121 verbs', () {
    expect(_conjugations.keys.toSet(), verbs.keys.toSet());
    for (final MapEntry(key: dict, value: (present, past, future, negative))
        in _conjugations.entries) {
      final v = verbs[dict]!;
      expect(v.conj.present, present, reason: dict);
      expect(v.conj.past, past, reason: dict);
      expect(v.conj.future, future, reason: dict);
      final neg = switch (v.negate) {
        NegateMode.none => '',
        NegateMode.split =>
          '${v.splitNoun} 안 ${v.conj.present.substring(v.splitNoun.length)}',
        NegateMode.normal => v.conj.negative(Tense.present),
      };
      expect(neg, negative, reason: dict);
    }
  });

  test('particles follow the last sound', () {
    expect(
      [
        for (final n in ['사과', '책', '지하철', '버스', '친구', '동생'])
          particleFor('을', n),
      ],
      ['를', '을', '을', '를', '를', '을'],
    );
    expect(particleFor('이', '동생'), '이');
    expect(particleFor('이', '친구'), '가');
    expect(particleFor('로', '지하철'), '로');
    expect(particleFor('로', '버스'), '로');
    expect(particleFor('로', '방'), '으로');
    expect(particleFor('와', '동생'), '과');
    expect(particleFor('와', '친구'), '와');
  });

  test('every sentence obeys particles, tense/time words and never makes an elder the subject', () {
    final m = SentenceMaker(Random(0));
    var count = 0;
    final dump = StringBuffer();
    for (final v in bank.verbs) {
      for (final s in m.everySentence(v)) {
        count++;
        dump.writeln(
          '${s.korean}\t${s.english}\t${sentenceLevelLabels[s.level]}',
        );
        for (var i = 0; i < s.nouns.length; i++) {
          final unit = s.units[s.units.length - s.nouns.length + i];
          expect(unit, [
            s.nouns[i].korean,
            particleFor(s.frame.slots[i].particle, s.nouns[i].korean),
          ]);
        }
        if (s.time == timeYesterday) {
          expect(s.tense, Tense.past, reason: s.korean);
        }
        if (s.time == timeTomorrow) {
          expect(s.tense, Tense.future, reason: s.korean);
        }
        expect(v.tenses, contains(s.tense));
        if (s.time.isNotEmpty) expect(v.timeWords, isTrue);
        if (s.negated) expect(v.negate, isNot(NegateMode.none));
        for (var i = 0; i < s.nouns.length; i++) {
          if (s.frame.slots[i].particle == '이') {
            expect(s.nouns[i].isElder, isFalse, reason: s.korean);
          }
        }
        expect(s.accepts(s.answerTiles), isTrue, reason: s.korean);
        expect(
          s.decoys.toSet().intersection(s.answerTiles.toSet()),
          isEmpty,
          reason: s.korean,
        );
        expect(s.english, isNot(contains('{')));
        expect(s.english[0], s.english[0].toUpperCase());
      }
    }
    expect(count, greaterThan(100000));
    final out = Platform.environment['SENTENCE_DUMP'];
    if (out != null) {
      File(out).writeAsStringSync('korean\tenglish\tlevel\n$dump');
    }
  });

  test('random rounds stay within their level', () {
    final m = SentenceMaker(Random(7));
    for (final level in [
      sentenceEasy,
      sentenceMedium,
      sentenceHard,
      sentenceMaster,
    ]) {
      for (var i = 0; i < 3000; i++) {
        final v = bank.verbs[i % bank.verbs.length];
        final s = m.make(v, level);
        if (s == null) {
          expect(
            level < sentenceHard && !v.tenses.contains(Tense.present),
            isTrue,
            reason: v.dict,
          );
          continue;
        }
        if (level < sentenceMedium) expect(s.subject, isNull);
        if (level < sentenceHard) {
          expect((s.tense, s.time), (Tense.present, ''));
        }
        if (level < sentenceMaster) {
          expect((s.frame.isCombo, s.negated), (false, false));
        }
        if (s.subject != null) expect(s.frame.hasNounSubject, isFalse);
        expect(
          s.decoys
              .where((d) => d.startsWith('어제') || d.startsWith('내일'))
              .isNotEmpty,
          level >= sentenceHard,
        );
      }
    }
  });

  test('English agrees with subject, tense and 안', () {
    final m = SentenceMaker(Random(0));
    final eat = verbs['먹다']!;
    final apple = bank.nouns.firstWhere((n) => n.korean == '사과');
    final frame = eat.frames.first;
    expect(m.build(eat, frame, [apple]).english, 'I eat apples');
    expect(
      m
          .build(
            eat,
            frame,
            [apple],
            subject: subjectHe,
            tense: Tense.past,
            time: timeYesterday,
          )
          .english,
      'He ate an apple yesterday',
    );
    expect(
      m.build(eat, frame, [apple], subject: subjectShe, negated: true).english,
      "She doesn't eat apples",
    );
    final s = m.build(
      eat,
      frame,
      [apple],
      subject: subjectFriend,
      tense: Tense.future,
      negated: true,
    );
    expect(s.english, "My friend won't eat an apple");
    expect(s.korean, '친구가 사과를 안 먹을 거예요');
    final know = verbs['모르다']!;
    expect(
      m.build(know, know.frames.first, [
        bank.nouns.firstWhere((n) => n.korean == '이유'),
      ], subject: subjectHe).english,
      "He doesn't know the reason",
    );
    final study = verbs['공부하다']!;
    final english = bank.nouns.firstWhere((n) => n.korean == '영어');
    final split = m.build(
      study,
      study.frames.first,
      [english],
      negated: true,
      tense: Tense.past,
    );
    expect(
      (split.korean, split.verbChip, split.fixedBeforeNegation),
      ('영어를 공부 안 했어요', '했어요', '공부'),
    );
  });

  test('units may go in any order, kept together, 안 last', () {
    final m = SentenceMaker(Random(0));
    final eat = verbs['먹다']!;
    final combo = eat.frames.firstWhere((f) => f.isCombo);
    final s = m.build(
      eat,
      combo,
      [
        bank.nouns.firstWhere((n) => n.korean == '식당'),
        bank.nouns.firstWhere((n) => n.korean == '사과'),
      ],
      subject: subjectMe,
      negated: true,
      level: sentenceMaster,
    );
    expect(s.answerTiles, ['저는', '식당', '에서', '사과', '를', '안']);
    expect(s.accepts(['사과', '를', '저는', '식당', '에서', '안']), isTrue);
    expect(s.accepts(['저는', '식당', '사과', '에서', '를', '안']), isFalse);
    expect(s.accepts(['저는', '안', '식당', '에서', '사과', '를']), isFalse);
  });
}
