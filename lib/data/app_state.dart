import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/game_engine.dart';
import '../logic/ini_parser.dart';
import '../models/vocab_entry.dart';
import 'bundles.dart';
import 'packs.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Everything the app keeps: vocab, packs, custom words, wins & stats.
class AppState extends ChangeNotifier {
  static const _kEnabled = 'enabled_bundles';
  static const kAllPacks = 'opt_all_packs';
  static const _kCustom = 'custom_words';
  static const _kWins = 'wins_by_day';
  static const _kKnown = 'known_bundles';
  static const kUserPacks = 'user_packs';
  static const kOverrides = 'builtin_overrides';
  static const kSeededMyWords = 'seeded_my_words';
  static const kVibration = 'opt_vibration';
  static const kShowWins = 'opt_show_wins';
  static const kShowStreak = 'opt_show_streak';
  static const kSpokenAnswer = 'opt_spoken_answer';
  static const kUseEmoji = 'opt_use_emoji';
  static const kShowBracketNotes = 'opt_show_bracket_notes';

  /// 📦 Word Pack Stats: day -> pack id -> wins, and every word (section
  /// name) that has been the word of a won round.
  static const kPackWins = 'pack_wins_by_day';
  static const kWonWords = 'won_words';

  /// 📊 Highest Streak: game number -> best streak ever (0 = 🔀 Shuffle).
  static const kBestStreaks = 'best_streaks';

  /// Old single 3️⃣-in-Shuffle toggle; read once to migrate into [kShuffleOff].
  static const kLegacyShuffleGame3 = 'opt_shuffle_game3';

  /// 🔀 Shuffle games that are switched OFF (game numbers as strings).
  static const kShuffleOff = 'opt_shuffle_off';
  static const kGame7MaxDigits = 'opt_game7_max_digits';

  /// 8️⃣ top number (10/30/50/99), and whether it was ever set to 99.
  static const kNativeMax = 'opt_native_max';
  static const kNative99Reached = 'native_99_reached';

  /// 🏗️ Sentence difficulty (0 Easy .. 3 Master), and whether it was ever
  /// set to Master (that stops the 5-in-a-row pop-up for good).
  static const kSentenceLevel = 'opt_sentence_level';
  static const kSentenceMasterReached = 'sentence_master_reached';

  /// 🔠 Button Font Size: 0 Small, 1 Medium, 2 Large (default), 3 Huge.
  static const kButtonFont = 'opt_button_font';

  /// Font size of game answer buttons, by [buttonFont] step.
  static const buttonFontSizes = [22.0, 26.0, 30.0, 36.0];
  static const buttonFontLabels = ['Small', 'Medium', 'Large', 'Huge'];
  static const kGame3Repetitions = 'opt_game3_repetitions';

  /// ⌚ Digital time in 🕒 What Time Is It? (default on).
  static const kShowDigitalTime = 'opt_show_digital_time';

  /// The one-time 🕒 5x-streak "turn off ⌚ Digital time?" pop-up was shown.
  static const kDigitalPromptShown = 'digital_prompt_shown';
  bool digitalPromptShown = false;

  /// Set once 🎯 Pick the Korean (old game 2) has been folded into 🔍 Pick
  /// the meaning (wins and 🔀 Shuffle switch); number 2 is now 🕒.
  static const kMergedGame2 = 'merged_game2_v16';

  late SharedPreferences _prefs;

  /// Built-in words exactly as shipped in the vocab file.
  List<VocabEntry> builtIn = [];
  final Map<String, VocabEntry> _originalBySection = {};

  /// Player edits of built-in words, keyed by section name. Stored apart from
  /// the vocab file so they survive app updates; one whose section is no
  /// longer in the file is ignored.
  Map<String, VocabEntry> overrides = {};

  /// Words the player added. `packId` is My Words ([customBundleId]), a
  /// built-in pack id (shows only when My Words AND that pack are on) or a
  /// user pack id (shows when that pack is on).
  List<VocabEntry> customWords = [];

  /// Packs the player created, in creation order.
  List<UserPack> userPacks = [];
  Set<String> enabledBundles = {};

