import 'dart:collection';
import 'dart:math';

import '../data/bundles.dart' show customBundleId;
import '../models/vocab_entry.dart';
import 'color_game.dart';
import 'link_game.dart';
import 'sentences.dart';
import 'time_game.dart';

export 'color_game.dart';
export 'link_game.dart';
export 'sentences.dart';
export 'time_game.dart';
import 'number_translation.dart';

/// A multiple-choice round (formats of the original games 1 & 2).
class ChoiceRound {
  final String prompt;
  final bool promptIsKorean;
  final List<String> options;
  final String correctAnswer;
  final bool optionsAreKorean;

  /// The English word behind an emoji [prompt] (tap the emoji to peek);
  /// '' when the prompt isn't an emoji or the English adds nothing.
  final String promptEnglish;

  /// The word this round is about (its wins go to its Word Packs); null for
  /// generated rounds (7️⃣/8️⃣ numbers).
  final VocabEntry? word;
  const ChoiceRound({
    this.word,
    this.promptEnglish = '',
    required this.prompt,
    required this.promptIsKorean,
    required this.options,
    required this.correctAnswer,
    required this.optionsAreKorean,
  });
}

/// A text-box round (formats of the original games 3, 4, 5, 6 and the
/// digit-button number format).
class TypingRound {
  final String prompt;
  final bool promptIsKorean;

  /// Item1: the "official" answer (shown by the hint, built by the buttons).
  final String answer1;

  /// Item2: an alternative accepted answer ('' if none).
  final String answer2;
  final bool answerIsKorean;
  final bool showHintAtStart;
  final int repetitions;

  /// Helper character buttons (empty = no buttons).
  final List<String> charButtons;

  /// Answers of other entries that share the exact same prompt (e.g. "1" is
  /// both 일 and 하나; "Rice" is both 밥 and 쌀 with ⚙️ Bracket notes off).
  /// Typing any of them is correct.
  final List<String> alsoAccepted;

  /// The English word behind an emoji [prompt] (tap the emoji to peek);
  /// '' when the prompt isn't an emoji or the English adds nothing.
  final String promptEnglish;

  /// The word this round is about (its wins go to its Word Packs); null for
  /// generated rounds (7️⃣/8️⃣ numbers).
  final VocabEntry? word;
  const TypingRound({
    this.word,
    this.alsoAccepted = const [],
    this.promptEnglish = '',
    required this.prompt,
    required this.promptIsKorean,
    required this.answer1,
    required this.answer2,
    required this.answerIsKorean,
    required this.showHintAtStart,
    required this.repetitions,
    required this.charButtons,
  });
}

/// A 🏗️ Sentence Builder round: the English to build, the slot tiles in
/// the usual order (the verb is pre-placed) and the tile pile with decoys.
class SentenceRound {
  final Sentence sentence;

  /// Answer tiles and decoys, shuffled.
  final List<String> tiles;

  /// The verb's word (its wins go to its Verb Pack).
  final VocabEntry? word;
  const SentenceRound({required this.sentence, required this.tiles, this.word});

  /// The correct tile per slot, in the usual order.
  List<String> get answer => sentence.answerTiles;
}

/// Pure (UI-free) port of the LINQPad game logic.
class GameEngine {
  static const int answerCount = 3; // Game 1 & 2 option count
  static const int gameHistoryCount = 5;
  static const int minimumCharacterScrambleLength = 2;
  static const int maximumCharacterScrambleLength = 10;

  /// 3️⃣ ✍️: correct typings needed per word (⚙️ Options slider, 1-5).
  static const int defaultGame3Repetitions = 3;
  static const int minGame3Repetitions = 1;
  static const int maxGame3Repetitions = 5;

  /// 7️⃣ 🔢: the most digits a Sino number can have (⚙️ Options slider, 1-8).
  static const int defaultGame7MaxDigits = 6;
  static const int minGame7MaxDigits = 1;
  static const int maxGame7MaxDigits = 8;

  /// 8️⃣ 🖐️ (native numbers): 1-2 digits, fixed.
  static const int game8MaxDigits = 2;

  /// 8️⃣ Native numbers: the top number (inclusive), one of [nativeMaxStops].
  static const nativeMaxStops = [10, 30, 50, 99];
  static const defaultNativeMax = 10;
  static const int newGameDelayMs = 300;
  static const int gameCount = 11;

  /// 🏗️ Sentence Builder: build a Korean sentence from word tiles.
  static const int sentenceGame = 11;

  /// Sentences in 🔟 🔗 Link Up and the syllable games stay this short.
  static const int maxSentenceSyllables = maximumCharacterScrambleLength;
  static const int maxLinkSentenceEnglish = 24;

