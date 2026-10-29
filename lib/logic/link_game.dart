import '../models/vocab_entry.dart';

/// One pair on a 🔟 🔗 Link Up board: a word's Korean (left) and its emoji
/// or English (right), exactly as shown.
class LinkPair {
  final VocabEntry word;
  final String korean;
  final String english;
  const LinkPair({required this.word, required this.korean, required this.english});
}

/// A 🔟 🔗 Link Up board: [pairs] down the left in this order, their
/// emoji / English down the right in [rightOrder] (rightOrder[slot] is the
/// pair shown in that right-hand slot).
class LinkRound {
  /// Pairs on one board.
  static const size = 6;

  /// How long a wrong line stays red before it disappears.
  static const wrongFlash = Duration(seconds: 1);

  final List<LinkPair> pairs;
  final List<int> rightOrder;
  const LinkRound({required this.pairs, required this.rightOrder});

  String leftText(int i) => pairs[i].korean;
  String rightText(int slot) => pairs[rightOrder[slot]].english;

  /// True when the Korean on the left in row [left] belongs with the right
  /// slot [right].
  bool matches(int left, int right) => rightOrder[right] == left;

  /// Every word on the board (all of them count as won when it's cleared).
  List<VocabEntry> get words => [for (final p in pairs) p.word];
}

enum LinkResult {
  /// A right line: locked in.
  linked,

  /// A wrong line: flashes red and disappears.
  wrong,

  /// One end was already locked in: nothing happens.
  ignored,
}

/// The lines locked in so far on a [LinkRound] (UI-free).
class LinkBoard {
  final LinkRound round;

  /// Left row → right slot, in the order they were locked in.
  final Map<int, int> locked = {};
  LinkBoard(this.round);

  bool leftLocked(int left) => locked.containsKey(left);
  bool rightLocked(int right) => locked.containsValue(right);

  /// Order (0, 1, …) in which [left]'s line was locked in; null when it isn't.
  int? lockOrder(int left) {
    var i = 0;
    for (final k in locked.keys) {
      if (k == left) return i;
      i++;
    }
    return null;
  }

  LinkResult tryLink(int left, int right) {
    if (leftLocked(left) || rightLocked(right)) return LinkResult.ignored;
    if (!round.matches(left, right)) return LinkResult.wrong;
    locked[left] = right;
    return LinkResult.linked;
  }

  bool get complete => locked.length == round.pairs.length;
}
