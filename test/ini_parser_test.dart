import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

void main() {
  test('parses sections, keys, comments and booleans', () {
    const ini =
        '\uFEFF; a comment\n'
        '# another comment\n'
        '[Entry_1]\r\n'
        'English1 = Cat\r\n'
        'KOREAN1=고양이\n'
        'korean2 = 냥이\n'
        'Emoji = 🐱\n'
        'Category = Animal\n'
        'IsFullPhrase = True\n'
        'not a key value line\n'
        '\n'
        '[Entry_2]\n'
        'english1 = a = b\n'
        'english2 = Second\n'
        'korean1 = 가\n'
        'isfullphrase = yes\n';
    final e = parseIni(ini);
    expect(e.length, 2);
    expect(e[0].sectionName, 'Entry_1');
    expect(e[0].english1, 'Cat');
    expect(e[0].korean1, '고양이');
    expect(e[0].korean2, '냥이');
    expect(e[0].emoji, '🐱');
    expect(e[0].packId, 'phrases'); // full phrases live in Handy Phrases
    expect(e[0].isFullPhrase, isTrue);
    expect(e[1].english1, 'a = b'); // split on the first '=' only
    expect(e[1].english2, 'Second');
    expect(e[1].isFullPhrase, isFalse); // "yes" isn't a .NET boolean
    expect(e[1].packId, 'grabbag');
  });

  test('keys before any section are ignored', () {
    expect(parseIni('english1 = x\nkorean1 = y\n'), isEmpty);
  });

  test("parses the user's bundled vocab file", () {
    final entries = parseIni(File('assets/korean_vocab.ini').readAsStringSync());
    // + 412 top-500 nouns (v9) − 3 family names, now seeded My Words (v13)
    expect(entries.length, 566 + 412 - 3 + 24); // v15: +24 🗨️ Everyday Talk
    expect(entries.first.sectionName, 'Entry_00000');
    expect(entries.first.english1, 'Spider');
    expect(entries.first.korean1, '거미');
    expect(entries.every((e) => e.korean1.isNotEmpty && e.english1.isNotEmpty), isTrue);
    expect(entries.where((e) => e.isFullPhrase).length, 24 + 24);

    // Every entry has exactly one home pack (shared words list extra packs
    // in alsoPacks; see shared_packs_test.dart).
    final counts = <String, int>{};
    for (final e in entries) {
      counts.update(e.packId, (v) => v + 1, ifAbsent: () => 1);
    }
    expect(counts.values.fold(0, (a, b) => a + b), 566 + 412 - 3 + 24);
    expect(counts, {
      'everyday-talk': 24,
      'phrases': 24,
      'food': 78,
      'home': 53,
      'outside': 53,
      'time': 36,
      'people': 25, // v13: −3 family names, now seeded My Words
      'animals': 24,
      'body': 29,
      'emotions': 11,
      'verbs': 81,
      'numbers': 50,
      'native': 20,
      'colours': 13,
      'grabbag': 68,
      'whos-who': 32,
      'tick-tock': 37,
      'here-there-everywhere': 34,
      'heart-and-body': 29,
      'stuff-and-nature': 26,
      'showtime': 33,
      'school-and-hustle': 36,
      'big-words': 68,
      'big-brain-ideas': 56,
      'how-things-are': 59,
    });
    expect(builtInBundles.map((b) => b.id).toSet(), counts.keys.toSet());
  });

  test('Handy Phrases have no emoji; Emotions holds the feeling words', () {
    final entries = parseIni(File('assets/korean_vocab.ini').readAsStringSync());
    final phrases = entries.where((e) => e.packId == 'phrases').toList();
    expect(phrases, hasLength(24));
    expect(phrases.where((e) => e.emoji.isNotEmpty), isEmpty);
    final emoji = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    expect(phrases.where((e) => emoji.hasMatch(e.english1)), isEmpty);
    expect(entries.where((e) => e.packId == 'emotions').map((e) => e.korean1).toSet(), {
      '스트레스',
      '사랑',
      '감탄하다',
      '끌리다',
      '울음',
      '흐느끼다',
      '웃다',
      '웃음',
      '화나다',
      '놀라다',
      '애정',
    });
    expect(builtInBundles.where((b) => b.id == 'words'), isEmpty);
    // Pack emojis are unique.
    expect(builtInBundles.map((b) => b.emoji).toSet(), hasLength(builtInBundles.length));
  });

  test('vocab corrections are in the bundled copy', () {
    // The original word list (the top-500 noun packs reuse a few English
    // words, e.g. 부모 "Parents" next to 부모님).
    final entries = parseIni(File('assets/korean_vocab.ini').readAsStringSync())
        .where((e) => !defaultOffBundles.difference({phrasesBundleId}).contains(e.packId))
        .toList();
    VocabEntry byEn(String en) => entries.singleWhere((e) => e.english1 == en);
    expect(byEn('Spiderweb').korean1, '거미줄');
    expect(byEn('Cat').korean2, '');
    expect(byEn('Wing').korean1, '날개');
    expect((byEn('Plate').korean1, byEn('Plate').korean2), ('접시', ''));
    expect(byEn('Earth').korean1, '지구');
    expect((byEn('Alcohol').korean1, byEn('Alcohol').korean2), ('술', ''));
    expect(byEn('Broccoli').korean1, '브로콜리');
    expect(byEn('Onion').korean1, '양파');
    expect(byEn('Cherry').korean1, '체리');
    expect(byEn('Orange (fruit)').korean1, '오렌지');
    expect((byEn('Sword').korean1, byEn('Sword').korean2), ('검', '칼'));
    expect(byEn('last week').korean1, '지난주');
    expect(byEn('You (formal)').korean1, '당신은');
    expect(byEn('I listen to music.').korean1, '저는 음악을 들어요');
    expect(byEn('It is here.').korean1, '여기예요');
    expect(byEn('October').korean1, '시월');
    expect(byEn('Burrito').korean1, '부리토');
    expect(byEn('He Needs').korean1, '그는 필요로 합니다');
    // The family names are no longer built in (v13): they are seeded My
    // Words, spelled the family's way.
    for (final name in ['Michi', 'Michel-André', 'Nicole']) {
      expect(entries.where((e) => e.english1 == name), isEmpty);
    }
    expect(seededMyWords.map((e) => (e.english1, e.korean1)), [
      ('Michi', '미시'),
      ('Michel-André', '미셸안드레'),
      ('Nicole', '다정전'),
    ]);
    expect((byEn('Lock').korean1, byEn('Lock').korean2, byEn('Lock').emoji), ('자물쇠', '', '🔒'));
    expect((byEn('To lock').korean1, byEn('To lock').packId), ('잠그다', 'grabbag'));
    expect((byEn('Cow').korean1, byEn('Cow').korean2), ('소', '암소'));
    expect((byEn('Idea').korean1, byEn('Idea').emoji), ('아이디어', '💡'));
    expect((byEn('Thought').korean1, byEn('Thought').emoji), ('생각', '💭'));
    final wife = entries.singleWhere((e) => e.sectionName == 'Entry_00259');
    expect((wife.korean1, wife.korean2), ('아내', '부인'));
    expect(byEn('Flower').emoji, '🌸');
    expect(byEn('Pencil').emoji, '✏️');
    expect(byEn('Clock').emoji, '⏰');
    expect(byEn('Sword').emoji, '🗡️');
    expect(byEn('Burrito').emoji, '🌯');
    expect(
      parseIni(File('assets/korean_vocab.ini').readAsStringSync())
          .where((e) => e.emoji.isNotEmpty)
          .length,
      66 + 124 + 2 + 12 + 7 + 27 - 1 + 20 - 7 + 67 + 36 - 1,
    ); // + Lock, Thought, colours, weekdays, round 5; − Appointment; + round 8; − 7 Handy Phrases emojis; + 67 emoji-only English1 moved to Emoji (v8); + 36 noun emojis (v9); − 💪 Strength (v10)
    // Round 4.
    expect((byEn('Older Brother').korean1, byEn('Older Brother').korean2), ('형', '오빠'));
    expect((byEn('Older Sister').korean1, byEn('Older Sister').korean2), ('누나', '언니'));
    expect(byEn('Younger Brother').korean1, '남동생');
    expect(byEn('Younger Sister').korean1, '여동생');
    expect((byEn('Brothers').korean1, byEn('Sisters').korean1), ('형제', '자매'));
    expect(byEn('Bridge').packId, 'outside');
    expect((byEn('Orange (fruit)').korean1, byEn('Orange (color)').korean1), ('오렌지', '주황색'));
    expect((byEn('Red').korean1, byEn('Red').korean2, byEn('Red').emoji), ('빨간색', '빨강', '🟥'));
    expect(byEn('Color').packId, 'colours');
    expect((byEn('Tuesday').korean1, byEn('Tuesday').emoji), ('화요일', '☀️3️⃣'));
    expect(byEn('Sunday').packId, byEn('January').packId);
    final native = entries.where((e) => e.packId == 'native').toList();
    expect(native.map((e) => e.english1), [for (var i = 1; i <= 20; i++) '$i']);
    expect((native[0].korean1, native[0].korean2, native[19].korean2), ('하나', '한', '스무'));
    expect((byEn('I Go').korean1, byEn('I Go').korean2), ('저는 갑니다', '저는 가요'));
    expect(byEn('She Writes').korean2, '그녀는 써요');
    expect(byEn('Goodbye (you are leaving)').korean2, '안녕히 계십시오');
    final sentences = entries.where((e) => e.isFullPhrase || e.packId == 'verbs');
    expect(sentences.where((e) => e.korean2.isEmpty).map((e) => e.english1), ['You don’t know?']);
    expect((byEn('Appointment').korean1, byEn('Appointment').emoji), ('약속', ''));
    // Round 5 regrouping and additions.
    for (final w in [
      'January',
      'Month',
      'Sunday',
      'Year',
      'today',
      'last week',
      'before',
      'Moment',
      'Time',
      'Yesterday',
      'Now',
    ]) {
      expect(byEn(w).packId, 'time', reason: w);
    }
    for (final w in ['Older Sister', 'Brothers', 'dad', 'Family']) {
      expect(byEn(w).packId, 'people', reason: w);
    }
    expect(entries.singleWhere((e) => e.sectionName == 'Entry_00403').packId, 'people'); // 부모님
    expect(entries.singleWhere((e) => e.sectionName == 'Entry_00259').packId, 'people'); // Wife
    // v11: the job and non-family people words went to Who's Who (off by default).
    for (final w in [
      'staff',
      'Stylist',
      'Designer',
      'Model',
      'Citizen',
      'Person',
      'Friend',
      'Men',
    ]) {
      expect(entries.where((e) => e.english1 == w), isEmpty, reason: w);
    }
    for (final w in ['Cat', 'Cow', 'Pig', 'Spider']) {
      expect(byEn(w).packId, 'animals', reason: w);
    }
    for (final w in ['Eye', 'Ear', 'Arm', 'Leg', 'Foot']) {
      expect(byEn(w).packId, 'body', reason: w);
    }
    // Round 8: new Body Parts and Animals.
    for (final w in [
      'Nose', 'Mouth', 'Hand', 'Tooth', 'Tongue', 'Heart', 'Bone', 'Hair', 'Finger', 'Head', //
      'Face', 'Neck', 'Shoulder', 'Knee', 'Toe', 'Elbow', 'Chest', 'Lungs', 'Lips',
    ]) {
      expect(byEn(w).packId, 'body', reason: w);
    }
    for (final w in [
      'Tiger',
      'Bear',
      'Rabbit',
      'Monkey',
      'Chicken',
      'Elephant',
      'Snake',
      'Duck',
      'Lion',
      'Frog',
    ]) {
      expect(byEn(w).packId, 'animals', reason: w);
    }
    expect((byEn('Tooth').korean1, byEn('Tooth').korean2, byEn('Tooth').emoji), ('이', '치아', '🦷'));
    expect((byEn('Lungs').korean1, byEn('Lungs').emoji), ('폐', '🫁'));
    expect((byEn('Lips').korean1, byEn('Lips').emoji), ('입술', ''));
    expect((byEn('Tiger').korean1, byEn('Tiger').emoji), ('호랑이', '🐯'));
    expect((byEn('Frog').korean1, byEn('Frog').emoji), ('개구리', '🐸'));
    // Clashing spares stay out.
    for (final w in ['Back', 'Belly', 'Turtle']) {
      expect(entries.where((e) => e.english1 == w), isEmpty, reason: w);
    }
    expect(entries.where((e) => e.korean1 == '쥐'), isEmpty);
    expect((byEn('Week').korean1, byEn('Week').korean2, byEn('Week').emoji), ('주', '일주일', ''));
    expect((byEn('Weekend').emoji, byEn('Restaurant').emoji), ('', ''));
    expect(byEn('Restaurant').packId, 'outside');
    expect((byEn('Morning').korean1, byEn('Morning').emoji), ('아침', '🌅'));
    expect(
      (byEn('Nice to meet you').korean1, byEn('Nice to meet you').korean2),
      ('만나서 반가워요', '만나서 반갑습니다'),
    );
    expect(byEn('Can I pay by card?').packId, 'phrases');
    expect(entries.where((e) => e.english1 == '5000').single.korean1, '오천');
    for (final vetoedNew in [
      "O'clock",
      "I can't speak Korean well",
      'Thanks for the meal (before eating)',
    ]) {
      expect(entries.where((e) => e.english1 == vetoedNew), isEmpty);
    }
    for (final vetoed in ['Japchae', 'Show', 'Month', 'Year', 'Words', 'Green onion']) {
      expect(byEn(vetoed).emoji, '', reason: vetoed);
    }
    final all = entries.expand((e) => [e.korean1, e.korean2]).join(' ');
    for (final bad in ['편물', '양피', '브로꼴리', '지넌주', '당신음', '듣어요', '십월', '이승', '가무']) {
      expect(all.contains(bad), isFalse, reason: bad);
    }
  });

  test('Pack = key (id or name) wins; legacy Category = still converts', () {
    final e = parseIni(
      '[A]\nenglish1 = a\nkorean1 = 가\npack = Food\n'
      '[B]\nenglish1 = b\nkorean1 = 나\nPack = animals\ncategory = Time\n'
      '[C]\nenglish1 = c\nkorean1 = 다\ncategory = time\n'
      '[D]\nenglish1 = d\nkorean1 = 라\ncategory = Nope\n'
      '[E]\nenglish1 = e\nkorean1 = 마\npack = nonsense\ncategory = Animal\n',
    );
    expect(e.map((x) => x.packId), ['food', 'animals', 'time', 'grabbag', 'animals']);
  });
}