  /// 🔟 🔗 Link Up: match [LinkRound.size] Korean words to their emoji/English.
  static const int linkUpGame = 10;

  /// 🔟 remembers two boards of words, so a board doesn't repeat right away.
  static const int linkHistoryCount = 2 * LinkRound.size;

  final Random rand;

  /// Repetitions for new 3️⃣ rounds; a round in progress keeps its own count.
  int game3Repetitions = defaultGame3Repetitions;

  /// 7️⃣: numbers have 1..[game7MaxDigits] digits, each length equally likely.
  int game7MaxDigits = defaultGame7MaxDigits;

  /// 8️⃣: numbers are 1..[nativeMax] (inclusive), all equally likely.
  int nativeMax = defaultNativeMax;

  /// Every word in play (the Word Packs that are on).
  List<VocabEntry> vocabList;

  /// ⚙️ Options 😀 Emoji: when false, words show their English instead of
  /// their emoji, in prompts and in 1️⃣'s answer buttons.
  bool useEmoji = true;

  /// ⚙️ Options 📑 Bracket notes: when false, English is shown without its
  /// notes in brackets ("Car (vehicle)" → "Car"). The stored words never change.
  bool showBracketNotes = true;

  /// [e]'s English as the player sees it (see [showBracketNotes]).
  String shownEnglish(VocabEntry e) =>
      showBracketNotes ? e.english1 : stripBracketNotes(e.english1);

  /// The words games 1-6 draw from. With emojis off, a word with no real
  /// English (empty, or only an emoji) sits out, so no emoji leaks through.
  /// A Verb Pack verb is in play as a sentence (see [verbOf]) when it can
  /// make one at [sentenceLevel].
  List<VocabEntry> get playList => [
    for (final e in vocabList)
      if ((useEmoji || hasPlainEnglish(e)) && _verbFits(e)) e,
  ];

  // ---------------------------------------------------------------- 🏗️ sentences

  /// 🏗️ data (null until the app loads it: then no verbs and no 🏗️).
  SentenceBank? get sentenceBank => _bank;
  set sentenceBank(SentenceBank? b) {
    _bank = b;
    _verbBySection = {for (final v in b?.verbs ?? const <SentenceVerb>[]) v.section: v};
  }

  SentenceBank? _bank;
  Map<String, SentenceVerb> _verbBySection = {};

  /// 🏗️ difficulty (Easy..Master), also for verbs in the other games.
  int sentenceLevel = sentenceEasy;

  /// Every Verb Pack word by section (switched on or not).
  Map<String, VocabEntry> verbWords = {};

  /// The verb behind a Verb Pack word in play; null for every other word.
  SentenceVerb? verbOf(VocabEntry e) => _verbBySection[e.sectionName];

  bool _verbFits(VocabEntry e) {
    final v = verbOf(e);
    return v == null || SentenceMaker.canMake(v, sentenceLevel);
  }

  /// [playList] without the verbs: the decoys for ordinary words.
  List<VocabEntry> get _wordsOnly => [
    for (final e in playList)
      if (verbOf(e) == null) e,
  ];

  /// The sentence behind a generated sentence entry (for its other orders).
  final Expando<Sentence> _sentenceOf = Expando();

  /// Nouns of the Word Packs that are on (🏗️ prefers these).
  bool Function(SentenceNoun) _preferredNouns() {
    final active = {for (final e in vocabList) e.sectionName};
    return (n) => n.sections.any(active.contains);
  }

  /// A sentence for [verb] at [sentenceLevel] that [fits]; failing that,
  /// at a lower level (so a syllable game gets a short one). Null if none.
  Sentence? makeSentence(SentenceVerb verb, {bool Function(Sentence)? fits}) {
    final maker = SentenceMaker(rand);
    final preferred = _preferredNouns();
    for (var level = sentenceLevel; level >= sentenceEasy; level--) {
      for (var i = 0; i < 12; i++) {
        final s = maker.make(verb, level, preferred: preferred);
        if (s == null) break;
        if (fits == null || fits(s)) return s;
      }
    }
    return null;
  }

  /// A word-like entry for [s]: Korean and English of the whole sentence,
  /// counting for [word] (the verb) and its Verb Pack.
  VocabEntry sentenceEntry(Sentence s, VocabEntry word) {
    final e = VocabEntry(
      sectionName: word.sectionName,
      packId: word.packId,
      alsoPacks: word.alsoPacks,
      english1: s.english,
      korean1: s.korean,
      isFullPhrase: true,
    );
    _sentenceOf[e] = s;
    return e;
  }

