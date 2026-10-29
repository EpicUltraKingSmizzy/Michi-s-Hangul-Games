import '../models/vocab_entry.dart';

/// A built-in word pack. Word Packs are the only grouping in the app: every
/// built-in word has one home pack (its `packId`) and may also belong to
/// other packs (its `alsoPacks`, INI `AlsoPacks =`). A word is stored once,
/// so it is counted, played and scored once however many packs hold it.
///
/// INI entries without a valid `Pack =` go to Handy Phrases if they are full
/// phrases, otherwise to the Grab Bag.
class WordBundle {
  final String id;
  final String emoji;
  final String name;
  final String blurb;
  const WordBundle(this.id, this.emoji, this.name, this.blurb);
}

final List<WordBundle> builtInBundles = [
  WordBundle(
    'phrases',
    '🗣️',
    'Handy Phrases',
    'Hello, sorry, how much?! Full sentences.',
  ),
  WordBundle(
    'everyday-talk',
    '🗨️',
    'Everyday Talk',
    'Handy everyday phrases for meals, shops & chatting.',
  ),
  WordBundle('food', '🍜', 'Food', 'Fruit, veggies, drinks & Korean classics.'),
  WordBundle('home', '🏠', 'At Home', 'Stuff around the house & gadgets.'),
  WordBundle(
    'outside',
    '🚌',
    'Out & About',
    'Places, getting around town, sports & fun.',
  ),
  WordBundle(
    'time',
    '📅',
    'Time & Calendar',
    'Days, months, today, tomorrow & more.',
  ),
  WordBundle(
    'people',
    '👨‍👩‍👧',
    'Family',
    'Mom, dad, siblings, grandparents & the whole crew.',
  ),
  WordBundle('animals', '🐾', 'Animals', 'Cats, dogs, cows & creepy crawlies.'),
  WordBundle('body', '🦵', 'Body Parts', 'Eyes, ears, arms & legs.'),
  WordBundle(
    'emotions',
    '😊',
    'Emotions',
    'Love, tears, laughs & big feelings.',
  ),
  WordBundle('verbs', '🏃', 'Action Heroes', 'I / he / she + doing things.'),
  WordBundle(
    'numbers',
    '🔢',
    'Sino-Korean Numbers',
    'Number words, 1 to 1,000,000,000.',
  ),
  WordBundle(
    'native',
    '🧮',
    'Native Numbers',
    'Counting the Korean way: 하나, 둘, 셋… 스물.',
  ),
  WordBundle(
    'colours',
    '🌈',
    'Colour Splash',
    'Red, blue, sky blue & every shade between.',
  ),
  WordBundle('grabbag', '🎲', 'Grab Bag', 'Odds & ends that fit nowhere else.'),
  // The top-500 Korean nouns, by theme (v9). Off until the player turns them on.
  WordBundle(
    'whos-who',
    '🧑‍🤝‍🧑',
    "Who's Who",
    'Jobs, friends, strangers & everyone outside the family.',
  ),
  WordBundle(
    'tick-tock',
    '⏰',
    'Tick Tock',
    'Now, later, seasons & the good old days.',
  ),
  WordBundle(
    'here-there-everywhere',
    '🗺️',
    'Here, There & Everywhere',
    'Places to go and where stuff is.',
  ),
  WordBundle(
    'heart-and-body',
    '💓',
    'Heart & Body',
    'Moods, dreams, sleep, health & the big stuff of life.',
  ),
  WordBundle(
    'stuff-and-nature',
    '🧸',
    'Stuff & Nature',
    'Everyday things, food & the great outdoors.',
  ),
  WordBundle(
    'showtime',
    '🎭',
    'Showtime!',
    'Movies, music, games, TV & the press.',
  ),
  WordBundle(
    'school-and-hustle',
    '🎒',
    'School & Hustle',
    'Classes, exams, offices & bosses.',
  ),
  WordBundle(
    'big-words',
    '🏛️',
    'Big Words',
    'Government, money, law & the evening news.',
  ),
  WordBundle(
    'big-brain-ideas',
    '💭',
    'Big Brain Ideas',
    'Thinking, talking, reasons & opinions.',
  ),
  WordBundle(
    'how-things-are',
    '📏',
    'How Things Are',
    'Sizes, shapes, kinds, parts & processes.',
  ),
];

/// Built-in packs that start switched OFF, both on a fresh install and for a
/// player updating from a version without them (their saved toggles for the
/// older packs are left exactly as they were).
const Set<String> defaultOffBundles = {
  'phrases',
  'everyday-talk',
  'whos-who',
  'tick-tock',
  'here-there-everywhere',
  'heart-and-body',
  'stuff-and-nature',
  'showtime',
  'school-and-hustle',
  'big-words',
  'big-brain-ideas',
  'how-things-are',
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
const String grabBagBundleId = 'grabbag';

/// Pack id for an INI entry. An explicit `Pack =` (id or name, any case) wins;
/// otherwise full phrases are Handy Phrases; everything else is the Grab Bag.
String packIdForIni({String pack = '', bool isFullPhrase = false}) {
  final p = pack.trim().toLowerCase();
  if (p.isNotEmpty) {
    for (final b in builtInBundles) {
      if (b.id == p || b.name.toLowerCase() == p) return b.id;
    }
  }
  if (isFullPhrase) return phrasesBundleId;
  return grabBagBundleId;
}

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
