import 'dart:async';
import 'dart:math';

import 'game_engine.dart';
import '../data/speaker.dart';

final _digit = RegExp(r'^[0-9]$');

/// 7️⃣/8️⃣ digit-button rounds get the phone keypad.
bool isKeypadRound(TypingRound r) =>
    r.charButtons.isNotEmpty && !r.answerIsKorean && r.charButtons.every(_digit.hasMatch);

/// 5️⃣/6️⃣ letter-tile rounds get answer slots.
/// 5️⃣/6️⃣: read a placed syllable aloud, except on the winning tap when the
/// win readout (Spoken Answer) is about to say the whole word anyway.
bool shouldSpeakSyllable(String syllable, {required bool winsNow, required bool spokenAnswer}) =>
    spokenAnswer && containsHangul(syllable) && !winsNow;

bool isSlotRound(TypingRound r) => r.charButtons.isNotEmpty && !isKeypadRound(r);

/// One slot per (non-space) answer character.
int slotCount(TypingRound r) => r.answer1.split('').where((c) => c.trim().isNotEmpty).length;

/// Answer slots for the tile games (5️⃣/6️⃣).
///
/// One slot per answer character. A tapped tile drops into the first empty
/// slot; tapping a filled slot sends that tile back to the pile and leaves a
/// gap where it was (later letters do not move), and the next tile tapped
/// fills that gap. ⌫ takes back the right-most filled slot.
class TileSlots {
  final List<String> tiles;
  final List<int?> _slots;

  TileSlots(this.tiles, int length) : _slots = List<int?>.filled(length, null);

  int get length => _slots.length;

  /// Tile index in slot [i], or null if the slot is empty.
  int? tileAt(int i) => _slots[i];
  String? charAt(int i) => _slots[i] == null ? null : tiles[_slots[i]!];

  bool isUsed(int tileIndex) => _slots.contains(tileIndex);
  bool get isFull => !_slots.contains(null);
  bool get isEmpty => _slots.every((s) => s == null);

  /// The letters currently in the slots, left to right (gaps skipped).
  String get text => [
    for (final s in _slots)
      if (s != null) tiles[s],
  ].join();

  /// Puts tile [tileIndex] into the first empty slot. Returns the slot used,
  /// or -1 when the tile is already placed or every slot is full.
  int place(int tileIndex) {
    if (isUsed(tileIndex)) return -1;
    final i = _slots.indexOf(null);
    if (i < 0) return -1;
    _slots[i] = tileIndex;
    return i;
  }

  /// Returns the tile in slot [slot] to the pile.
  void removeAt(int slot) => _slots[slot] = null;

  /// ⌫: empties the right-most filled slot.
  void backspace() {
    final i = _slots.lastIndexWhere((s) => s != null);
    if (i >= 0) _slots[i] = null;
  }

  void clear() => _slots.fillRange(0, _slots.length, null);

  /// Hint: sends back to the pile every placed tile that is not where an
  /// accepted answer has it. [answers] are the accepted answers, one piece
  /// per slot (a shorter answer leaves the slots after it empty). The answer
  /// agreeing with the most placed tiles is followed, so what stays can
  /// always be finished into an accepted answer. Returns the slots emptied.
  List<int> removeWrong(Iterable<List<String>> answers) {
    List<int> wrongFor(List<String> a) => [
      for (var i = 0; i < _slots.length; i++)
        if (_slots[i] != null && (i >= a.length || tiles[_slots[i]!] != a[i])) i,
    ];
    List<int>? best;
    for (final a in answers) {
      final w = wrongFor(a);
      if (best == null || w.length < best.length) best = w;
    }
    final out =
        best ??
        [
          for (var i = 0; i < _slots.length; i++)
            if (_slots[i] != null) i,
        ];
    for (final i in out) {
      _slots[i] = null;
    }
    return out;
  }
}

/// Consecutive right answers in one visit to a game.
///
/// +1 for every round won (a whole 3️⃣ round of five repetitions counts once).
/// Reset by a wrong attempt, by skipping with ➡️, and by leaving the game
/// (a new game screen starts a new counter).
class Streak {
  int count = 0;
  int best = 0;

  void hit() {
    count++;
    if (count > best) best = count;
  }

  void miss() => count = 0;

  /// 🔥 badge text; null below 2 (a single right answer is not a combo yet).
  String? get label => count >= 2 ? '🔥×$count' : null;

  /// Every fifth answer in a row gets a big cheer.
  bool get isMilestone => count > 0 && count % 5 == 0;
}

/// How long a won round stays on screen before the next one.
class WinPause {
  static const quick = Duration(milliseconds: 300);

  /// Used when TTS is unavailable, fails, or never reports that it started.
  static const speechFallback = Duration(milliseconds: 1500);

  /// Upper bound on waiting for the voice to finish (long phrases / an engine
  /// that starts but never reports completion).
  static const speechCap = Duration(seconds: 5);

  /// Spoken Answer off: 300 ms. On: speaks via [speak] straight away and ends
  /// the moment the voice finishes (no minimum). If TTS fails / is missing /
  /// never starts, ends ~[speechFallback] after the win; never longer than
  /// [speechCap].
  static Future<void> run({required bool spokenAnswer, required SpeechTracking Function() speak}) {
    if (!spokenAnswer) return Future<void>.delayed(quick);
    final done = Completer<void>();
    var started = false;
    var failed = false;
    var fallbackElapsed = false;
    Timer? fallbackTimer;
    Timer? capTimer;
    void finish() {
      if (done.isCompleted) return;
      fallbackTimer?.cancel();
      capTimer?.cancel();
      done.complete();
    }

    fallbackTimer = Timer(speechFallback, () {
      fallbackElapsed = true;
      if (failed || !started) finish();
    });
    capTimer = Timer(speechCap, finish);

    void onFailed() {
      failed = true;
      if (fallbackElapsed) finish();
    }

    SpeechTracking s;
    try {
      s = speak();
    } catch (_) {
      onFailed();
      return done.future;
    }
    s.started.then((_) => started = true, onError: (_) {});
    s.finished.then((ok) => ok ? finish() : onFailed(), onError: (_) => onFailed());
    return done.future;
  }
}

/// 🔀 Shuffle: a random game among those switched on for Shuffle ([enabled],
/// ⚙️ Options › 🔀 Shuffle games) and playable right now ([canPlay]: 1️⃣-6️⃣
/// need enough words, 7️⃣ 8️⃣ 9️⃣ always play). Any game may come up twice in
/// a row except 3️⃣ (unless it is the only one left). Null when no switched-on
/// game can be played.
int? pickShuffleGame(
  Random rand, {
  int? previous,
  bool Function(int game)? enabled,
  required bool Function(int game) canPlay,
}) {
  final open = [
    for (var g = 1; g <= GameEngine.gameCount; g++)
      if ((enabled?.call(g) ?? true) && canPlay(g)) g,
  ];
  if (open.isEmpty) return null;
  final games = previous == 3 && open.length > 1 ? (open..remove(3)) : open;
  return games[rand.nextInt(games.length)];
}