  /// Per-session wins (reset when the app restarts), like the original W:n.
  final Map<int, int> sessionWins = {for (var i = 1; i <= GameEngine.gameCount; i++) i: 0};

  /// Persistent analytics: day -> game -> wins.
  Map<String, Map<int, int>> winsByDay = {};

  /// 📦 Word Pack wins this session (pack id -> wins; reset on restart).
  final Map<String, int> packSessionWins = {};

  /// 📦 Word Pack wins kept forever: day -> pack id -> wins.
  Map<String, Map<String, int>> packWinsByDay = {};

  /// Section names of every word that has been the word of a won round.
  Set<String> wonWords = {};

  /// 📊 Highest Streak: best 🔥 streak per game, kept forever. Key 0 is
  /// 🔀 Shuffle (streaks made in Shuffle only count there).
  Map<int, int> bestStreaks = {};

  late GameEngine engine;

  // ⚙️ Options (all default on).
  bool vibration = true;
  bool showWins = true;
  bool showStreak = true;
  bool spokenAnswer = true;

  /// 😀 Emoji: words show their emoji in the games (off: their English).
  bool useEmoji = true;

  /// ⚙️ Options 📑 Bracket notes: show "Car (vehicle)" (true) or just "Car".
  bool showBracketNotes = false;

  /// ⌚ Digital time: show '5:05' under the 🕒 clock.
  bool showDigitalTime = true;

  /// [english] as the player sees it: without bracket notes when they're off.
  String displayEnglish(String english) => showBracketNotes ? english : stripBracketNotes(english);

  /// Games left out of 🔀 Shuffle (all games are in by default).
  Set<int> _shuffleOff = {};

  /// 7️⃣ 🔢 most digits per number (1-8, default 6).
  int game7MaxDigits = GameEngine.defaultGame7MaxDigits;
  int nativeMax = GameEngine.defaultNativeMax;
  bool native99Reached = false;
  int sentenceLevel = sentenceEasy;
  bool sentenceMasterReached = false;

  /// The 🏗️ 5-in-a-row pop-up was shown since the app started.
  bool sentencePromptShownThisSession = false;

  /// 🏗️ sentence data (nouns, verbs), linked to the built-in words.
  SentenceBank? sentenceBank;

  /// Stored index: 0 Small, 1 Medium, 2 Large (default), 3 Huge.
  static const defaultButtonFont = 2;
  int buttonFont = defaultButtonFont;
  double get buttonFontSize => buttonFontSizes[buttonFont];

  /// 3️⃣ ✍️ repetitions per word (1-5, default 3).
  int game3Repetitions = GameEngine.defaultGame3Repetitions;

