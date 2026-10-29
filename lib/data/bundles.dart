import '../models/vocab_entry.dart';

/// A built-in word pack. Word Packs are the only grouping in the app: every
/// built-in word has one home pack (its `packId`) and may also belong to
/// other packs (its `alsoPacks`, INI `AlsoPacks =`). A word is stored once,
/// so it is counted, played and scored once however many packs hold it.
///
/// [legacyCategories] maps the old INI `Category =` values (the original
/// LINQPad format, still accepted) onto the pack. Full phrases go to
/// Handy Phrases, and anything unmatched lands in the Grab Bag.
class WordBundle {
  final String id;
  final String emoji;
  final String name;
  final String blurb;
  final List<String> legacyCategories;
  const WordBundle(this.id, this.emoji, this.name, this.blurb, this.legacyCategories);
}

final List<WordBundle> builtInBundles = [
  WordBundle('phrases', '🗣️', 'Handy Phrases', 'Hello, sorry, how much?! Full sentences.', []),
  WordBundle(
    'everyday-talk',
    '🗨️',
    'Everyday Talk',
    'Handy everyday phrases for meals, shops & chatting.',
    [],
  ),
  WordBundle('food', '🍜', 'Food', 'Fruit, veggies, drinks & Korean classics.', ['Food']),
  WordBundle('home', '🏠', 'At Home', 'Stuff around the house & gadgets.', [
    'Household',
    'Digital',
  ]),
  WordBundle('outside', '🚌', 'Out & About', 'Places, getting around town, sports & fun.', [
    'Society',
    'Activity',
  ]),
  WordBundle('time', '📅', 'Time & Calendar', 'Days, months, today, tomorrow & more.', ['Time']),
  WordBundle('people', '👨‍👩‍👧', 'Family', 'Mom, dad, siblings, grandparents & the whole crew.', [
    'People',
    'Family',
  ]),
  WordBundle('animals', '🐾', 'Animals', 'Cats, dogs, cows & creepy crawlies.', ['Animal']),
  WordBundle('body', '🦵', 'Body Parts', 'Eyes, ears, arms & legs.', ['Bodypart']),
  WordBundle('emotions', '😊', 'Emotions', 'Love, tears, laughs & big feelings.', ['Emotion']),
  WordBundle('verbs', '🏃', 'Action Heroes', 'I / he / she + doing things.', [
    'I_do',
    'He_does',
    'She_does',
  ]),
  WordBundle('numbers', '🔢', 'Sino-Korean Numbers', 'Number words, 1 to 1,000,000,000.', [
    'Number',
  ]),
  WordBundle('native', '🧮', 'Native Numbers', 'Counting the Korean way: 하나, 둘, 셋… 스물.', [
    'NativeNumber',
  ]),
  WordBundle('colours', '🌈', 'Colour Splash', 'Red, blue, sky blue & every shade between.', [
    'Colours',
  ]),
  WordBundle('grabbag', '🎲', 'Grab Bag', 'Odds & ends that fit nowhere else.', [
    'Vocab',
    'Words & Feelings',
  ]),
  // The top-500 Korean nouns, by theme (v9). Off until the player turns them on.
  WordBundle(
    'whos-who',
    '🧑‍🤝‍🧑',
    "Who's Who",
    'Jobs, friends, strangers & everyone outside the family.',
    [],
  ),
  WordBundle('tick-tock', '⏰', 'Tick Tock', 'Now, later, seasons & the good old days.', []),
  WordBundle(
    'here-there-everywhere',
    '🗺️',
    'Here, There & Everywhere',
    'Places to go and where stuff is.',
    [],
  ),
  WordBundle(
    'heart-and-body',
    '💓',
    'Heart & Body',
    'Moods, dreams, sleep, health & the big stuff of life.',
    [],
  ),
  WordBundle(
    'stuff-and-nature',
    '🧸',
    'Stuff & Nature',
    'Everyday things, food & the great outdoors.',
    [],
  ),
  WordBundle('showtime', '🎭', 'Showtime!', 'Movies, music, games, TV & the press.', []),
  WordBundle('school-and-hustle', '🎒', 'School & Hustle', 'Classes, exams, offices & bosses.', []),
  WordBundle('big-words', '🏛️', 'Big Words', 'Government, money, law & the evening news.', []),
  WordBundle(
    'big-brain-ideas',
    '💭',
    'Big Brain Ideas',
    'Thinking, talking, reasons & opinions.',
    [],
  ),
  WordBundle(
    'how-things-are',
    '📏',
    'How Things Are',
    'Sizes, shapes, kinds, parts & processes.',
    [],
  ),
];

/// Packs that used to start ON and now start OFF. Only fresh installs get
/// the new default: an existing player's switch (saved or not) is kept.
const Set<String> newlyDefaultOffBundles = {'phrases'};

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

/// Packs that were split up in an update: old id -> the ids that replaced it.
/// A player who had the old pack switched off gets the new ones off too.
const Map<String, List<String>> splitBundles = {
  'critters': ['people', 'animals', 'body'],
};

/// Packs removed in an update: old id -> the pack its words moved to. Saved
/// words in a retired pack move with them (emotion words go to Emotions,
/// see AppState), and a player who had it on gets its new home on.
const Map<String, String> retiredBundles = {'words': grabBagBundleId};