  /// [e] itself, or for a verb a sentence entry that [fits] (null if the
  /// verb can't make one).
  VocabEntry? _asPlayed(VocabEntry e, {bool Function(Sentence)? fits}) {
    final v = verbOf(e);
    if (v == null) return e;
    final s = makeSentence(v, fits: fits);
    return s == null ? null : sentenceEntry(s, e);
  }

  /// Fits the 🧩/🌀 slots: at most [maxSentenceSyllables] syllables.
  static bool shortSentence(Sentence s) => stripSpaces(s.korean).length <= maxSentenceSyllables;

  /// Fits a 🔗 card.
  static bool linkSentence(Sentence s) =>
      shortSentence(s) && s.english.length <= maxLinkSentenceEnglish;

  /// Up to [count] sentences of other verbs (in play first, then any), for
  /// decoys next to sentence [target]. Never single words.
  List<VocabEntry> otherSentences(VocabEntry target, int count, {bool Function(Sentence)? fits}) {
    final own = verbOf(target);
    final inPlay = _shuffled(playList.where((e) => verbOf(e) != null && verbOf(e) != own));
    final rest = _shuffled(
      verbWords.values.where((e) => verbOf(e) != null && verbOf(e) != own && !inPlay.contains(e)),
    );
    final out = <VocabEntry>[target];
    for (final w in [...inPlay, ...rest]) {
      if (out.length > count) break;
      final s = makeSentence(verbOf(w)!, fits: fits);
      if (s == null) continue;
      final e = sentenceEntry(s, w);
      if (out.any(
        (o) => entriesClash(o, e, useEmoji: useEmoji, showBracketNotes: showBracketNotes),
      )) {
        continue;
      }
      out.add(e);
    }
    return out.sublist(1);
  }

  /// The verbs of the Verb Packs that are on, usable at [sentenceLevel].
  List<VocabEntry> get _sentenceVerbs => [
    for (final e in vocabList)
      if (verbOf(e) case final v? when SentenceMaker.canMake(v, sentenceLevel)) e,
  ];

  /// 🏗️ needs at least one Verb Pack on (with a verb usable at
  /// [sentenceLevel]).
  bool get hasSentenceVerbs => _bank != null && _sentenceVerbs.isNotEmpty;

  /// 🏗️: a sentence for a verb of the Verb Packs that are on, not one of
  /// the last few, at [sentenceLevel]; nouns from the Word Packs that are
  /// on when the verb can use them.
  SentenceRound sentenceRound() {
    final pool = _sentenceVerbs;
    final history = gameHistory[sentenceGame]!;
    var valid = pool.where((e) => !history.contains(e.sectionName)).toList();
    if (valid.isEmpty) {
      history.clear();
      valid = pool;
    }
    final word = valid[rand.nextInt(valid.length)];
    logGameTarget(word.sectionName);
    final s = makeSentence(verbOf(word)!)!;
    return SentenceRound(
      sentence: s,
      tiles: _shuffled([...s.answerTiles, ...s.decoys]),
      word: word,
    );
  }

  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// True when [e]'s English has at least one letter or digit.
  static bool hasPlainEnglish(VocabEntry e) => _letterOrDigit.hasMatch(e.english1);
  final Map<int, ListQueue<String>> gameHistory = {
    for (var i = 1; i <= gameCount; i++) i: ListQueue<String>(),
  };
  int currentGame = 0;

  GameEngine(this.vocabList, {Random? random}) : rand = random ?? Random();

  /// EntryMinimumCheck
  bool get hasEnoughEntries => playList.length >= answerCount;

  /// 7️⃣/8️⃣ generate their own numbers and 9️⃣ uses its own colours; none
  /// of them touch [vocabList];
  /// games 1-6 need at least [answerCount] words.
  /// The Link Up board needs a full board of [LinkRound.size] words that
  /// can't be mixed up, all of one kind (see [canLinkUp]).
  static bool usesVocab(int game) => (game <= 6 && game != timeGame) || game == linkUpGame;

  /// 2️⃣ 🕒 What Time Is It? (number 2 was 🎯 Pick the Korean, whose format
  /// is now half of 🔍 Pick the meaning's rounds).
  static const int timeGame = 2;

  /// Tests only: pin 1️⃣'s format (true = emoji/English → pick the Korean,
  /// false = Korean → pick the meaning). Null picks at random each round.
  static bool? pickKoreanFormat;
  bool canPlay(int game) {
    if (game == sentenceGame) return hasSentenceVerbs;
    if (!usesVocab(game)) return true;
    if (game == linkUpGame) return canLinkUp;
    return hasEnoughEntries;
  }

