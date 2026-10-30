import 'dart:math';

import '../models/vocab_entry.dart';
import 'ini_parser.dart' show parseSections;

/// 🏗️ Sentence Builder data: `assets/sentences/nouns.tsv` (which built-in
/// words sentences may use, with their English) and
/// `assets/sentences/verbs.ini` (each verb's sentence shapes). The file
/// headers explain the formats.
const String sentenceNounsAsset = 'assets/sentences/nouns.tsv';
const String sentenceVerbsAsset = 'assets/sentences/verbs.ini';

enum Tense { present, past, future }

/// ⚙️ Options 🤖 Sentence difficulty steps.
const sentenceLevelLabels = ['Easy', 'Medium', 'Hard', 'Master'];
const int sentenceEasy = 0, sentenceMedium = 1, sentenceHard = 2, sentenceMaster = 3;

// ------------------------------------------------------------------ Hangul

const _hangulBase = 0xAC00;

bool _isSyllable(int c) => c >= 0xAC00 && c <= 0xD7A3;

/// (initial, medial, final) of the last character, or null if not Hangul.
(int, int, int)? _lastJamo(String s) {
  if (s.isEmpty) return null;
  final c = s.codeUnitAt(s.length - 1);
  if (!_isSyllable(c)) return null;
  final x = c - _hangulBase;
  return (x ~/ 588, (x % 588) ~/ 28, x % 28);
}

String _syllable(int i, int m, int f) => String.fromCharCode(_hangulBase + (i * 21 + m) * 28 + f);

String _replaceLast(String s, String last) => s.substring(0, s.length - 1) + last;

/// True when [word] ends in a consonant (받침).
bool hasBatchim(String word) => (_lastJamo(word)?.$3 ?? 0) != 0;

bool _endsInRieul(String word) => _lastJamo(word)?.$3 == 8;

// ------------------------------------------------------------ conjugation

/// The regular polite 해요 form of a dictionary-form verb (가다 → 가요).
String regularPolite(String dict) {
  final stem = dict.substring(0, dict.length - 1);
  if (stem.endsWith('하')) return '${_replaceLast(stem, '해')}요';
  final (i, m, f) = _lastJamo(stem)!;
  if (f != 0) return stem + (m == 0 || m == 8 ? '아요' : '어요');
  switch (m) {
    case 0 || 1 || 4 || 5 || 6: // ㅏ ㅐ ㅓ ㅔ ㅕ
      return '$stem요';
    case 8: // ㅗ → ㅘ
      return '${_replaceLast(stem, _syllable(i, 9, 0))}요';
    case 13: // ㅜ → ㅝ
      return '${_replaceLast(stem, _syllable(i, 14, 0))}요';
    case 20: // ㅣ → ㅕ
      return '${_replaceLast(stem, _syllable(i, 6, 0))}요';
    case 11: // ㅚ → ㅙ
      return '${_replaceLast(stem, _syllable(i, 10, 0))}요';
    case 18: // ㅡ drops: ㅏ/ㅗ before it → ㅏ, else ㅓ
      final prev = stem.length > 1 ? _lastJamo(stem.substring(0, stem.length - 1)) : null;
      final v = prev != null && (prev.$2 == 0 || prev.$2 == 8) ? 0 : 4;
      return '${_replaceLast(stem, _syllable(i, v, 0))}요';
    default:
      return '$stem어요';
  }
}

/// A verb's four forms used in sentences.
class Conjugation {
  final String dict;

  /// The 해요 form ([politeOverride] from the Verb Pack, else the rules).
  final String present;
  Conjugation(this.dict, {String politeOverride = ''})
    : present = politeOverride.isNotEmpty ? politeOverride : regularPolite(dict);

  String get _stem => dict.substring(0, dict.length - 1);

  /// 했어요 / 먹었어요: ㅆ added to the 해요 form's last syllable, then 어요.
  String get past {
    final x = present.substring(0, present.length - 1);
    final (i, m, _) = _lastJamo(x)!;
    return '${_replaceLast(x, _syllable(i, m, 20))}어요';
  }

  /// (으)ㄹ 거예요. ㄷ/ㅂ/ㅅ irregulars (known by a Polite form the rules
  /// don't give) become 들을 / 누울 / 지을.
  String get future {
    final stem = _stem;
    final (i, m, f) = _lastJamo(stem)!;
    final irregular = present != regularPolite(dict);
    String base;
    if (stem.endsWith('하')) {
      base = _replaceLast(stem, '할');
    } else if (f == 0) {
      base = _replaceLast(stem, _syllable(i, m, 8));
    } else if (f == 8) {
      base = stem;
    } else if (irregular && f == 7) {
      base = '${_replaceLast(stem, _syllable(i, m, 8))}을';
    } else if (irregular && f == 17) {
      base = '${_replaceLast(stem, _syllable(i, m, 0))}울';
    } else if (irregular && f == 19) {
      base = '${_replaceLast(stem, _syllable(i, m, 0))}을';
    } else {
      base = '$stem을';
    }
    return '$base 거예요';
  }

