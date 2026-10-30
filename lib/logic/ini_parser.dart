import '../data/bundles.dart';
import '../models/vocab_entry.dart';

/// Built-in vocabulary lives in `assets/vocab/`: [vocabIndexAsset] lists the
/// pack ids in display order, and each pack is `assets/vocab/<id>.ini`.
///
/// A pack file starts with a `[Pack]` header (Id, Emoji, Name, Blurb,
/// DefaultOn, and `Type = verb` for a Verb Pack) followed by one `[Section]` per word. Every word's home pack is
/// the file it is in. Word keys (case-insensitive): English1, English2, Emoji,
/// Korean1, Korean2, AlsoPacks (comma-separated extra pack ids or names),
/// IsFullPhrase, Polite (a Verb Pack word's polite 해요 form, given for
/// irregular verbs; see [parsePoliteForms]). Blank lines and lines starting with `;` or `#` are skipped.
const String vocabDir = 'assets/vocab';
const String vocabIndexAsset = '$vocabDir/index.txt';
String packAsset(String id) => '$vocabDir/$id.ini';

const String packHeaderSection = 'Pack';

/// `Type =` value of a Verb Pack's `[Pack]` header.
const String verbPackType = 'verb';
const Set<String> packHeaderKeys = {'id', 'type', 'emoji', 'name', 'blurb', 'defaulton'};
const Set<String> wordKeys = {
  'english1',
  'english2',
  'emoji',
  'korean1',
  'korean2',
  'alsopacks',
  'isfullphrase',
  'polite',
  'notwith',
};

final _lineBreak = RegExp(r'\r\n|\n|\r');

/// Pack ids listed in the index file, in order.
List<String> parsePackIndex(String content) => [
  for (final raw in content.split(_lineBreak))
    if (raw.trim() case final l when l.isNotEmpty && !l.startsWith('#') && !l.startsWith(';')) l,
];

/// One raw `[Section]` with its keys (lower-cased) and values, in file order.
class IniSection {
  final String name;
  final List<MapEntry<String, String>> pairs = [];
  IniSection(this.name);

  String get(String key) {
    for (final p in pairs) {
      if (p.key == key) return p.value;
    }
    return '';
  }
}

/// `[Section]` headers followed by `key = value` lines (split on the first
/// `=`). Keys before any section are ignored; a UTF-8 BOM is stripped.
List<IniSection> parseSections(String content) {
  if (content.startsWith('\uFEFF')) content = content.substring(1);
  final out = <IniSection>[];
  IniSection? current;
  for (final rawLine in content.split(_lineBreak)) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      out.add(current = IniSection(line.substring(1, line.length - 1)));
      continue;
    }
    if (current != null && line.contains('=')) {
      final idx = line.indexOf('=');
      final key = line.substring(0, idx).trim().toLowerCase();
      current.pairs.add(MapEntry(key, line.substring(idx + 1).trim()));
    }
  }
  return out;
}

/// The words in one pack file (its `[Pack]` header skipped), homed in
/// [packId]. AlsoPacks keep their raw values; [loadBuiltInVocab] resolves
/// them once every pack is known.
List<VocabEntry> parseIni(String content, {required String packId}) => [
  for (final s in parseSections(content))
    if (s.name != packHeaderSection) _entry(s, packId),
];

VocabEntry _entry(IniSection s, String packId) => VocabEntry(
  sectionName: s.name,
  packId: packId,
  alsoPacks: [
    for (final p in s.pairs)
      if (p.key == 'alsopacks')
        ...p.value.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty),
  ],
  english1: s.get('english1'),
  english2: s.get('english2'),
  emoji: s.get('emoji'),
  korean1: s.get('korean1'),
  korean2: s.get('korean2'),
  // .NET Boolean.TryParse: case-insensitive "true"/"false", else false.
  isFullPhrase: s.get('isfullphrase').toLowerCase() == 'true',
);

/// The pack described by a file's `[Pack]` header, or null if it has none.
WordBundle? parsePackHeader(String content) {
  for (final s in parseSections(content)) {
    if (s.name != packHeaderSection) continue;
    return WordBundle(
      s.get('id'),
      s.get('emoji'),
      s.get('name'),
      s.get('blurb'),
      defaultOn: s.get('defaulton').toLowerCase() != 'false',
      isVerbPack: s.get('type').toLowerCase() == verbPackType,
    );
  }
  return null;
}