  /// Builds the next round for [game] (1-11). Returns a [ChoiceRound], a
  /// [TypingRound], (9️⃣) a [ColorRound] or (🏗️) a [SentenceRound].
  Object newRound(int game) {
    currentGame = game;
    switch (game) {
      case 1:
        // 🔍 Pick the meaning: Korean → pick the meaning, or (the old 🎯
        // Pick the Korean) emoji/English → pick the Korean, at random.
        final t = _playedTarget();
        // A sentence's wrong answers are other sentences, never words.
        final wrong = _sentenceOf[t] != null
            ? otherSentences(t, 2)
            : getWrongAnswers(t, _wordsOnly);
        return matchingGame(t, wrong, pickKoreanFormat ?? rand.nextBool());
      case timeGame:
        return newTimeRound(rand, recent: gameHistory[timeGame]);
      case 3:
        return createTextBoxGame(_playedTarget(), gameRepetitionCount: game3Repetitions);
      case 4:
        return createTextBoxGame(_playedTarget(), showHintAtStart: false);
      case 5:
        return createTextBoxGame(_scrambleTarget(), showHintAtStart: false, helperButtons: true);
      case 6:
        final t = _scrambleTarget();
        return createTextBoxGame(
          t,
          showHintAtStart: false,
          helperButtons: true,
          includeWrongOptions: true,
          wrongOptions: _sentenceOf[t] == null ? null : _sentenceDecoyChars(t),
        );
      case 7:
        return numberGame();
      case 8:
        return numberGame(useNativeKorean: true);
      case 9:
        final history = gameHistory[9]!;
        final r = newColorRound(rand, recent: history);
        history.addLast(r.target.id);
        if (history.length > 3) history.removeFirst();
        return r;
      case linkUpGame:
        return linkRound();
      case sentenceGame:
        return sentenceRound();
      default:
        throw ArgumentError('Unknown game $game');
    }
  }

  // ---------------------------------------------------------------- helpers

  String _pickKorean(VocabEntry e) =>
      (e.korean2.isNotEmpty && rand.nextInt(2) == 0 ? e.korean2 : e.korean1).trim();

  String _englishSide(VocabEntry e) => useEmoji && e.emoji.isNotEmpty ? e.emoji : shownEnglish(e);

  /// The English to reveal when an emoji prompt is tapped: '' when the entry
  /// has no emoji (the prompt is already English), no English, or English
  /// that is just the emoji again. [showBracketNotes] false strips the notes.
  static String peekEnglish(VocabEntry e, {bool showBracketNotes = true}) {
    final en = (showBracketNotes ? e.english1 : stripBracketNotes(e.english1)).trim();
    if (e.emoji.trim().isEmpty || en.isEmpty) return '';
    if (stripSpaces(en).toLowerCase() == stripSpaces(e.emoji).toLowerCase()) return '';
    return en;
  }

  List<T> _shuffled<T>(Iterable<T> items) => items.toList()..shuffle(rand);

  /// FilteredVocabList
  List<VocabEntry> filteredVocabList({int minimumItemCount = 1}) {
    final history = gameHistory[currentGame]!;
    final play = playList;
    var valid = play.where((x) => !history.contains(x.sectionName)).toList();
    if (valid.length < minimumItemCount) {
      history.clear();
      valid = List.of(play);
    }
    return valid;
  }

  void logGameTarget(String target) {
    final history = gameHistory[currentGame]!;
    history.addLast(target);
    final max = currentGame == linkUpGame ? linkHistoryCount : gameHistoryCount;
    while (history.length > max) {
      history.removeFirst();
    }
  }

  /// GetGameTarget
  VocabEntry getGameTarget() {
    final valid = filteredVocabList();
    final target = valid[rand.nextInt(valid.length)];
    logGameTarget(target.sectionName);
    return target;
  }

  /// A target for 1️⃣ 3️⃣ 4️⃣: a verb comes as a sentence at [sentenceLevel].
  VocabEntry _playedTarget() {
    for (var i = 0; i < 5; i++) {
      final e = _asPlayed(getGameTarget());
      if (e != null) return e;
    }
    final words = _wordsOnly;
    return words.isEmpty ? getGameTarget() : words[rand.nextInt(words.length)];
  }