  String form(Tense t) => switch (t) {
    Tense.present => present,
    Tense.past => past,
    Tense.future => future,
  };

  /// 안 + the form (안 먹어요).
  String negative(Tense t) => '안 ${form(t)}';
}

/// A polite verb form as the two 🏗️ Hard/Master pieces: the stem with its
/// tense, then the polite ending. 먹었 + 어요, 먹을 거 + 예요, 먹 + 어요 /
/// 앉 + 아요 when the ending is its own syllable, else 가 + 요 / 공부해 + 요.
List<String> splitVerbForm(String form) {
  if (form.endsWith(' 거예요')) return [form.substring(0, form.length - 2), '예요'];
  for (final e in ['어요', '아요']) {
    if (form.length > e.length && form.endsWith(e)) {
      return [form.substring(0, form.length - e.length), e];
    }
  }
  return [form.substring(0, form.length - 1), '요'];
}

/// Wrong polite endings offered as 🏗️ Master decoys (none for a bare 요).
const verbEndingDecoys = {'어요': '아요', '아요': '어요', '예요': '이에요'};

// ---------------------------------------------------------------- particles

/// Particle keys used in verbs.ini: 을 (을/를), 이 (이/가), 에, 에서, 와 (와/과),
/// 로 ((으)로).
const particleKeys = ['을', '이', '에', '에서', '와', '로'];

/// [key] in the form that fits [noun]'s last sound (사과를, 책을, 지하철로).
String particleFor(String key, String noun) {
  final b = hasBatchim(noun);
  return switch (key) {
    '을' => b ? '을' : '를',
    '이' => b ? '이' : '가',
    '와' => b ? '과' : '와',
    '로' => b && !_endsInRieul(noun) ? '으로' : '로',
    '은' => b ? '은' : '는',
    _ => key,
  };
}

/// The other form of [key] (wrong for [noun]), or null when it has one form.
String? wrongParticleForm(String key, String noun) {
  final b = hasBatchim(noun);
  return switch (key) {
    '을' => b ? '를' : '을',
    '이' => b ? '가' : '이',
    '와' => b ? '와' : '과',
    '로' => b && !_endsInRieul(noun) ? '로' : '으로',
    _ => null,
  };
}

/// Wrong-job particles offered as decoys for each particle.
const roleDecoys = {
  '을': ['이', '에'],
  '에': ['에서', '이'],
  '에서': ['에', '을'],
  '와': ['을', '에'],
  '로': ['이', '을'],
  '이': ['을', '에'],
};

// -------------------------------------------------------------------- data

/// One row of nouns.tsv.
class SentenceNoun {
  final String korean;
  final String pack;
  final Set<String> kinds;
  final String english;
  final String general;
  final String at;
  final String to;
  final bool plural;

  /// 'he' / 'she': only with a male / female owner (형, 아내 / 남편).
  final String owner;

  /// Section names of the built-in word(s) this row is (set by
  /// [SentenceBank.link]; food has two 파 cards).
  Set<String> sections = {};

  SentenceNoun({
    required this.korean,
    required this.pack,
    required this.kinds,
    required this.english,
    this.general = '',
    this.at = '',
    this.to = '',
    this.plural = false,
    this.owner = '',
  });

  String get key => '$korean@$pack';

  /// Not someone a sentence may make the subject (선생님, 할머니, 부모님...).
  bool get isElder => kinds.contains('person') && !kinds.contains('peer');
}

class FrameSlot {
  final String particle;
  final List<SentenceNoun> nouns;
  const FrameSlot(this.particle, this.nouns);
}

class VerbFrame {
  final List<FrameSlot> slots;
  final String template;

  /// Frame-only English verb ("look at, looked at"), or null for the verb's Say.
  final (String, String)? say;
  const VerbFrame(this.slots, this.template, this.say);

  /// Two-noun frames are 🏗️ Master only.
  bool get isCombo => slots.length > 1;

  /// The noun with 이/가 is the sentence's subject (수업이 끝나요).
  bool get hasNounSubject => slots.any((s) => s.particle == '이');

  bool get usesTimeNoun => slots.any((s) => s.nouns.any((n) => n.kinds.contains('time_e')));
}

enum NegateMode { normal, split, none }

class SentenceVerb {
  final String dict;
  final Conjugation conj;
  final (String, String) say;
  final List<VerbFrame> frames;
  final Set<Tense> tenses;
  final bool timeWords;
  final NegateMode negate;

