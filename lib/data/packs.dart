import 'bundles.dart';

/// A Word Pack the player created from the New Word screen. Packs cannot be
/// renamed or deleted by hand; one that runs out of words disappears.
class UserPack {
  final String id;
  final String name;
  final String emoji;

  /// A Verb Pack (made from the Edit Verb screen): listed with the Verb Packs.
  final bool isVerb;
  const UserPack({required this.id, required this.name, required this.emoji, this.isVerb = false});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    if (isVerb) 'verb': true,
  };

  factory UserPack.fromJson(Map<String, dynamic> j) => UserPack(
    id: (j['id'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    emoji: (j['emoji'] ?? '📦') as String,
    isVerb: j['verb'] == true,
  );
}

const String myWordsName = 'My Words';
const String myWordsEmoji = '✏️';
const String userPackPrefix = 'user_';

bool isUserPackId(String id) => id.startsWith(userPackPrefix);

enum PackKind { myWords, builtIn, user, newPack }

/// Where a word typed into the "Word Pack" field ends up.
class PackChoice {
  final PackKind kind;

  /// Pack id; empty for [PackKind.newPack] (assigned when it is created).
  final String id;

  /// Display name (for a new pack: what the player typed, tidied up).
  final String name;

  /// Emoji the player typed in front of a new pack's name, if any.
  final String typedEmoji;
  const PackChoice(this.kind, this.id, this.name, {this.typedEmoji = ''});

  @override
  String toString() => 'PackChoice($kind, $id, $name)';
}

final _leadingSymbols = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);
final _spaces = RegExp(r'\s+');

/// Leading emoji / symbols removed, inner whitespace collapsed, trimmed.
String tidyPackName(String input) =>
    input.trim().replaceFirst(_leadingSymbols, '').trim().replaceAll(_spaces, ' ');

/// Case-insensitive comparison key for pack names.
String packKey(String input) => tidyPackName(input).toLowerCase();

/// Resolves the "Word Pack" field: trimmed, case ignored, a leading emoji
/// ignored. Blank or "My Words" -> My Words; an existing built-in or user
/// pack name -> that pack; anything else -> a brand-new pack.
/// With [verbs] (the Edit Verb screen) only Verb Packs match, and a blank
/// field or "My Words" gives a new pack with no name (the screen refuses it).
PackChoice resolvePackInput(String input, {required List<UserPack> userPacks, bool verbs = false}) {
  final key = packKey(input);
  if (verbs) {
    for (final b in builtInBundles) {
      if (b.isVerbPack && packKey(b.name) == key) return PackChoice(PackKind.builtIn, b.id, b.name);
    }
    for (final p in userPacks) {
      if (p.isVerb && packKey(p.name) == key) return PackChoice(PackKind.user, p.id, p.name);
    }
    if (key.isEmpty || key == packKey(myWordsName)) {
      return const PackChoice(PackKind.newPack, '', '');
    }
  } else if (key.isEmpty || key == packKey(myWordsName)) {
    return const PackChoice(PackKind.myWords, customBundleId, myWordsName);
  }
  for (final b in builtInBundles) {
    if (packKey(b.name) == key) return PackChoice(PackKind.builtIn, b.id, b.name);
  }
  for (final p in userPacks) {
    if (packKey(p.name) == key) return PackChoice(PackKind.user, p.id, p.name);
  }
  final trimmed = input.trim();
  final lead = _leadingSymbols.firstMatch(trimmed)?.group(0)?.trim() ?? '';
  return PackChoice(PackKind.newPack, '', tidyPackName(input), typedEmoji: lead);
}