  /// Target selection for games 5 & 6 (with the Korean2 `<=` max fix). A
  /// verb comes as a short sentence (at most [maxSentenceSyllables]).
  VocabEntry _scrambleTarget() {
    final play = playList;
    var valid = filteredVocabList();
    bool okLen(String s) =>
        s.isNotEmpty &&
        s.length >= minimumCharacterScrambleLength &&
        s.length <= maximumCharacterScrambleLength;
    valid = valid.where((x) => verbOf(x) != null || okLen(x.korean1) || okLen(x.korean2)).toList();
    if (valid.isEmpty) valid = List.of(play);
    for (var i = 0; i < 5; i++) {
      final target = valid[rand.nextInt(valid.length)];
      final played = _asPlayed(target, fits: shortSentence);
      if (played == null) continue;
      logGameTarget(target.sectionName);
      return played;
    }
    final words = valid.where((x) => verbOf(x) == null).toList();
    final target = (words.isEmpty
        ? play
        : words)[rand.nextInt((words.isEmpty ? play : words).length)];
    logGameTarget(target.sectionName);
    return target;
  }

  /// 🌀 decoy letters for a sentence: from other sentences first (wrong
  /// particles and endings look alike), then from the words in play.
  List<String> _sentenceDecoyChars(VocabEntry target) {
    final a1 = stripSpaces(target.korean1);
    final need = max(3, a1.length);
    final wrong = getWrongCharacters(a1, target, otherSentences(target, 3), optionCount: need);
    if (wrong.length < need) {
      for (final c in getWrongCharacters(a1, target, _wordsOnly, optionCount: need)) {
        if (wrong.length == need) break;
        if (!wrong.contains(c)) wrong.add(c);
      }
    }
    return wrong;
  }

  /// True when two entries would look identical (or both be correct) in a
  /// multiple-choice round: same emoji/English side, or any shared Korean
  /// answer (homonyms such as 다리 = Leg / Bridge).
  /// With [useEmoji] off the English is what shows, so equal English clashes.
  /// With [showBracketNotes] off the English is compared without its notes
  /// (Rice (meal) and Rice (uncooked) both show "Rice").
  static bool entriesClash(
    VocabEntry a,
    VocabEntry b, {
    bool useEmoji = true,
    bool showBracketNotes = true,
  }) {
    String word(VocabEntry e) =>
        stripSpaces(showBracketNotes ? e.english1 : stripBracketNotes(e.english1)).toLowerCase();
    String en(VocabEntry e) =>
        useEmoji && e.emoji.isNotEmpty ? stripSpaces(e.emoji).toLowerCase() : word(e);
    Set<String> ko(VocabEntry e) =>
        {e.korean1, e.korean2}.map(stripSpaces).where((k) => k.isNotEmpty).toSet();
    // Same shown side; the same English word when at least one of them shows
    // English (부모 "Parents" next to 부모님 👫); or a shared Korean spelling
    // (homographs such as 차 tea / 차 car): the two would both look right.
    final bothEmoji = useEmoji && a.emoji.isNotEmpty && b.emoji.isNotEmpty;
    return en(a) == en(b) ||
        (!bothEmoji && word(a).isNotEmpty && word(a) == word(b)) ||
        ko(a).intersection(ko(b)).isNotEmpty;
  }

  /// GetWrongAnswers: decoys come first from the same Word Pack with the same
  /// IsFullPhrase, then the same IsFullPhrase from the other packs in play,
  /// then anything in play. Decoys never clash with the
  /// target or with each other (see [entriesClash]); only if the vocabulary is
  /// too small to avoid it are clashing entries used as a last resort.
  List<VocabEntry> getWrongAnswers(VocabEntry target, List<VocabEntry> list, {int count = 2}) {
    final others = list.where((x) => x.sectionName != target.sectionName).toList();
    final tiers = <bool Function(VocabEntry)>[
      (x) =>
          x.isFullPhrase == target.isFullPhrase &&
          (target.packId.isEmpty || target.packIds.any(x.inPack)),
      (x) => x.isFullPhrase == target.isFullPhrase,
      (x) => true,
    ];
    for (final tier in tiers) {
      final wrong = _pickDecoys(target, _shuffled(others.where(tier)), count);
      if (wrong.length == count) return wrong;
    }
    // Tiny vocabulary: fall back to the original behaviour.
    final pool = List.of(others);
    final wrong = <VocabEntry>[];
    while (wrong.length < count && pool.isNotEmpty) {
      wrong.add(pool.removeAt(rand.nextInt(pool.length)));
    }
    return wrong;
  }

  /// Takes up to [count] entries from [pool] in order, skipping any that
  /// clash with the target or with a decoy already taken.
  List<VocabEntry> _pickDecoys(VocabEntry target, List<VocabEntry> pool, int count) {
    bool clash(VocabEntry a, VocabEntry b) =>
        entriesClash(a, b, useEmoji: useEmoji, showBracketNotes: showBracketNotes);
    final wrong = <VocabEntry>[];
    for (final x in pool) {
      if (wrong.length == count) break;
      if (clash(x, target) || wrong.any((w) => clash(w, x))) continue;
      wrong.add(x);
    }
    return wrong;
  }

