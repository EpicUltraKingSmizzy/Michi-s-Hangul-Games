/// One vocabulary item. Mirrors the VB.NET `VocabEntry` structure, with the
/// old Category replaced by the Word Pack the word belongs to ([packId]).
class VocabEntry {
  final String sectionName;
  final String packId;
  final String english1;
  final String english2;
  final String emoji;
  final String korean1;
  final String korean2;
  final bool isFullPhrase;

  /// Other built-in packs this word also belongs to (besides [packId]).
  /// The word is still one card: one entry in play, one set of wins.
  final List<String> alsoPacks;

  const VocabEntry({
    this.sectionName = '',
    this.packId = '',
    this.english1 = '',
    this.english2 = '',
    this.emoji = '',
    this.korean1 = '',
    this.korean2 = '',
    this.isFullPhrase = false,
    this.alsoPacks = const [],
  });

  /// Every pack this word is in: its home pack first, then [alsoPacks].
  List<String> get packIds => [packId, ...alsoPacks.where((p) => p != packId)];

  bool inPack(String id) => packId == id || alsoPacks.contains(id);

  VocabEntry copyWith({
    String? sectionName,
    String? packId,
    String? english1,
    String? english2,
    String? emoji,
    String? korean1,
    String? korean2,
    bool? isFullPhrase,
    List<String>? alsoPacks,
  }) => VocabEntry(
    sectionName: sectionName ?? this.sectionName,
    packId: packId ?? this.packId,
    english1: english1 ?? this.english1,
    english2: english2 ?? this.english2,
    emoji: emoji ?? this.emoji,
    korean1: korean1 ?? this.korean1,
    korean2: korean2 ?? this.korean2,
    isFullPhrase: isFullPhrase ?? this.isFullPhrase,
    alsoPacks: alsoPacks ?? this.alsoPacks,
  );

  Map<String, dynamic> toJson() => {
    'sectionName': sectionName,
    'packId': packId,
    'english1': english1,
    'english2': english2,
    'emoji': emoji,
    'korean1': korean1,
    'korean2': korean2,
    'isFullPhrase': isFullPhrase,
    if (alsoPacks.isNotEmpty) 'alsoPacks': alsoPacks,
  };

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
    sectionName: (j['sectionName'] ?? '') as String,
    packId: (j['packId'] ?? '') as String,
    english1: (j['english1'] ?? '') as String,
    english2: (j['english2'] ?? '') as String,
    emoji: (j['emoji'] ?? '') as String,
    korean1: (j['korean1'] ?? '') as String,
    korean2: (j['korean2'] ?? '') as String,
    isFullPhrase: (j['isFullPhrase'] ?? false) as bool,
    alsoPacks: [for (final p in (j['alsoPacks'] as List?) ?? const []) '$p'],
  );

  /// Old saves (before Word Packs) stored a free-text category instead.
  static String legacyCategoryOf(Map<String, dynamic> j) => (j['categoryName'] ?? '') as String;

  @override
  bool operator ==(Object other) =>
      other is VocabEntry &&
      other.sectionName == sectionName &&
      other.packId == packId &&
      other.english1 == english1 &&
      other.english2 == english2 &&
      other.emoji == emoji &&
      other.korean1 == korean1 &&
      other.korean2 == korean2 &&
      other.isFullPhrase == isFullPhrase &&
      other.alsoPacks.length == alsoPacks.length &&
      Iterable.generate(alsoPacks.length).every((i) => other.alsoPacks[i] == alsoPacks[i]);

  @override
  int get hashCode => Object.hash(
    sectionName,
    packId,
    english1,
    english2,
    emoji,
    korean1,
    korean2,
    isFullPhrase,
    Object.hashAll(alsoPacks),
  );

  @override
  String toString() => 'VocabEntry($sectionName: $english1 = $korean1)';
}
