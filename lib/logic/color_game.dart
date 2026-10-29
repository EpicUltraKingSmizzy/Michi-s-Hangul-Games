import 'dart:math';

/// One colour of 9️⃣ 🎨 Color match. [argb] is what the player sees;
/// [korean] is the ~색 name and [short] the short name (null when Korean has
/// no everyday short form, e.g. 갈색, 회색). [english] is what a tap on the
/// colour box peeks at.
class GameColor {
  final String id;
  final int argb;
  final String korean;
  final String? short;
  final String english;
  const GameColor(this.id, this.argb, this.korean, this.short, this.english);

  /// Light colours (white, yellow) get an outline so they stand out on the
  /// light background.
  bool get isLight {
    final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
    return (0.299 * r + 0.587 * g + 0.114 * b) > 200;
  }

  /// Text on this colour reads best in black (true) or white: whichever has
  /// the higher WCAG contrast ratio against it.
  bool get wantsDarkText {
    double ch(int shift) {
      final v = ((argb >> shift) & 0xFF) / 255;
      return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final l = 0.2126 * ch(16) + 0.7152 * ch(8) + 0.0722 * ch(0);
    return (l + 0.05) / 0.05 >= 1.05 / (l + 0.05);
  }

  String name({required bool shortForm}) => shortForm ? short! : korean;
}

/// The game's own 12 colours, independent of Word Packs. Picked to be easy to
/// tell apart on screen.
const List<GameColor> gameColors = [
  GameColor('red', 0xFFE53935, '빨간색', '빨강', 'Red'),
  GameColor('orange', 0xFFFF8F00, '주황색', '주황', 'Orange'),
  GameColor('yellow', 0xFFFFEB3B, '노란색', '노랑', 'Yellow'),
  GameColor('green', 0xFF2E9D3A, '초록색', '초록', 'Green'),
  GameColor('teal', 0xFF00A39A, '청록색', '청록', 'Teal'),
  GameColor('blue', 0xFF1E56E8, '파란색', '파랑', 'Blue'),
  GameColor('purple', 0xFF8E2DB5, '보라색', '보라', 'Purple'),
  GameColor('pink', 0xFFFF80BF, '분홍색', '분홍', 'Pink'),
  GameColor('brown', 0xFF7A4A21, '갈색', null, 'Brown'),
  GameColor('white', 0xFFFFFFFF, '흰색', '하양', 'White'),
  GameColor('gray', 0xFF9A9A9A, '회색', null, 'Gray'),
  GameColor('black', 0xFF151515, '검은색', '검정', 'Black'),
];

/// A 9️⃣ round. When [colorInBox] the prompt box is painted [target] and the
/// buttons show Korean names; otherwise the box shows the Korean name and the
/// buttons are painted in [options]' colours. One wording style
/// ([shortForm]) is used for the whole round.
class ColorRound {
  final GameColor target;
  final List<GameColor> options;
  final bool colorInBox;
  final bool shortForm;
  const ColorRound({
    required this.target,
    required this.options,
    required this.colorInBox,
    required this.shortForm,
  });

  String nameOf(GameColor c) => c.name(shortForm: shortForm);
  String get answer => nameOf(target);
}

/// Builds a round: random mode, random wording style, target + 2 different
/// decoys. Short-form rounds leave out colours with no short name. Targets
/// in [recent] are avoided when possible.
ColorRound newColorRound(Random rand, {Iterable<String> recent = const []}) {
  final shortForm = rand.nextBool();
  final pool = gameColors.where((c) => !shortForm || c.short != null).toList();
  final fresh = pool.where((c) => !recent.contains(c.id)).toList();
  final target = (fresh.isEmpty
      ? pool
      : fresh)[rand.nextInt((fresh.isEmpty ? pool : fresh).length)];
  final decoys = (pool.where((c) => c.id != target.id).toList()..shuffle(rand)).take(2);
  return ColorRound(
    target: target,
    options: [target, ...decoys]..shuffle(rand),
    colorInBox: rand.nextBool(),
    shortForm: shortForm,
  );
}