  /// 🔟: up to [LinkRound.size] words from [pool], taken in order, none
  /// clashing with another (see [entriesClash]: no two with the same emoji /
  /// English, the same English once bracket notes are hidden, or a shared
  /// Korean spelling), so every line has exactly one right partner.
  List<VocabEntry> linkWords(List<VocabEntry> pool) {
    bool clash(VocabEntry a, VocabEntry b) =>
        entriesClash(a, b, useEmoji: useEmoji, showBracketNotes: showBracketNotes);
    final picked = <VocabEntry>[];
    for (final x in pool) {
      if (picked.length == LinkRound.size) break;
      if (!picked.any((p) => clash(p, x))) picked.add(x);
    }
    return picked;
  }

  /// 🔟: the Word Packs a word counts toward on a board. Set by the app to
  /// the word's packs that are switched on (home pack, AlsoPacks, and
  /// ✏️ My Words for the player's own words); by default its [VocabEntry.packIds].
  Iterable<String> Function(VocabEntry e)? linkPacksOf;

  Iterable<String> _linkPacks(VocabEntry e) =>
      linkPacksOf?.call(e) ?? [for (final p in e.packIds) p.isEmpty ? customBundleId : p];

  bool _linkFills(List<VocabEntry> pool) => linkWords(pool).length == LinkRound.size;

  /// [words] split into the kinds (single words, full phrases) that can fill
  /// a whole board on their own.
  List<List<VocabEntry>> _linkKinds(Iterable<VocabEntry> words) {
    // Verbs come as sentences, so they go with the full phrases.
    final single = words.where((x) => !x.isFullPhrase && verbOf(x) == null).toList();
    final phrases = words.where((x) => x.isFullPhrase || verbOf(x) != null).toList();
    return [if (_linkFills(single)) single, if (_linkFills(phrases)) phrases];
  }

  /// Every pack with a word in play, in first-seen order.
  List<String> _linkPackIds(List<VocabEntry> play) =>
      {for (final w in play) ..._linkPacks(w)}.toList();

  /// 🔟 can deal a board: some single pack, or failing that all the packs in
  /// play together, has [LinkRound.size] words of one kind that can't be
  /// mixed up. (Same check [linkPool] makes, minus the dice.)
  bool get canLinkUp {
    final play = playList;
    if (_linkPackIds(play)
        .any((p) => _linkKinds(play.where((w) => _linkPacks(w).contains(p))).isNotEmpty)) {
      return true;
    }
    return _linkKinds(play).isNotEmpty;
  }

  /// 🔟: the words one board draws from. Packs in play are tried in random
  /// order; the first that can fill a board with all single words or all
  /// full phrases wins, and when it can do both the kind is a coin flip.
  /// When no single pack can, every word in play is pooled, still one kind
  /// only. Null when even that can't fill a board.
  List<VocabEntry>? linkPool() {
    final play = playList;
    List<VocabEntry>? pick(Iterable<VocabEntry> words) {
      final kinds = _linkKinds(words);
      return kinds.isEmpty ? null : kinds[rand.nextInt(kinds.length)];
    }

    for (final p in _shuffled(_linkPackIds(play))) {
      final pool = pick(play.where((w) => _linkPacks(w).contains(p)));
      if (pool != null) return pool;
    }
    return pick(play);
  }

  /// 🔟 🔗 Link Up: a board of [LinkRound.size] words picked at random from
  /// [linkPool] (one pack, one kind), preferring words not on the last
  /// boards. Korean on the left (Korean1 or Korean2, as in the matching
  /// games), the emoji/English side shuffled on the right.
  LinkRound linkRound() {
    final pool = linkPool();
    List<VocabEntry> words;
    if (pool == null) {
      words = linkWords(_shuffled(playList)); // not enough: canPlay is false
    } else {
      final history = gameHistory[linkUpGame]!;
      words = linkWords([
        ..._shuffled(pool.where((x) => !history.contains(x.sectionName))),
        ..._shuffled(pool.where((x) => history.contains(x.sectionName))),
      ]);
      // The pool is known to fill a board in its own order.
      if (words.length < LinkRound.size) words = linkWords(pool);
    }
    for (final w in words) {
      logGameTarget(w.sectionName);
    }
    // Verbs become short sentences that fit a card.
    words = [for (final w in words) _asPlayed(w, fits: linkSentence) ?? w];
    final pairs = [
      for (final w in words)
        LinkPair(
          word: w,
          korean: _pickKorean(w),
          english: _englishSide(w),
          plainEnglish: shownEnglish(w),
        ),
    ];
    return LinkRound(pairs: pairs, rightOrder: _shuffled(List.generate(pairs.length, (i) => i)));
  }