  /// The Korean means "not ..." (모르다 = not know).
  final bool englishNegative;
  final Set<String> alsoOk;

  /// Section name of the Verb Pack word (set by [SentenceBank.link]).
  String section = '';

  SentenceVerb({
    required this.dict,
    required this.conj,
    required this.say,
    required this.frames,
    required this.tenses,
    required this.timeWords,
    required this.negate,
    required this.englishNegative,
    required this.alsoOk,
  });

  /// 공부 for 공부하다 (split negation: 공부 안 해요).
  String get splitNoun => dict.substring(0, dict.length - 2);
}

/// A sentence subject: a pronoun with 은/는 (one tile) or a peer noun with 이/가.
class Subject {
  final String korean;
  final String particle;
  final String english;
  final String possessive;
  final String reflexive;
  final bool third;
  final String gender;
  const Subject(
    this.korean,
    this.particle,
    this.english,
    this.possessive,
    this.reflexive, {
    this.third = true,
    this.gender = '',
  });

  bool get isPronoun => particle.isEmpty;
  List<String> get tiles => isPronoun ? [korean] : [korean, particle];
}

const subjectMe = Subject('저는', '', 'I', 'my', 'myself', third: false);
const subjectHe = Subject('그는', '', 'he', 'his', 'himself', gender: 'he');
const subjectShe = Subject('그녀는', '', 'she', 'her', 'herself', gender: 'she');
const subjectFriend = Subject('친구', '가', 'my friend', 'their', 'themselves');
const subjectSibling = Subject('동생', '이', 'my younger sibling', 'their', 'themselves');
const allSubjects = [subjectMe, subjectHe, subjectShe, subjectFriend, subjectSibling];

const timeYesterday = '어제', timeToday = '오늘', timeTomorrow = '내일';
const timeEnglish = {timeYesterday: 'yesterday', timeToday: 'today', timeTomorrow: 'tomorrow'};

// --------------------------------------------------------------- English

String _thirdPerson(String w) {
  if (w == 'have') return 'has';
  if (w == 'do') return 'does';
  if (RegExp(r'(s|sh|ch|x|z|o)$').hasMatch(w)) return '${w}es';
  if (RegExp(r'[^aeiou]y$').hasMatch(w)) {
    return '${w.substring(0, w.length - 1)}ies';
  }
  return '${w}s';
}