/// Built-in packs renamed in an update: old name (lower case) -> pack id, so
/// the old name typed in the Word Pack field still finds the pack.
const Map<String, String> renamedBundles = {'people & family': 'people'};

/// Built-in words whose home pack changed in v11 (Family / Who's Who split)
/// and v12 (body parts out of Heart & Body):
/// section -> the old home pack. A saved edit still homed in the old pack
/// follows the word to its new one.
const Map<String, String> movedWords = {
  // People & Family -> Who's Who
  'Entry_00173': 'people', // 남자들 Men
  'Entry_00183': 'people', // 시민 Citizen
  'Entry_00186': 'people', // 종업원 staff
  'Entry_00193': 'people', // 팬 Fan
  'Entry_00194': 'people', // 아이돌 Idol
  'Entry_00195': 'people', // 모델 Model
  'Entry_00197': 'people', // 스타일리스트 Stylist
  'Entry_00198': 'people', // 디자이너 Designer
  'Entry_00218': 'people', // 사람 Person
  'Entry_00219': 'people', // 친구 Friend
  'Entry_00254': 'people', // 남성 Male
  'Entry_00255': 'people', // 여성 Female
  // Who's Who -> Family
  'Entry_00571': 'whos-who', // 엄마 Mom
  'Entry_00575': 'whos-who', // 자식 Children
  'Entry_00577': 'whos-who', // 할머니 Grandmother
  'Entry_00580': 'whos-who', // 결혼 Marriage
  'Entry_00581': 'whos-who', // 동생 Younger sibling
  'Entry_00582': 'whos-who', // 아기 Baby
  'Entry_00586': 'whos-who', // 부모 Parents
  'Entry_00587': 'whos-who', // 할아버지 Grandfather
  'Entry_00589': 'whos-who', // 가정 Household
  'Entry_00597': 'whos-who', // 부부 Married couple
  // Who's Who -> Big Brain Ideas / How Things Are
  'Entry_00566': 'whos-who', // 자신 Oneself
  'Entry_00572': 'whos-who', // 남 Others
  'Entry_00573': 'whos-who', // 혼자 Alone
  'Entry_00574': 'whos-who', // 나이 Age
  'Entry_00578': 'whos-who', // 개인 Individual
  'Entry_00593': 'whos-who', // 인류 Humankind
  'Entry_00601': 'whos-who', // 출신 Origin
  // v12: Heart & Body -> Body Parts
  'Entry_00675': 'heart-and-body', // 몸 Body
  'Entry_00683': 'heart-and-body', // 고개 Head (nod)
  'Entry_00700': 'heart-and-body', // 등 Back (body)
  'Entry_00703': 'heart-and-body', // 허리 Waist
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

/// v13: the built-in entries the seeded names replace (removed from the INI),
/// matched by position with [seededMyWords]. An edit a player made to one of
/// them is carried over to its My Words copy.
const List<String> retiredNameEntries = ['Entry_00262', 'Entry_00263', 'Entry_00264'];

/// v13: Korean spellings an old version wrongly "fixed" these names to. A
/// carried-over edit still holding one gets the right spelling back; any other
/// Korean the player typed is theirs and stays.
const Map<String, String> wrongNameSpellings = {'미셸앙드레': '미셸안드레', '니콜': '다정전'};

const String phrasesBundleId = 'phrases';
const String grabBagBundleId = 'grabbag';

/// Pack id for an INI entry. An explicit `Pack =` (id or name, any case) wins;
/// otherwise the legacy `Category =` is converted; full phrases are Handy
/// Phrases; everything else is the Grab Bag.
String packIdForIni({String pack = '', String category = '', bool isFullPhrase = false}) {
  final p = pack.trim().toLowerCase();
  if (p.isNotEmpty) {
    for (final b in builtInBundles) {
      if (b.id == p || b.name.toLowerCase() == p) return b.id;
    }
    final renamed = renamedBundles[p];
    if (renamed != null) return renamed;
  }
  if (isFullPhrase) return phrasesBundleId;
  final c = category.trim().toLowerCase();
  if (c.isNotEmpty) {
    for (final b in builtInBundles) {
      if (b.legacyCategories.any((x) => x.toLowerCase() == c)) return b.id;
    }
  }
  return grabBagBundleId;
}

/// Built-in pack id whose id or name (any case) is [pack], or null.
String? builtInPackIdFor(String pack) {
  final p = pack.trim().toLowerCase();
  if (p.isEmpty) return null;
  for (final b in builtInBundles) {
    if (b.id == p || b.name.toLowerCase() == p) return b.id;
  }
  return renamedBundles[p];
}

/// Built-in pack whose name or old category matches [category] (migration of
/// custom words saved with a category), or null.
String? builtInPackForLegacyCategory(String category) {
  final c = category.trim().toLowerCase();
  if (c.isEmpty) return null;
  for (final b in builtInBundles) {
    if (b.name.toLowerCase() == c || b.id == c) return b.id;
    if (b.legacyCategories.any((x) => x.toLowerCase() == c)) return b.id;
  }
  return renamedBundles[c];
}

WordBundle? builtInBundleById(String id) {
  for (final b in builtInBundles) {
    if (b.id == id) return b;
  }
  return null;
}