  /// MatchingGame. targetIsEnglish = prompt is emoji/English, options Korean.
  ChoiceRound matchingGame(VocabEntry target, List<VocabEntry> wrongEntries, bool targetIsEnglish) {
    final String prompt;
    final String correct;
    if (targetIsEnglish) {
      prompt = _englishSide(target);
      correct = _pickKorean(target);
    } else {
      prompt = _pickKorean(target);
      correct = _englishSide(target);
    }
    final options = <String>[correct];
    for (final w in wrongEntries) {
      options.add(targetIsEnglish ? _pickKorean(w) : _englishSide(w));
    }
    return ChoiceRound(
      word: _wordOf(target),
      promptEnglish: targetIsEnglish && useEmoji
          ? peekEnglish(target, showBracketNotes: showBracketNotes)
          : '',
      prompt: prompt,
      promptIsKorean: !targetIsEnglish,
      options: _shuffled(options),
      correctAnswer: correct,
      optionsAreKorean: targetIsEnglish,
    );
  }

  /// GetWrongCharacters, with the OptionCount bug fixed
  /// (count = max(3, answer length without spaces)) and no infinite loop:
  /// decoy characters are gathered from randomly ordered entries until enough
  /// are found or the vocabulary runs out.
  List<String> getWrongCharacters(
    String correctAnswer,
    VocabEntry target,
    List<VocabEntry> list, {
    int optionCount = -1,
    bool koreanCharacters = true,
  }) {
    final answerChars = <String>{};
    void addChars(String s) => answerChars.addAll(s.split('').where((c) => c.trim().isNotEmpty));
    if (koreanCharacters) {
      addChars(target.korean1);
      addChars(target.korean2);
    } else {
      addChars(shownEnglish(target));
    }
    if (optionCount == -1) {
      optionCount = max(3, correctAnswer.replaceAll(' ', '').length);
    }
    final wrong = <String>[];
    // Same Word Pack first (look-alike letters), then everything else.
    final ordered = [
      ..._shuffled(list.where((x) => target.packId.isNotEmpty && target.packIds.any(x.inPack))),
      ..._shuffled(list.where((x) => target.packId.isEmpty || !target.packIds.any(x.inPack))),
    ];
    for (final tryEntry in ordered) {
      final tryOption = koreanCharacters ? tryEntry.korean1 : shownEnglish(tryEntry);
      for (final c in tryOption.split('')) {
        if (c.trim().isEmpty || answerChars.contains(c) || wrong.contains(c)) continue;
        wrong.add(c);
        if (wrong.length == optionCount) return wrong;
      }
    }
    return wrong;
  }

  /// CreateTextBoxGame (entry overload), with the Answer swap bug fixed.
  TypingRound createTextBoxGame(
    VocabEntry target, {
    bool showHintAtStart = true,
    bool helperButtons = false,
    bool includeWrongOptions = false,
    List<String>? wrongOptions,
    bool targetIsEnglish = true,
    int gameRepetitionCount = 1,
  }) {
    String prompt;
    String a1;
    String a2 = '';
    if (targetIsEnglish) {
      a1 = target.korean1.replaceAll(' ', '');
      a2 = target.korean2.isNotEmpty ? target.korean2.replaceAll(' ', '') : '';
      prompt = _englishSide(target);
      if (a2.length >= minimumCharacterScrambleLength && rand.nextInt(2) == 0) {
        final tmp = a1;
        a1 = a2;
        a2 = tmp;
      }
    } else {
      a1 = shownEnglish(target).replaceAll(' ', '');
      prompt = _pickKorean(target);
      if (useEmoji && target.emoji.isNotEmpty) a2 = target.emoji.replaceAll(' ', '');
    }

    final answerChars = a1.split('').where((c) => c.trim().isNotEmpty).toList();
    if (includeWrongOptions && wrongOptions == null) {
      wrongOptions = getWrongCharacters(a1, target, _wordsOnly, koreanCharacters: targetIsEnglish);
    }
    var charList = <String>[];
    if (helperButtons) {
      charList = _shuffled([...answerChars, ...?wrongOptions]);
    }
    final alsoAccepted = <String>[
      // Not for generated number-game entries (no section): 7️⃣/8️⃣ must stay exact.
      // A sentence: its units in any other order.
      ...?_sentenceOf[target]?.allOrders,
      if (targetIsEnglish && target.sectionName.isNotEmpty && _sentenceOf[target] == null)
        for (final o in _wordsOnly)
          // Another card showing the same prompt, or with the same English
          // word when the prompt is English (부모 / 부모님 for "Parents"; with
          // bracket notes off, 밥 / 쌀 for "Rice").
          if (o.sectionName != target.sectionName &&
              {
                stripSpaces(_englishSide(o)).toLowerCase(),
                stripSpaces(shownEnglish(o)).toLowerCase(),
              }.contains(stripSpaces(prompt).toLowerCase()))
            ...[o.korean1, o.korean2].where((k) => k.isNotEmpty),
    ];
    return TypingRound(
      word: _wordOf(target),
      alsoAccepted: alsoAccepted,
      promptEnglish: targetIsEnglish && useEmoji
          ? peekEnglish(target, showBracketNotes: showBracketNotes)
          : '',
      prompt: prompt,
      promptIsKorean: !targetIsEnglish,
      answer1: a1,
      answer2: a2,
      answerIsKorean: targetIsEnglish,
      showHintAtStart: showHintAtStart,
      repetitions: gameRepetitionCount,
      charButtons: charList,
    );
  }