/// The English verb phrase: [say] (base, past) in [tense], agreeing with the
/// subject, with do-support negation (don't/doesn't/didn't/won't).
String englishVerb(
  (String, String) say,
  Tense tense, {
  required bool third,
  bool firstPerson = false,
  bool negative = false,
}) {
  final (base, past) = say;
  final words = base.split(' ');
  if (words.first == 'be') {
    final rest = words.skip(1).join(' ');
    final head = switch (tense) {
      Tense.present =>
        negative
            ? (firstPerson
                  ? 'am not'
                  : third
                  ? "isn't"
                  : "aren't")
            : (firstPerson
                  ? 'am'
                  : third
                  ? 'is'
                  : 'are'),
      Tense.past =>
        negative
            ? (third || firstPerson ? "wasn't" : "weren't")
            : (third || firstPerson ? 'was' : 'were'),
      Tense.future => negative ? "won't be" : 'will be',
    };
    return rest.isEmpty ? head : '$head $rest';
  }
  if (negative) {
    return switch (tense) {
      Tense.present => "${third ? "doesn't" : "don't"} $base",
      Tense.past => "didn't $base",
      Tense.future => "won't $base",
    };
  }
  return switch (tense) {
    Tense.present => third ? [_thirdPerson(words.first), ...words.skip(1)].join(' ') : base,
    Tense.past => past,
    Tense.future => 'will $base',
  };
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _bare(String phrase) => phrase.replaceFirst(RegExp(r'^(a|an|the) '), '');

// ------------------------------------------------------------------ round

/// One 🏗️ round (or one generated sentence): the English to show, the
/// Korean in tiles, and the wrong tiles.
class Sentence {
  final SentenceVerb verb;
  final VerbFrame frame;
  final List<SentenceNoun> nouns;
  final Subject? subject;
  final Tense tense;
  final String time;
  final bool negated;
  final int level;

  /// Movable pieces in their usual order: each is one or two tiles
  /// (저는 / 친구+가 / 어제 / 사과+를).
  final List<List<String>> units;
  final String english;

  /// Wrong tiles (particles, subjects, time words, 안).
  final List<String> decoys;

  Sentence._({
    required this.verb,
    required this.frame,
    required this.nouns,
    required this.subject,
    required this.tense,
    required this.time,
    required this.negated,
    required this.level,
    required this.units,
    required this.english,
    required this.decoys,
  });

  bool get _split => negated && verb.negate == NegateMode.split;

  /// The pre-placed verb chip (먹어요; 해요 when 안 splits 공부 안 해요).
  String get verbChip =>
      _split ? verb.conj.form(tense).substring(verb.splitNoun.length) : verb.conj.form(tense);

  /// Fixed chip before 안 in a split negation (공부), else ''.
  String get fixedBeforeNegation => _split ? verb.splitNoun : '';

  /// Hard and Master: the verb is placed as two pieces, nothing pre-placed.
  bool get verbPlaced => level >= sentenceHard;

  /// The verb's two pieces (먹었 + 어요; 해 + 요 after 공부 안).
  List<String> get verbPieces => splitVerbForm(verbChip);

  /// The slot tiles after the movable units, in this order: Easy/Medium
  /// just 안; Hard/Master (공부) (안) then the verb's pieces.
  List<String> get tailTiles => verbPlaced
      ? [if (_split) verb.splitNoun, if (negated) '안', ...verbPieces]
      : [if (negated) '안'];

  /// The slot tiles in the usual order (안 and the verb last).
  List<String> get answerTiles => [for (final u in units) ...u, ...tailTiles];

  String get korean {
    final parts = [for (final u in units) u.join()];
    if (_split) {
      parts.addAll([verb.splitNoun, '안', verbChip]);
    } else {
      if (negated) parts.add('안');
      parts.add(verb.conj.form(tense));
    }
    return parts.join(' ');
  }

  /// The whole sentence in every accepted order: the units in any order,
  /// then 안 and the verb (for typing and the syllable games).
  List<String> get allOrders {
    final tail = _split
        ? [verb.splitNoun, '안', verbChip]
        : [if (negated) '안', verb.conj.form(tense)];
    final out = <String>[];
    void go(List<List<String>> done, List<List<String>> left) {
      if (left.isEmpty) {
        out.add([for (final u in done) u.join(), ...tail].join(' '));
        return;
      }
      for (var i = 0; i < left.length; i++) {
        go([...done, left[i]], [...left]..removeAt(i));
      }
    }

    go([], units);
    return out.toSet().toList();
  }

  /// The slot tiles of every accepted order: the units in any order, each
  /// kept together, then [tailTiles] (the same orders as [accepts]).
  List<List<String>> get acceptedTileOrders {
    final out = <List<String>>[];
    final tail = tailTiles;
    void go(List<String> done, List<List<String>> left) {
      if (left.isEmpty) {
        out.add([...done, ...tail]);
        return;
      }
      for (var i = 0; i < left.length; i++) {
        go([...done, ...left[i]], [...left]..removeAt(i));
      }
    }

    go([], units);
    return out;
  }

  /// True when [placed] (slot tiles left to right) is the units in any
  /// order, each unit kept together, then [tailTiles] (안, the verb) last.
  bool accepts(List<String> placed) {
    final tail = tailTiles;
    if (placed.length < tail.length) return false;
    var rest = placed.sublist(0, placed.length - tail.length);
    for (var i = 0; i < tail.length; i++) {
      if (placed[rest.length + i] != tail[i]) return false;
    }
    bool match(int at, List<bool> used) {
      if (at == rest.length) return used.every((u) => u);
      for (var i = 0; i < units.length; i++) {
        if (used[i]) continue;
        final u = units[i];
        if (at + u.length > rest.length) continue;
        var ok = true;
        for (var j = 0; j < u.length; j++) {
          if (rest[at + j] != u[j]) ok = false;
        }
        if (!ok) continue;
        used[i] = true;
        if (match(at + u.length, used)) return true;
        used[i] = false;
      }
      return false;
    }

    return match(0, List.filled(units.length, false));
  }
}

/// All sentence data, linked to the built-in words.
class SentenceBank {
  final List<SentenceNoun> nouns;
  final List<SentenceVerb> verbs;
  SentenceBank(this.nouns, this.verbs);

  static SentenceBank parse(
    String nounsTsv,
    String verbsIni, {
    Map<String, String> polite = const {},
  }) {
    final nouns = parseSentenceNouns(nounsTsv);
    final errors = <String>[];
    final verbs = parseSentenceVerbs(verbsIni, nouns, polite: polite, errors: errors);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return SentenceBank(nouns, verbs);
  }

  /// Links nouns and verbs to built-in words (by home pack + Korean1/Korean2
  /// for nouns, Korean1 in a Verb Pack for verbs). Returns problems.
  List<String> link(List<VocabEntry> builtIn, Set<String> verbPackIds) {
    final errors = <String>[];
    for (final n in nouns) {
      final m = builtIn.where(
        (e) =>
            e.packId == n.pack &&
            !verbPackIds.contains(e.packId) &&
            (e.korean1 == n.korean || e.korean2 == n.korean),
      );
      if (m.isEmpty) {
        errors.add('nouns.tsv ${n.korean} (${n.pack}): no built-in word');
      }
      n.sections = m.map((e) => e.sectionName).toSet();
    }
    for (final v in verbs) {
      final m = builtIn.where((e) => verbPackIds.contains(e.packId) && e.korean1 == v.dict);
      if (m.length != 1) {
        errors.add(
          'verbs.ini [${v.dict}]: ${m.isEmpty ? 'not in a Verb Pack' : 'in more than one'}',
        );
      } else {
        v.section = m.first.sectionName;
      }
    }
    final known = verbs.map((v) => v.dict).toSet();
    for (final e in builtIn) {
      if (verbPackIds.contains(e.packId) && !known.contains(e.korean1)) {
        errors.add('verbs.ini: no [${e.korean1}]');
      }
    }
    return errors;
  }

  SentenceVerb? verbBySection(String section) {
    for (final v in verbs) {
      if (v.section == section) return v;
    }
    return null;
  }
}

List<SentenceNoun> parseSentenceNouns(String tsv) => [
  for (final line in tsv.split('\n'))
    if (line.trim().isNotEmpty && !line.startsWith('#'))
      if ((line.split('\t')..length) case final f)
        SentenceNoun(
          korean: f[0].trim(),
          pack: f[1].trim(),
          kinds: f[2].split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toSet(),
          english: f[3].trim(),
          general: f.length > 4 ? f[4].trim() : '',
          at: f.length > 5 ? f[5].trim() : '',
          to: f.length > 6 ? f[6].trim() : '',
          plural: f.length > 7 && f[7].split(',').map((x) => x.trim()).contains('pl'),
          owner: f.length > 7
              ? f[7]
                    .split(',')
                    .map((x) => x.trim())
                    .firstWhere((x) => x == 'he' || x == 'she', orElse: () => '')
              : '',
        ),
];

const _verbKeys = {'say', 'frame', 'tenses', 'timewords', 'negate', 'english', 'alsook'};
final _placeholder = RegExp(r'\{([a-z]+ )?(\d|v|my|self)\}');

(String, String)? _parseSay(String s) {
  final p = s.split(',').map((x) => x.trim()).toList();
  if (p.length != 2 || p.any((x) => x.isEmpty)) return null;
  return (p[0], p[1]);
}

List<SentenceVerb> parseSentenceVerbs(
  String ini,
  List<SentenceNoun> nouns, {
  Map<String, String> polite = const {},
  List<String>? errors,
}) {
  final errs = errors ?? <String>[];
  final kinds = {for (final n in nouns) ...n.kinds};
  List<SentenceNoun> resolve(String where, String list) {
    final include = <SentenceNoun>[];
    final exclude = <SentenceNoun>{};
    for (var tok in list.split('/')) {
      tok = tok.trim();
      final minus = tok.startsWith('-');
      if (minus) tok = tok.substring(1);
      List<SentenceNoun> found;
      if (RegExp(r'^[a-z_]+$').hasMatch(tok)) {
        if (!kinds.contains(tok)) errs.add('$where: unknown kind $tok');
        found = nouns.where((n) => n.kinds.contains(tok)).toList();
      } else {
        final (ko, pack) = tok.contains('@') ? (tok.split('@')[0], tok.split('@')[1]) : (tok, '');
        found = nouns.where((n) => n.korean == ko && (pack.isEmpty || n.pack == pack)).toList();
        if (found.isEmpty) errs.add('$where: unknown noun $tok');
        if (found.length > 1) {
          errs.add('$where: $tok is in two packs (use $tok@pack)');
        }
      }
      if (minus) {
        exclude.addAll(found);
      } else {
        for (final n in found) {
          if (!include.contains(n)) include.add(n);
        }
      }
    }
    return include.where((n) => !exclude.contains(n)).toList();
  }

  final out = <SentenceVerb>[];
  for (final s in parseSections(ini)) {
    final where = '[${s.name}]';
    for (final p in s.pairs) {
      if (!_verbKeys.contains(p.key)) errs.add('$where: unknown key ${p.key}');
    }
    final say = _parseSay(s.get('say'));
    if (say == null) errs.add('$where: Say must be "base, past"');
    final frames = <VerbFrame>[];
    for (final p in s.pairs.where((p) => p.key == 'frame')) {
      final parts = p.value.split('|').map((x) => x.trim()).toList();
      if (parts.length < 2 || parts.length > 3) {
        errs.add('$where: Frame needs "slots | English [| Say]"');
        continue;
      }
      final slots = <FrameSlot>[];
      for (final spec in parts[0].split(RegExp(r'\s+'))) {
        final i = spec.indexOf(':');
        final particle = i < 0 ? spec : spec.substring(0, i);
        if (!particleKeys.contains(particle)) {
          errs.add('$where: unknown particle $particle');
        }
        final ns = i < 0 ? <SentenceNoun>[] : resolve(where, spec.substring(i + 1));
        if (ns.isEmpty) errs.add('$where: no nouns in $spec');
        slots.add(FrameSlot(particle, ns));
      }
      final fsay = parts.length == 3 ? _parseSay(parts[2]) : null;
      if (parts.length == 3 && fsay == null) {
        errs.add('$where: Frame Say must be "base, past"');
      }
      for (final m in _placeholder.allMatches(parts[1])) {
        final n = int.tryParse(m.group(2)!);
        if (n != null && (n < 1 || n > slots.length)) {
          errs.add('$where: {$n} has no slot');
        }
      }
      if (!parts[1].contains('{v}')) errs.add('$where: English needs {v}');
      final leftover = parts[1].replaceAll(_placeholder, '');
      if (leftover.contains('{') || leftover.contains('}')) {
        errs.add('$where: bad placeholder in ${parts[1]}');
      }
      frames.add(VerbFrame(slots, parts[1], fsay));
    }
    if (frames.isEmpty) errs.add('$where: no Frame');
    final tensesText = s.get('tenses');
    final tenses = tensesText.isEmpty
        ? Tense.values.toSet()
        : {
            for (final t in tensesText.split(',').map((x) => x.trim()))
              ...Tense.values.where((v) => v.name == t),
          };
    if (tenses.isEmpty) errs.add('$where: bad Tenses');
    final neg = s.get('negate').toLowerCase();
    if (!{'', 'no', 'split'}.contains(neg)) {
      errs.add('$where: Negate must be no or split');
    }
    if (neg == 'split' && !s.name.endsWith('하다')) {
      errs.add('$where: Negate = split is for 하다 verbs');
    }
    final alsoOk = s
        .get('alsook')
        .split(',')
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toSet();
    for (final a in alsoOk) {
      if (!particleKeys.contains(a)) {
        errs.add('$where: unknown AlsoOk particle $a');
      }
    }
    if (!s.name.endsWith('다')) errs.add('$where: a verb must end in 다');
    if (say == null || !s.name.endsWith('다')) continue;
    out.add(
      SentenceVerb(
        dict: s.name,
        conj: Conjugation(s.name, politeOverride: polite[s.name] ?? ''),
        say: say,
        frames: frames,
        tenses: tenses,
        timeWords: s.get('timewords').toLowerCase() != 'no',
        negate: switch (neg) {
          'no' => NegateMode.none,
          'split' => NegateMode.split,
          _ => NegateMode.normal,
        },
        englishNegative: s.get('english').toLowerCase() == 'negative',
        alsoOk: alsoOk,
      ),
    );
  }
  return out;
}

// -------------------------------------------------------------- generation

/// Builds sentences for a verb at a 🏗️ difficulty level.
class SentenceMaker {
  final Random rand;

  /// Every verb, for 🏗️ Master's other-verb decoy.
  final List<SentenceVerb> verbs;
  SentenceMaker(this.rand, {this.verbs = const []});

  /// Chance of a subject at Medium+, a time word at Hard+, a two-noun frame
  /// and 안 at Master.
  static const subjectChance = 0.7, timeChance = 0.6, comboChance = 0.4, negChance = 0.3;

  T _pick<T>(List<T> xs) => xs[rand.nextInt(xs.length)];

  /// Tenses [verb] can use at [level] (present only below Hard).
  static List<Tense> tensesAt(SentenceVerb verb, int level) => [
    for (final t in Tense.values)
      if (verb.tenses.contains(t) && (level >= sentenceHard || t == Tense.present)) t,
  ];

  /// [verb]'s frames usable at [level] whose slots can all be filled from
  /// [pool] (null = any noun).
  static List<VerbFrame> framesAt(
    SentenceVerb verb,
    int level,
    bool Function(SentenceNoun)? pool,
  ) => [
    for (final f in verb.frames)
      if ((!f.isCombo || level >= sentenceMaster) &&
          f.slots.every((s) => s.nouns.any((n) => pool?.call(n) ?? true)))
        f,
  ];

  /// Whether [verb] can make a sentence at [level].
  static bool canMake(SentenceVerb verb, int level) => tensesAt(verb, level).isNotEmpty;

  /// Subjects allowed with these nouns (no peer subject next to a person
  /// noun; 형/아내 only with a male owner, 남편 with a female one).
  static List<Subject> subjectsFor(List<SentenceNoun> nouns) {
    final people = nouns.any((n) => n.kinds.contains('person') || n.kinds.contains('peer'));
    final owner = nouns.map((n) => n.owner).firstWhere((o) => o.isNotEmpty, orElse: () => '');
    return [
      for (final s in allSubjects)
        if (!(people && !s.isPronoun) && (owner.isEmpty || s == subjectMe || s.gender == owner)) s,
    ];
  }

  /// Time words that fit [tense].
  static List<String> timesFor(Tense tense) => switch (tense) {
    Tense.present => [timeToday],
    Tense.past => [timeYesterday, timeToday],
    Tense.future => [timeTomorrow, timeToday],
  };

  /// A random sentence for [verb] at [level]. Nouns come from [preferred]
  /// when some frame can be filled from it, else from every noun. Null when
  /// the verb can't make a sentence at [level] (태어나다 below Hard).
  Sentence? make(SentenceVerb verb, int level, {bool Function(SentenceNoun)? preferred}) {
    final tenses = tensesAt(verb, level);
    if (tenses.isEmpty) return null;
    var pool = preferred;
    var frames = framesAt(verb, level, pool);
    if (frames.isEmpty) {
      pool = null;
      frames = framesAt(verb, level, null);
    }
    final combos = frames.where((f) => f.isCombo).toList();
    final singles = frames.where((f) => !f.isCombo).toList();
    final frame = combos.isNotEmpty && (singles.isEmpty || rand.nextDouble() < comboChance)
        ? _pick(combos)
        : _pick(singles);
    final nouns = <SentenceNoun>[];
    for (final s in frame.slots) {
      final options = s.nouns.where((n) => (pool?.call(n) ?? true) && !nouns.contains(n)).toList();
      nouns.add(_pick(options.isEmpty ? s.nouns : options));
    }
    Subject? subject;
    if (level >= sentenceMedium && !frame.hasNounSubject && rand.nextDouble() < subjectChance) {
      final options = subjectsFor(nouns);
      if (options.isNotEmpty) subject = _pick(options);
    }
    final tense = _pick(tenses);
    var time = '';
    if (level >= sentenceHard &&
        verb.timeWords &&
        !frame.usesTimeNoun &&
        rand.nextDouble() < timeChance) {
      time = _pick(timesFor(tense));
    }
    final negated =
        level >= sentenceMaster && verb.negate != NegateMode.none && rand.nextDouble() < negChance;
    return build(
      verb,
      frame,
      nouns,
      subject: subject,
      tense: tense,
      time: time,
      negated: negated,
      level: level,
    );
  }

  /// The sentence with exactly these choices (also used to list every sentence).
  Sentence build(
    SentenceVerb verb,
    VerbFrame frame,
    List<SentenceNoun> nouns, {
    Subject? subject,
    Tense tense = Tense.present,
    String time = '',
    bool negated = false,
    int level = 0,
  }) {
    final units = <List<String>>[
      if (subject != null) subject.tiles,
      if (time.isNotEmpty) [time],
      for (var i = 0; i < nouns.length; i++)
        [nouns[i].korean, particleFor(frame.slots[i].particle, nouns[i].korean)],
    ];
    final english = englishFor(
      verb,
      frame,
      nouns,
      subject: subject,
      tense: tense,
      time: time,
      negated: negated,
    );
    final decoys = <String>[];
    final split = negated && verb.negate == NegateMode.split;
    String chipOf(SentenceVerb v, Tense t) {
      final f = v.conj.form(t);
      return split && v == verb ? f.substring(v.splitNoun.length) : f;
    }

    final pieces = level >= sentenceHard ? splitVerbForm(chipOf(verb, tense)) : const <String>[];
    final answer = {
      for (final u in units) ...u,
      if (negated) '안',
      if (split && level >= sentenceHard) verb.splitNoun,
      ...pieces,
    };
    void add(String? d) {
      if (d != null && !answer.contains(d) && !decoys.contains(d)) {
        decoys.add(d);
      }
    }

    for (var i = 0; i < nouns.length; i++) {
      final key = frame.slots[i].particle;
      final ko = nouns[i].korean;
      add(wrongParticleForm(key, ko));
      final roles = roleDecoys[key]!.where((r) => !verb.alsoOk.contains(r)).toList();
      if (roles.isNotEmpty) add(particleFor(_pick(roles), ko));
    }
    if (level >= sentenceMedium && !frame.hasNounSubject) {
      if (subject == null) {
        add(_pick([subjectHe, subjectShe]).korean);
      } else if (subject.isPronoun) {
        add(_pick(allSubjects.where((s) => s.isPronoun && s != subject).toList()).korean);
      } else {
        add((subject == subjectFriend ? subjectSibling : subjectFriend).korean);
      }
    }
    if (level >= sentenceHard) {
      add(switch (tense) {
        Tense.past => timeTomorrow,
        Tense.future => timeYesterday,
        Tense.present => _pick([timeYesterday, timeTomorrow]),
      });
    }
    if (level >= sentenceMaster && !negated && verb.negate != NegateMode.none) {
      add('안');
    }
    if (level >= sentenceMaster) {
      // Verb decoys: the same verb's stem in a wrong tense, another verb's
      // stem in this tense, and a wrong ending. Each differs from every
      // answer piece, and 🏗️ only takes the exact pieces, so none can be
      // part of an accepted answer.
      add(splitVerbForm(chipOf(verb, _pick(Tense.values.where((t) => t != tense).toList())))[0]);
      final others = [
        for (final v in verbs)
          if (v.dict != verb.dict && !answer.contains(splitVerbForm(v.conj.form(tense))[0])) v,
      ];
      if (others.isNotEmpty) add(splitVerbForm(_pick(others).conj.form(tense))[0]);
      add(verbEndingDecoys[pieces[1]]);
    }
    return Sentence._(
      verb: verb,
      frame: frame,
      nouns: nouns,
      subject: subject,
      tense: tense,
      time: time,
      negated: negated,
      level: level,
      units: units,
      english: english,
      decoys: decoys,
    );
  }

  /// The English for these choices ("My friend didn't eat an apple yesterday").
  static String englishFor(
    SentenceVerb verb,
    VerbFrame frame,
    List<SentenceNoun> nouns, {
    Subject? subject,
    Tense tense = Tense.present,
    String time = '',
    bool negated = false,
  }) {
    final say = frame.say ?? verb.say;
    final nounSubject = frame.hasNounSubject;
    final subj = subject ?? subjectMe;
    final subjectNoun = nounSubject
        ? nouns[frame.slots.indexWhere((s) => s.particle == '이')]
        : null;
    final third = subjectNoun != null ? !subjectNoun.plural : subj.third;
    final verbText = englishVerb(
      say,
      tense,
      third: third,
      firstPerson: subjectNoun == null && subj == subjectMe,
      negative: negated != verb.englishNegative,
    );
    final possessive = nounSubject ? 'my' : subj.possessive;
    final reflexive = nounSubject ? 'myself' : subj.reflexive;
    var text = frame.template.replaceAllMapped(_placeholder, (m) {
      final kind = m.group(1)?.trim() ?? '';
      final what = m.group(2)!;
      if (what == 'v') return verbText;
      if (what == 'my' || what == 'self') return '{$what}';
      final n = nouns[int.parse(what) - 1];
      return switch (kind) {
        'a' => n.english,
        'bare' => _bare(n.english),
        'at' => n.at.isNotEmpty ? n.at : 'at ${n.english}',
        'to' => n.to.isNotEmpty ? n.to : 'to ${n.english}',
        'by' => 'by ${_bare(n.english)}',
        _ => tense == Tense.present && time.isEmpty && n.general.isNotEmpty ? n.general : n.english,
      };
    });
    text = text.replaceAll('{my}', possessive).replaceAll('{self}', reflexive);
    if (!nounSubject) text = '${subj.english} $text';
    if (time.isNotEmpty) text = '$text ${timeEnglish[time]}';
    return _capitalize(text.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  /// Every sentence the game can make for [verb], at the lowest level
  /// that can make it: every frame and set of nouns × subject × tense ×
  /// time word × 안.
  Iterable<Sentence> everySentence(SentenceVerb verb) sync* {
    for (final frame in verb.frames) {
      var lists = <List<SentenceNoun>>[[]];
      for (final s in frame.slots) {
        lists = [
          for (final l in lists)
            for (final n in s.nouns)
              if (!l.contains(n)) [...l, n],
        ];
      }
      for (final nouns in lists) {
        yield* _variants(verb, frame, nouns);
      }
    }
  }

  Iterable<Sentence> _variants(SentenceVerb verb, VerbFrame frame, List<SentenceNoun> nouns) sync* {
    final subjects = <Subject?>[null, if (!frame.hasNounSubject) ...subjectsFor(nouns)];
    for (final subject in subjects) {
      for (final tense in verb.tenses) {
        final times = ['', if (verb.timeWords && !frame.usesTimeNoun) ...timesFor(tense)];
        for (final time in times) {
          for (final neg in [false, if (verb.negate != NegateMode.none) true]) {
            var level = sentenceEasy;
            if (subject != null) level = sentenceMedium;
            if (tense != Tense.present || time.isNotEmpty) level = sentenceHard;
            if (frame.isCombo || neg) level = sentenceMaster;
            yield build(
              verb,
              frame,
              nouns,
              subject: subject,
              tense: tense,
              time: time,
              negated: neg,
              level: level,
            );
          }
        }
      }
    }
  }
}