  /// 🔀 Shuffle wins this session (each also counts for the game played).
  int shuffleSessionWins = 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    // Anything saved at all means this is an update, not a fresh install.
    final existingInstall = _prefs.getKeys().isNotEmpty;
    vibration = _prefs.getBool(kVibration) ?? true;
    showWins = _prefs.getBool(kShowWins) ?? true;
    showStreak = _prefs.getBool(kShowStreak) ?? true;
    spokenAnswer = _prefs.getBool(kSpokenAnswer) ?? true;
    useEmoji = _prefs.getBool(kUseEmoji) ?? true;
    showBracketNotes = _prefs.getBool(kShowBracketNotes) ?? false;
    showDigitalTime = _prefs.getBool(kShowDigitalTime) ?? true;
    digitalPromptShown = _prefs.getBool(kDigitalPromptShown) ?? false;
    buttonFont = (_prefs.getInt(kButtonFont) ?? defaultButtonFont).clamp(0, 3);
    final mergeGame2 = !(_prefs.getBool(kMergedGame2) ?? false);
    _shuffleOff = await _loadShuffleOff();
    if (mergeGame2 && existingInstall) {
      // Old 🎯 on and 🔍 off: 🔍 now holds 🎯's rounds, so it comes on.
      if (_shuffleOff.contains(1) && !_shuffleOff.contains(2)) _shuffleOff.remove(1);
      _shuffleOff.remove(2); // 🕒 starts on
      if (_shuffleOff.length >= GameEngine.gameCount) _shuffleOff = {};
      await _saveShuffleOff();
    }
    game7MaxDigits = _clampDigits(
      _prefs.getInt(kGame7MaxDigits) ?? GameEngine.defaultGame7MaxDigits,
    );
    nativeMax = _snapNative(_prefs.getInt(kNativeMax) ?? GameEngine.defaultNativeMax);
    native99Reached = (_prefs.getBool(kNative99Reached) ?? false) || nativeMax == 99;
    sentenceLevel = (_prefs.getInt(kSentenceLevel) ?? sentenceEasy).clamp(
      sentenceEasy,
      sentenceMaster,
    );
    sentenceMasterReached =
        (_prefs.getBool(kSentenceMasterReached) ?? false) || sentenceLevel == sentenceMaster;
    sentencePromptShownThisSession = false;
    game3Repetitions = _clampReps(
      _prefs.getInt(kGame3Repetitions) ?? GameEngine.defaultGame3Repetitions,
    );
    final index = await rootBundle.loadString(vocabIndexAsset);
    final packTexts = {
      for (final id in parsePackIndex(index)) id: await rootBundle.loadString(packAsset(id)),
    };
    builtIn = loadBuiltInVocab(index, (id) => packTexts[id]!);
    _originalBySection
      ..clear()
      ..addEntries(builtIn.map((e) => MapEntry(e.sectionName, e)));
    final verbIds = packTexts.keys.where(isVerbPackId).toSet();
    sentenceBank = SentenceBank.parse(
      await rootBundle.loadString(sentenceNounsAsset),
      await rootBundle.loadString(sentenceVerbsAsset),
      polite: {for (final id in verbIds) ...parsePoliteForms(packTexts[id]!)},
    );
    final problems = sentenceBank!.link(builtIn, verbIds);
    if (problems.isNotEmpty) debugPrint('🏗️ sentence data: ${problems.join('; ')}');

    final packsJson = _prefs.getString(kUserPacks);
    userPacks = packsJson == null
        ? []
        : (jsonDecode(packsJson) as List)
              .map((j) => UserPack.fromJson(j as Map<String, dynamic>))
              .where((p) => p.id.isNotEmpty)
              .toList();
    final userIds = userPacks.map((p) => p.id).toSet();
    String validPack(String id, String fallback) =>
        builtInBundleById(id) != null || id == customBundleId || userIds.contains(id)
        ? id
        : fallback;

    // Custom words (My Words and the player's own packs).
    var migrated = false;
    final customJson = _prefs.getString(_kCustom);
    customWords = [];
    if (customJson != null) {
      for (final raw in jsonDecode(customJson) as List) {
        final e = VocabEntry.fromJson(raw as Map<String, dynamic>);
        customWords.add(e.copyWith(packId: validPack(e.packId, customBundleId)));
      }
    }

    // The player's edits of built-in words; the shipped originals stay in
    // [_originalBySection] for the reset button.
    final overridesJson = _prefs.getString(kOverrides);
    overrides = {};
    if (overridesJson != null) {
      (jsonDecode(overridesJson) as Map<String, dynamic>).forEach((section, j) {
        final e = VocabEntry.fromJson(j as Map<String, dynamic>);
        final original = _originalBySection[section];
        // Edits of words no longer shipped (e.g. the removed 🏃 Action
        // Heroes pack) are dropped.
        if (original == null) return;
        overrides[section] = e.copyWith(
          sectionName: section,
          // Extra packs come from the bundled list, never from the save.
          alsoPacks: original.alsoPacks,
          packId: validPack(e.packId, original.packId),
        );
      });
    }