  /// [e] when it is a real word (generated number entries have no section).
  static VocabEntry? _wordOf(VocabEntry e) => e.sectionName.isEmpty ? null : e;

  /// NumberGame (games 7 & 8).
  Object numberGame({bool useNativeKorean = false}) {
    const numberOfOptions = 3;
    final maxDigits = useNativeKorean
        ? game8MaxDigits
        : game7MaxDigits.clamp(minGame7MaxDigits, maxGame7MaxDigits);
    final numberOfDigits = 1 + rand.nextInt(maxDigits); // 1..maxDigits, uniform
    var minValue = pow(10, numberOfDigits - 1).toInt();
    var maxValue = pow(10, numberOfDigits).toInt();
    if (useNativeKorean) {
      // 8️⃣: 1..nativeMax, so the answer and both decoys stay in range.
      minValue = 1;
      maxValue = nativeMax.clamp(numberOfOptions, 99) + 1;
    }

    final history = gameHistory[currentGame]!;
    var nums = <int>[];
    var failSafe = 0;
    do {
      final n = minValue + rand.nextInt(maxValue - minValue);
      if (!nums.contains(n) && !history.contains(n.toString())) nums.add(n);
      failSafe++;
    } while (!(nums.length == numberOfOptions || failSafe == 200));
    if (nums.length < numberOfOptions) nums = [1, 2, 3];

    logGameTarget(nums[0].toString());

    final answers = [
      for (final n in nums)
        VocabEntry(
          english1: n.toString(),
          korean1: numberTranslation(n, useNativeKorean: useNativeKorean, random: rand),
        ),
    ];

    final format = 1 + rand.nextInt(4); // Random.Shared.Next(1, 5)
    switch (format) {
      case 1:
        return matchingGame(answers[0], answers.sublist(1), false);
      case 2:
        return matchingGame(answers[0], answers.sublist(1), true);
      case 3:
        return createTextBoxGame(answers[0], showHintAtStart: false);
      default:
        return TypingRound(
          prompt: answers[0].korean1,
          promptIsKorean: true,
          answer1: answers[0].english1,
          answer2: '',
          answerIsKorean: false,
          showHintAtStart: false,
          repetitions: 1,
          charButtons: const ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
        );
    }
  }
}

/// [english] without its notes in brackets: "Car (vehicle)" → "Car",
/// "Seat (spot)" → "Seat". Every (...) group is removed and spaces tidied; if
/// nothing would be left, the English is returned unchanged.
String stripBracketNotes(String english) {
  if (!english.contains('(')) return english;
  final s = english
      .replaceAll(RegExp(r'\s*\([^()]*\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,.!?;:])'), r'$1')
      .trim();
  return s.isEmpty ? english : s;
}

/// Removes all whitespace (the original removed spaces; phone keyboards may
/// also add other whitespace).
String stripSpaces(String s) => s.replaceAll(RegExp(r'\s+'), '');

/// Enter/✔ check for typing rounds: accepts Item1 or Item2, spaces ignored.
bool isTypedAnswerCorrect(String input, TypingRound round) {
  final user = stripSpaces(input);
  if (user.isEmpty) return false;
  return user == stripSpaces(round.answer1) ||
      (round.answer2.isNotEmpty && user == stripSpaces(round.answer2)) ||
      round.alsoAccepted.any((a) => user == stripSpaces(a));
}

/// Helper-button check: the built text must equal Item1 (spaces ignored).
bool isHelperAnswerComplete(String input, TypingRound round) =>
    stripSpaces(input) == stripSpaces(round.answer1);
