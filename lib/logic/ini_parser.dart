import '../data/bundles.dart';
import '../models/vocab_entry.dart';

/// Port of the VB.NET `ParseIniFile` function.
///
/// Format: `[Section]` headers followed by `key = value` lines. Keys are
/// case-insensitive: english1, english2, emoji, korean1, korean2, pack,
/// alsopacks (comma-separated extra packs, ids or names), isfullphrase.
/// The original `category` key is still read and converted to
/// a Word Pack (see [packIdForIni]); `pack` (id or name) wins if both appear. Blank lines and lines starting with `;` or `#` are skipped.
List<VocabEntry> parseIni(String content) {
  final entries = <VocabEntry>[];
  // Strip a UTF-8 BOM if present.
  if (content.startsWith('\uFEFF')) content = content.substring(1);

  _Builder? current;
  for (final rawLine in content.split(RegExp(r'\r\n|\n|\r'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      if (current != null) entries.add(current.build());
      current = _Builder(line.substring(1, line.length - 1));
      continue;
    }

    if (current != null && line.contains('=')) {
      final idx = line.indexOf('=');
      final key = line.substring(0, idx).trim().toLowerCase();
      final val = line.substring(idx + 1).trim();
      switch (key) {
        case 'english1':
          current.english1 = val;
        case 'english2':
          current.english2 = val;
        case 'emoji':
          current.emoji = val;
        case 'korean1':
          current.korean1 = val;
        case 'korean2':
          current.korean2 = val;
        case 'category':
          current.category = val;
        case 'pack':
          current.pack = val;
        case 'alsopacks':
          current.alsoPacks.addAll(val.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty));
        case 'isfullphrase':
          // .NET Boolean.TryParse: case-insensitive "true"/"false", else false.
          current.isFullPhrase = val.toLowerCase() == 'true';
      }
    }
  }
  if (current != null) entries.add(current.build());
  return entries;
}

class _Builder {
  final String section;
  String english1 = '', english2 = '', emoji = '', korean1 = '', korean2 = '';
  String category = '', pack = '';
  final List<String> alsoPacks = [];
  bool isFullPhrase = false;
  _Builder(this.section);

  VocabEntry build() {
    final home = packIdForIni(pack: pack, category: category, isFullPhrase: isFullPhrase);
    final extra = <String>[];
    for (final p in alsoPacks) {
      final id = builtInPackIdFor(p);
      if (id != null && id != home && !extra.contains(id)) extra.add(id);
    }
    return VocabEntry(
      sectionName: section,
      packId: home,
      alsoPacks: extra,
      english1: english1,
      english2: english2,
      emoji: emoji,
      korean1: korean1,
      korean2: korean2,
      isFullPhrase: isFullPhrase,
    );
  }
}