    final enabled = _prefs.getStringList(_kEnabled);
    final builtInIds = {...builtInBundles.map((b) => b.id), customBundleId};
    final allIds = {...builtInIds, ...userIds};
    // Fresh install: everything on except the packs that start off.
    enabledBundles = enabled?.toSet() ?? allIds.difference(defaultOffBundles);
    if (enabled != null) {
      // Packs added in an app update start switched on, without re-enabling
      // packs the player turned off.
      final known = _prefs.getStringList(_kKnown)?.toSet() ?? builtInIds;
      final added = builtInIds.difference(known);
      for (final id in added) {
        if (!defaultOffBundles.contains(id)) enabledBundles.add(id);
      }
      enabledBundles.removeWhere((id) => !allIds.contains(id));
      if (added.isNotEmpty ||
          !enabledBundles.containsAll(enabled) ||
          !enabled.toSet().containsAll(enabledBundles)) {
        await _prefs.setStringList(_kEnabled, enabledBundles.toList());
      }
    }
    await _prefs.setStringList(_kKnown, builtInIds.toList());
    // v13: every install gets the family names in My Words, once. A deleted
    // one never comes back, and a player who already has a custom word with
    // the same Korean doesn't get a second copy.
    final seedNow = !(_prefs.getBool(kSeededMyWords) ?? false);
    if (seedNow) {
      final have = <String>{
        for (final c in customWords)
          for (final k in [c.korean1, c.korean2])
            if (k.trim().isNotEmpty) stripSpaces(k),
      };
      for (final seed in seededMyWords) {
        if (seed.korean1.trim().isNotEmpty && have.contains(stripSpaces(seed.korean1))) continue;
        customWords.add(seed);
        have.add(stripSpaces(seed.korean1));
        migrated = true;
      }
    }
    if (migrated) await _prefs.setString(_kCustom, _encodeCustom());
    if (seedNow) await _prefs.setBool(kSeededMyWords, true);

