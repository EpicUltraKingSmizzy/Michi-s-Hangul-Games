import '../models/vocab_entry.dart';

/// A built-in word pack. Word Packs are the only grouping in the app: every
/// built-in word has one home pack (its `packId`, the pack file it is in) and
/// may also belong to other packs (its `alsoPacks`, INI `AlsoPacks =`). A word
/// is stored once, so it is counted, played and scored once however many
/// packs hold it. Packs are defined by their files in `assets/vocab/` (see
/// `loadBuiltInVocab`), not in code.
class WordBundle {
  final String id;
  final String emoji;
  final String name;
  final String blurb;

  /// Whether the pack starts switched on, both on a fresh install and for a
  /// player updating from a version without it.
  final bool defaultOn;
  const WordBundle(this.id, this.emoji, this.name, this.blurb, {this.defaultOn = true});
}

List<WordBundle> _builtIn = const [];

/// Built-in packs in display order, as loaded from `assets/vocab/`.
List<WordBundle> get builtInBundles => _builtIn;
void setBuiltInBundles(List<WordBundle> bundles) => _builtIn = List.unmodifiable(bundles);

/// Built-in packs that start switched OFF (their [WordBundle.defaultOn] is false).
Set<String> get defaultOffBundles => {
  for (final b in _builtIn)
    if (!b.defaultOn) b.id,
};

const String emotionsBundleId = 'emotions';

/// 🏃 Action Heroes: I / he / she + a verb (old I_do, He_does, She_does).
const String actionHeroesBundleId = 'verbs';

const String customBundleId = 'custom';

/// v13: the family names are the player's own words, not a built-in pack's.
/// Every install starts with them in ✏️ My Words as ordinary custom words
/// (editable, deletable), seeded once on first run of v13 or later.
const List<VocabEntry> seededMyWords = [
  VocabEntry(
    sectionName: 'Custom_seed_michi',
    packId: customBundleId,
    english1: 'Michi',
    korean1: '미시',
  ),
  VocabEntry(
    sectionName: 'Custom_seed_michel_andre',
    packId: customBundleId,
    english1: 'Michel-André',
    korean1: '미셸안드레',
  ),
  VocabEntry(
    sectionName: 'Custom_seed_nicole',
    packId: customBundleId,
    english1: 'Nicole',
    korean1: '다정전',
  ),
];

const String phrasesBundleId = 'phrases';

/// Built-in pack id whose id or name (any case) is [pack], or null.
String? builtInPackIdFor(String pack) {
  final p = pack.trim().toLowerCase();
  if (p.isEmpty) return null;
  for (final b in builtInBundles) {
    if (b.id == p || b.name.toLowerCase() == p) return b.id;
  }
  return null;
}

WordBundle? builtInBundleById(String id) {
  for (final b in builtInBundles) {
    if (b.id == id) return b;
  }
  return null;
}