/// Builds the built-in packs and words from the index and pack files, sets
/// [builtInBundles], and returns every built-in word (packs in index order,
/// words in file order). Unknown AlsoPacks are dropped.
List<VocabEntry> loadBuiltInVocab(String index, String Function(String id) readPack) {
  final bundles = <WordBundle>[];
  final words = <VocabEntry>[];
  for (final id in parsePackIndex(index)) {
    final text = readPack(id);
    bundles.add(parsePackHeader(text) ?? WordBundle(id, '', id, ''));
    words.addAll(parseIni(text, packId: id));
  }
  setBuiltInBundles(bundles);
  return [
    for (final e in words)
      e.copyWith(
        alsoPacks: {
          for (final p in e.alsoPacks)
            if (builtInPackIdFor(p) case final id? when id != e.packId) id,
        }.toList(),
      ),
  ];
}

/// Words that must never share a round (`NotWith = Entry_00187, ...`, other
/// words' section names): each pair once, as `a|b` with a before b.
Set<String> parseNotWith(String content) => {
  for (final s in parseSections(content))
    for (final p in s.pairs)
      if (p.key == 'notwith')
        for (final x in p.value.split(',').map((x) => x.trim()))
          if (x.isNotEmpty) notWithKey(s.name, x),
};

/// The [parseNotWith] key for two section names (either order).
String notWithKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

/// Korean1 → Polite form for every word in a pack file that gives one.
Map<String, String> parsePoliteForms(String content) => {
  for (final s in parseSections(content))
    if (s.name != packHeaderSection && s.get('polite').isNotEmpty)
      s.get('korean1'): s.get('polite'),
};

/// Problems in the vocab files (empty when all is well): bad or mismatched
/// pack headers, duplicate section names across files, unknown AlsoPacks ids,
/// missing English1/Korean1, and unknown keys. Verb Pack words must be
/// dictionary forms (Korean1 ending in 다) with no emoji, and only they may
/// have a Polite form.
List<String> validateVocab(String index, String Function(String id) readPack) {
  final errors = <String>[];
  final ids = parsePackIndex(index);
  if (ids.toSet().length != ids.length) errors.add('index: duplicate pack id');
  final packNames = <String>{};
  final seen = <String, String>{};
  final also = <(String, String)>[];
  final notWith = <(String, String)>[];
  for (final id in ids) {
    final sections = parseSections(readPack(id));
    final isVerb = sections.isNotEmpty && sections.first.get('type').toLowerCase() == verbPackType;
    if (sections.isEmpty || sections.first.name != packHeaderSection) {
      errors.add('$id: first section must be [$packHeaderSection]');
    }
    for (final s in sections) {
      if (s.name == packHeaderSection) {
        for (final p in s.pairs) {
          if (!packHeaderKeys.contains(p.key)) errors.add('$id [Pack]: unknown key ${p.key}');
        }
        if (s.get('id') != id) errors.add('$id [Pack]: Id must be "$id"');
        for (final k in ['emoji', 'name', 'blurb']) {
          if (s.get(k).isEmpty) errors.add('$id [Pack]: missing $k');
        }
        if (!{'', verbPackType}.contains(s.get('type').toLowerCase())) {
          errors.add('$id [Pack]: Type must be $verbPackType or left out');
        }
        if (!{'true', 'false'}.contains(s.get('defaulton').toLowerCase())) {
          errors.add('$id [Pack]: DefaultOn must be true or false');
        }
        if (!packNames.add(s.get('name').toLowerCase())) errors.add('$id [Pack]: duplicate name');
        continue;
      }
      final where = '$id [${s.name}]';
      if (seen[s.name] case final other?) {
        errors.add('$where: duplicate section (also in $other)');
      }
      seen[s.name] = id;
      for (final p in s.pairs) {
        if (!wordKeys.contains(p.key)) errors.add('$where: unknown key ${p.key}');
        if (p.key == 'notwith') {
          for (final x in p.value.split(',').map((x) => x.trim())) {
            if (x.isNotEmpty) notWith.add((where, x));
          }
        }
        if (p.key == 'alsopacks') {
          for (final x in p.value.split(',').map((x) => x.trim())) {
            if (x.isNotEmpty) also.add((where, x));
          }
        }
      }
      if (s.get('english1').isEmpty) errors.add('$where: missing English1');
      if (s.get('korean1').isEmpty) errors.add('$where: missing Korean1');
      if (isVerb) {
        if (!s.get('korean1').endsWith('다')) errors.add('$where: a verb must end in 다');
        if (s.get('emoji').isNotEmpty) errors.add('$where: verbs have no emoji');
      } else if (s.get('polite').isNotEmpty) {
        errors.add('$where: Polite is for Verb Pack words only');
      }
    }
  }
  for (final (where, x) in notWith) {
    if (!seen.containsKey(x)) errors.add('$where: unknown NotWith section $x');
  }
  for (final (where, x) in also) {
    if (!ids.contains(x)) errors.add('$where: unknown AlsoPacks id $x');
  }
  return errors;
}