    final winsJson = _prefs.getString(_kWins);
    if (winsJson != null) {
      final raw = jsonDecode(winsJson) as Map<String, dynamic>;
      winsByDay = raw.map(
        (day, games) => MapEntry(
          day,
          (games as Map<String, dynamic>).map((g, n) => MapEntry(int.parse(g), n as int)),
        ),
      );
    }
    if (mergeGame2) {
      // 🎯's wins join 🔍's, day by day (so all-time totals add up too).
      if (winsByDay.values.any((m) => m.containsKey(2))) {
        for (final m in winsByDay.values) {
          final old = m.remove(2);
          if (old != null && old > 0) m[1] = (m[1] ?? 0) + old;
        }
        await _saveWins();
      }
      await _prefs.setBool(kMergedGame2, true);
    }
    // 📦 Word Pack Stats (installs from before them start at zero).
    packWinsByDay = {};
    try {
      final raw = _prefs.getString(kPackWins);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((day, packs) {
          packWinsByDay[day] = (packs as Map<String, dynamic>).map(
            (p, n) => MapEntry(p, (n as num).toInt()),
          );
        });
      }
    } catch (_) {
      packWinsByDay = {};
    }
    wonWords = (_prefs.getStringList(kWonWords) ?? const []).toSet();
    bestStreaks = {};
    try {
      final raw = _prefs.getString(kBestStreaks);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach(
          (g, n) => bestStreaks[int.parse(g)] = (n as num).toInt(),
        );
      }
    } catch (_) {
      bestStreaks = {};
    }
    engine = GameEngine(activeVocab())
      ..useEmoji = useEmoji
      ..showBracketNotes = showBracketNotes
      ..game3Repetitions = game3Repetitions
      ..game7MaxDigits = game7MaxDigits
      ..nativeMax = nativeMax
      ..sentenceBank = sentenceBank
      ..sentenceLevel = sentenceLevel
      ..verbWords = _verbWords()
      ..linkPacksOf = ((w) => packsOfWord(w).where(enabledBundles.contains));
  }

  Future<void> setVibration(bool v) => _setOption(kVibration, v, () => vibration = v);
  Future<void> setShowWins(bool v) => _setOption(kShowWins, v, () => showWins = v);
  Future<void> setShowStreak(bool v) => _setOption(kShowStreak, v, () => showStreak = v);
  Future<void> setSpokenAnswer(bool v) => _setOption(kSpokenAnswer, v, () => spokenAnswer = v);
  Future<void> setUseEmoji(bool v) => _setOption(kUseEmoji, v, () {
    useEmoji = v;
    engine.useEmoji = v;
  });
  Future<void> setShowBracketNotes(bool v) => _setOption(kShowBracketNotes, v, () {
    showBracketNotes = v;
    engine.showBracketNotes = v;
  });

  Future<void> markDigitalPromptShown() async {
    digitalPromptShown = true;
    await _prefs.setBool(kDigitalPromptShown, true);
  }

  Future<void> setShowDigitalTime(bool v) =>
      _setOption(kShowDigitalTime, v, () => showDigitalTime = v);

  /// Whether [game] can come up in 🔀 Shuffle.
  bool shuffleIncludes(int game) => !_shuffleOff.contains(game);

  /// How many games are switched on for 🔀 Shuffle.
  int get shuffleGameCount =>
      [for (var g = 1; g <= GameEngine.gameCount; g++) g].where(shuffleIncludes).length;

  /// Switches [game] in or out of 🔀 Shuffle. Refuses (returns false) to switch
  /// off the last game that is still on.
  Future<bool> setShuffleGame(int game, bool on) async {
    if (shuffleIncludes(game) == on) return true;
    if (!on && shuffleGameCount <= 1) return false;
    on ? _shuffleOff.remove(game) : _shuffleOff.add(game);
    notifyListeners();
    await _saveShuffleOff();
    return true;
  }

  Future<void> _saveShuffleOff() =>
      _prefs.setStringList(kShuffleOff, [for (final g in _shuffleOff.toList()..sort()) '$g']);

  /// Reads the off-list, migrating the old 3️⃣-only toggle the first time.
  Future<Set<int>> _loadShuffleOff() async {
    final saved = _prefs.getStringList(kShuffleOff);
    Set<int> off;
    if (saved == null) {
      off = {if (_prefs.getBool(kLegacyShuffleGame3) == false) 3};
      _shuffleOff = off;
      await _saveShuffleOff();
    } else {
      off = {
        for (final s in saved)
          if (int.tryParse(s) case final g? when g >= 1 && g <= GameEngine.gameCount) g,
      };
    }
    if (_prefs.containsKey(kLegacyShuffleGame3)) await _prefs.remove(kLegacyShuffleGame3);
    // At least one game always stays on.
    if (off.length >= GameEngine.gameCount) off = {};
    return off;
  }

  Future<void> setButtonFont(int v) async {
    v = v.clamp(0, 3);
    if (v == buttonFont) return;
    buttonFont = v;
    notifyListeners();
    await _prefs.setInt(kButtonFont, v);
  }

  /// Every Verb Pack word (with the player's edits), by section.
  Map<String, VocabEntry> _verbWords() => {
    for (final e in effectiveBuiltIn)
      if (isVerbPackId(e.packId)) e.sectionName: e,
  };

  /// 🏗️ difficulty; applies from the next round (verbs in the other games
  /// too). Choosing Master (anywhere) stops the 5-in-a-row pop-up for good.
  Future<void> setSentenceLevel(int v) async {
    v = v.clamp(sentenceEasy, sentenceMaster);
    if (v == sentenceMaster) sentenceMasterReached = true;
    sentenceLevel = v;
    engine.sentenceLevel = v;
    notifyListeners();
    await _prefs.setInt(kSentenceLevel, v);
    if (sentenceMasterReached) await _prefs.setBool(kSentenceMasterReached, true);
  }

  /// Applies from the next 7️⃣ number.
  Future<void> setGame7MaxDigits(int v) async {
    v = _clampDigits(v);
    if (v == game7MaxDigits) return;
    game7MaxDigits = v;
    engine.game7MaxDigits = v;
    notifyListeners();
    await _prefs.setInt(kGame7MaxDigits, v);
  }

  /// 8️⃣ top number; applies from the next round. Setting 99 (anywhere)
  /// remembers it for good, which stops the 5-in-a-row pop-up.
  Future<void> setNativeMax(int v) async {
    v = _snapNative(v);
    if (v == 99) native99Reached = true;
    if (v != nativeMax) {
      nativeMax = v;
      engine.nativeMax = v;
    }
    notifyListeners();
    await _prefs.setInt(kNativeMax, v);
    if (native99Reached) await _prefs.setBool(kNative99Reached, true);
  }

  /// The nearest allowed stop (10/30/50/99).
  static int _snapNative(int v) =>
      GameEngine.nativeMaxStops.reduce((a, b) => (v - a).abs() <= (v - b).abs() ? a : b);

  static int _clampDigits(int v) =>
      v.clamp(GameEngine.minGame7MaxDigits, GameEngine.maxGame7MaxDigits);

  /// Applies from the next 3️⃣ word (the current word keeps its count).
  Future<void> setGame3Repetitions(int v) async {
    v = _clampReps(v);
    if (v == game3Repetitions) return;
    game3Repetitions = v;
    engine.game3Repetitions = v;
    notifyListeners();
    await _prefs.setInt(kGame3Repetitions, v);
  }

  static int _clampReps(int v) =>
      v.clamp(GameEngine.minGame3Repetitions, GameEngine.maxGame3Repetitions);

  Future<void> _setOption(String key, bool v, void Function() apply) async {
    apply();
    notifyListeners();
    await _prefs.setBool(key, v);
  }

  /// Built-in words with the player's edits applied.
  Iterable<VocabEntry> get effectiveBuiltIn => builtIn.map((e) => overrides[e.sectionName] ?? e);

  bool isBuiltInWord(VocabEntry e) => _originalBySection.containsKey(e.sectionName);

  VocabEntry? originalOf(VocabEntry e) => _originalBySection[e.sectionName];

  bool isOverridden(VocabEntry e) => overrides.containsKey(e.sectionName);

  /// Whether a word is in play with the current switches.
  bool isWordVisible(VocabEntry e) {
    final pack = e.packId.isEmpty ? customBundleId : e.packId;
    // Verb Pack words are in play as sentences (the games turn each verb
    // into a sentence); a player's own word in a Verb Pack never is.
    if (isVerbPackId(pack) && !isBuiltInWord(e)) return false;
    // A built-in word in several packs is in play when any of them is on.
    if (isBuiltInWord(e)) {
      return enabledBundles.contains(pack) || e.alsoPacks.any(enabledBundles.contains);
    }
    if (builtInBundleById(pack) != null) {
      // A custom word in a built-in pack needs My Words AND that pack.
      return enabledBundles.contains(customBundleId) && enabledBundles.contains(pack);
    }
    return enabledBundles.contains(pack);
  }

  List<VocabEntry> activeVocab() => [
    ...effectiveBuiltIn.where(isWordVisible),
    ...customWords.where(isWordVisible),
  ];

  /// Words listed under a pack on the Word Packs screen. My Words also lists
  /// the custom words living in built-in packs, since its switch gates them.
  List<VocabEntry> wordsInPack(String id) => [
    ...effectiveBuiltIn.where((e) => e.inPack(id)),
    ...customWords.where(
      (e) => e.packId == id || (id == customBundleId && builtInBundleById(e.packId) != null),
    ),
  ];

  void _refreshEngine() {
    engine
      ..vocabList = activeVocab()
      ..verbWords = _verbWords();
    notifyListeners();
  }

  Future<void> setBundleEnabled(String id, bool on) async {
    on ? enabledBundles.add(id) : enabledBundles.remove(id);
    await _savePacks();
  }

  /// Built-in packs shown on the Word Packs screen (My Words and the
  /// Verb Packs excluded).
  Iterable<String> get builtInPackIds => builtInBundles
      .where((b) => !b.isVerbPack)
      .map((b) => b.id)
      .where((id) => wordsInPack(id).isNotEmpty);

  /// Verb Packs, listed on the Verb Packs screen.
  Iterable<String> get verbPackIds => builtInBundles
      .where((b) => b.isVerbPack)
      .map((b) => b.id)
      .where((id) => wordsInPack(id).isNotEmpty);

  /// Every pack the "All packs" switch controls: built-in and user packs,
  /// never My Words.
  Iterable<String> get allPackIds => [...builtInPackIds, ...userPacks.map((p) => p.id)];

  /// The "All packs" master switch: on whenever any pack is on, off only
  /// when they are all off. Derived from the saved pack states, so it is
  /// always consistent and restored on restart. My Words is never involved.
  bool get allPacksOn => allPackIds.any(enabledBundles.contains);

  /// Master switch: every built-in and user pack on / off. My Words untouched.
  Future<void> setAllPacks(bool on) async {
    for (final id in allPackIds) {
      on ? enabledBundles.add(id) : enabledBundles.remove(id);
    }
    await _savePacks();
  }

  Future<void> _savePacks() async {
    _refreshEngine();
    await _prefs.setStringList(_kEnabled, enabledBundles.toList());
    await _prefs.setBool(kAllPacks, allPacksOn); // mirror, for the record
  }

  String _encodeCustom() => jsonEncode(customWords.map((e) => e.toJson()).toList());

  /// Saves words, edits, user packs and switches after any word change,
  /// dropping user packs that ran out of words first.
  Future<void> _saveWords() async {
    final used = {...customWords.map((e) => e.packId), ...overrides.values.map((e) => e.packId)};
    final empty = userPacks.where((p) => !used.contains(p.id)).map((p) => p.id).toSet();
    userPacks.removeWhere((p) => empty.contains(p.id));
    enabledBundles.removeAll(empty);
    await _prefs.setString(_kCustom, _encodeCustom());
    await _prefs.setString(
      kOverrides,
      jsonEncode(overrides.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.setString(kUserPacks, jsonEncode(userPacks.map((p) => p.toJson()).toList()));
    await _savePacks();
  }

  /// Name and emoji for any pack id.
  ({String emoji, String name}) packLabel(String id) {
    if (id.isEmpty || id == customBundleId) return (emoji: myWordsEmoji, name: myWordsName);
    final b = builtInBundleById(id);
    if (b != null) return (emoji: b.emoji, name: b.name);
    for (final p in userPacks) {
      if (p.id == id) return (emoji: p.emoji, name: p.name);
    }
    return (emoji: myWordsEmoji, name: myWordsName);
  }

  PackChoice resolvePack(String input) => resolvePackInput(input, userPacks: userPacks);

  /// Creates a new user pack (switched on) and returns its id. Not saved
  /// until a word is put in it.
  String createUserPack(String name, String emoji) {
    var n = DateTime.now().microsecondsSinceEpoch;
    while (userPacks.any((p) => p.id == '$userPackPrefix$n')) {
      n++;
    }
    final id = '$userPackPrefix$n';
    userPacks.add(UserPack(id: id, name: name, emoji: emoji.isEmpty ? '📦' : emoji));
    enabledBundles.add(id);
    return id;
  }

  /// Saves a word from the New / Edit Word screen into [packChoice] (creating
  /// the pack when it is new, with [newPackEmoji]). Built-in words become a
  /// local edit; everything else is a custom word.
  Future<VocabEntry> saveWord(
    VocabEntry e, {
    required PackChoice packChoice,
    String newPackEmoji = '',
  }) async {
    final packId = packChoice.kind == PackKind.newPack
        ? createUserPack(packChoice.name, newPackEmoji)
        : packChoice.id;
    var word = e.copyWith(packId: packId);
    final original = originalOf(word);
    // A built-in word keeps the extra packs it shares (not editable).
    if (original != null) word = word.copyWith(alsoPacks: original.alsoPacks);
    if (original != null) {
      word == original ? overrides.remove(word.sectionName) : overrides[word.sectionName] = word;
    } else {
      final i = customWords.indexWhere((x) => x.sectionName == word.sectionName);
      if (word.sectionName.isEmpty || i < 0) {
        word = word.copyWith(
          sectionName: word.sectionName.isEmpty
              ? 'Custom_${DateTime.now().microsecondsSinceEpoch}'
              : word.sectionName,
        );
        customWords.add(word);
      } else {
        customWords[i] = word;
      }
    }
    await _saveWords();
    return word;
  }

  /// Puts a built-in word back exactly as shipped (pack included).
  Future<void> resetBuiltInWord(VocabEntry e) async {
    overrides.remove(e.sectionName);
    await _saveWords();
  }

  Future<void> deleteCustomWord(VocabEntry e) async {
    customWords.removeWhere((x) => x.sectionName == e.sectionName);
    await _saveWords();
  }

  /// A win in [game]; Stats always file it under the game actually played,
  /// [inShuffle] also counts it for 🔀 Shuffle's session total.
  ///
  /// [word] is the word the round was about (null for 7️⃣ 8️⃣ 9️⃣, which
  /// don't use the Word Packs): the win also counts once for every pack the
  /// word is listed under (see [packsOfWord]) and marks the word as won.
  ///
  /// [words] is for a round about several words at once (a cleared Link Up
  /// board): it is still one win, every one of its words is marked as won,
  /// and each pack that has any of them gets one win.
  Future<void> recordWin(
    int game, {
    DateTime? now,
    bool inShuffle = false,
    VocabEntry? word,
    Iterable<VocabEntry> words = const [],
  }) async {
    sessionWins[game] = (sessionWins[game] ?? 0) + 1;
    if (inShuffle) shuffleSessionWins++;
    final day = dayKey(now ?? DateTime.now());
    final m = winsByDay.putIfAbsent(day, () => {});
    m[game] = (m[game] ?? 0) + 1;
    final credited = [?word, ...words].where((w) => w.sectionName.isNotEmpty).toList();
    final packs = {for (final w in credited) ...packsOfWord(w)};
    if (packs.isNotEmpty) {
      final pm = packWinsByDay.putIfAbsent(day, () => {});
      for (final p in packs) {
        packSessionWins[p] = (packSessionWins[p] ?? 0) + 1;
        pm[p] = (pm[p] ?? 0) + 1;
      }
      wonWords.addAll(credited.map((w) => w.sectionName));
    }
    notifyListeners();
    await _saveWins();
    if (packs.isNotEmpty) {
      await _prefs.setString(kPackWins, jsonEncode(packWinsByDay));
      await _prefs.setStringList(kWonWords, wonWords.toList()..sort());
    }
  }

  /// A streak of [count] in [game] (0 = 🔀 Shuffle): saved if it's a new best.
  Future<void> recordStreak(int game, int count) async {
    if (count <= (bestStreaks[game] ?? 0)) return;
    bestStreaks[game] = count;
    notifyListeners();
    await _prefs.setString(
      kBestStreaks,
      jsonEncode(bestStreaks.map((g, n) => MapEntry(g.toString(), n))),
    );
  }

  Future<void> _saveWins() => _prefs.setString(
    _kWins,
    jsonEncode(winsByDay.map((d, g) => MapEntry(d, g.map((k, v) => MapEntry(k.toString(), v))))),
  );

  /// Every pack [word] is listed under on the Word Packs screen (same rule
  /// as [wordsInPack]): its home pack, its extra packs, and ✏️ My Words too
  /// for a word the player added to a built-in pack.
  Set<String> packsOfWord(VocabEntry word) {
    final home = word.packId.isEmpty ? customBundleId : word.packId;
    final custom = customWords.any((c) => c.sectionName == word.sectionName);
    return {
      home,
      ...word.alsoPacks.where((p) => p.isNotEmpty),
      if (custom && builtInBundleById(home) != null) customBundleId,
    };
  }

  /// 📦 Every pack in Word Packs order (built-in, the player's, My Words),
  /// on or off.
  List<String> get statsPackIds => [
    ...builtInPackIds,
    ...userPacks.map((p) => p.id),
    customBundleId,
  ];

  int packWinsOnDay(String pack, String day) => packWinsByDay[day]?[pack] ?? 0;

  int packAllTime(String pack) => packWinsByDay.values.fold(0, (a, m) => a + (m[pack] ?? 0));

  /// ⭐: every word the pack has now has been the word of a won round.
  bool packStarred(String pack) {
    final words = wordsInPack(pack);
    return words.isNotEmpty && words.every((w) => wonWords.contains(w.sectionName));
  }

  /// (won, total) words in a pack, for the ⭐ progress.
  ({int won, int total}) packWordProgress(String pack) {
    final words = wordsInPack(pack);
    return (won: words.where((w) => wonWords.contains(w.sectionName)).length, total: words.length);
  }

  int get allTimeTotal => winsByDay.values.fold(0, (a, m) => a + m.values.fold(0, (x, y) => x + y));

  Map<int, int> get allTimeByGame {
    final r = {for (var i = 1; i <= GameEngine.gameCount; i++) i: 0};
    for (final m in winsByDay.values) {
      m.forEach((g, n) => r[g] = (r[g] ?? 0) + n);
    }
    return r;
  }

  int winsOnDay(String day) => (winsByDay[day]?.values ?? const <int>[]).fold(0, (a, b) => a + b);
}
