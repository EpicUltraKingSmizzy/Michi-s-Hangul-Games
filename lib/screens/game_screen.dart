import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../data/buzz.dart';
import '../data/speaker.dart';
import '../logic/game_engine.dart';
import '../logic/play_helpers.dart';
import '../main.dart';
import '../models/vocab_entry.dart';
import '../widgets/number_help.dart';
import '../widgets/common.dart';
import 'options_screen.dart';
import '../widgets/emoji_peek.dart';
import '../widgets/link_board.dart';
import '../widgets/number_keypad.dart';
import '../widgets/time_art.dart';
import 'bundles_screen.dart';
import 'shuffle_games_screen.dart';

part 'games/choice_game.dart';
part 'games/color_game.dart';
part 'games/link_up_game.dart';
part 'games/number_game.dart';
part 'games/syllable_game.dart';
part 'games/time_game.dart';
part 'games/typing_game.dart';

const _green = Color(0xFF3DDC84);
const _red = Color(0xFFFF4D4D);
const _ink = Color(0xFF3A1D5C);
const _textShadow = [Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 3)];

const _optionPalette = [Color(0xFF7B5CFF), Color(0xFF00B4FF), Color(0xFFFF9F1C)];

const _helperPalette = [
  Color(0xFFFF5C8A),
  Color(0xFF7B5CFF),
  Color(0xFF00B4FF),
  Color(0xFF2EC4B6),
  Color(0xFFFF9F1C),
  Color(0xFFE040FB),
];

class GameScreen extends StatefulWidget {
  /// The game (1-10); 0 for 🔀 Shuffle.
  final int game;

  /// 🔀 Shuffle: a random playable game, and another after every win. The
  /// 🔥 streak and 🏆 count carry across games.
  final bool shuffle;
  const GameScreen({super.key, required this.game}) : shuffle = false;
  const GameScreen.shuffle({super.key}) : game = 0, shuffle = true;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _rand = Random();
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 700));
  final _input = TextEditingController();
  final _focus = FocusNode();

  Object? _round;
  int _roundId = 0;
  bool _locked = false;

  /// The current round is already won and we're in the pause before the next.
  bool _won = false;

  /// The game being played (changes every win in 🔀 Shuffle).
  late int _game = widget.game;

  /// 🔥 combo for this visit to the game (leaving the game resets it).
  final Streak _streak = Streak();

  // Choice state
  final Map<int, Color> _optionColors = {};

  // Typing state
  bool _hintVisible = false;

  /// 🕒/🧩/🌀: ? was pressed this round, so the header shows 🔊.
  bool _hintUsed = false;
  int _reps = 0;
  Color? _fieldFlash;
  int _shake = 0;

  /// Emoji prompt flipped to its English word (a tap on the emoji). Every
  /// round starts on the emoji; peeking never affects wins or the streak.
  bool _peek = false;

  // 5️⃣/6️⃣ answer slots
  TileSlots? _slots;

  // 🕒: the 오전 / 오후 button picked (sky rounds only).
  String? _period;

  // Link Up board
  LinkBoard? _links;

  /// A card tapped first (tap-tap linking), waiting for its partner.
  LinkSpot? _linkPick;

  /// The card a line is being dragged from, and the finger.
  LinkSpot? _dragFrom;
  Offset? _dragTo;

  /// A wrong line (left row, right slot), red for [LinkRound.wrongFlash].
  (int, int)? _wrongLine;
  Timer? _wrongTimer;

  // Cheer bubble
  String? _cheer;
  int _cheerId = 0;

  /// 🔀 Shuffle with no game to play yet (none switched on is playable).
  GameInfo get _info => _game == 0 ? shuffleInfo : gameInfos[_game - 1];

  @visibleForTesting
  Object? get currentRound => _round;
  @visibleForTesting
  int get currentGame => _game;
  @visibleForTesting
  int get streakCount => _streak.count;
  @visibleForTesting
  bool get peeking => _peek;
  @visibleForTesting
  LinkBoard? get linkBoard => _links;
  @visibleForTesting
  TileSlots? get tileSlots => _slots;
  @visibleForTesting
  (int, int)? get wrongLine => _wrongLine;

  /// [setState] for the per-game parts (extensions can't call it directly).
  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  @override
  void dispose() {
    _wrongTimer?.cancel();
    _confetti.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A new round; in 🔀 Shuffle with [newGame] (and at the start) a new
  /// random game too.
  void _nextRound({bool newGame = false}) {
    final engine = appState.engine;
    setState(() {
      if (widget.shuffle && (newGame || _game == 0)) {
        _game =
            pickShuffleGame(
              _rand,
              previous: _game == 0 ? null : _game,
              enabled: appState.shuffleIncludes,
              canPlay: engine.canPlay,
            ) ??
            0;
      }
      _round = _game != 0 && engine.canPlay(_game) ? engine.newRound(_game) : null;
      _roundId++;
      _locked = false;
      _won = false;
      _optionColors.clear();
      _peek = false;
      _input.value = TextEditingValue.empty;
      _reps = 0;
      _fieldFlash = null;
      final r = _round;
      _hintVisible = r is TypingRound && r.showHintAtStart;
      _hintUsed = false;
      _slots = r is TypingRound && isSlotRound(r)
          ? TileSlots(r.charButtons, slotCount(r))
          : r is TimeRound
          ? TileSlots(r.tiles, r.syllables.length)
          : null;
      _period = null;
      _links = r is LinkRound ? LinkBoard(r) : null;
      _linkPick = null;
      _dragFrom = null;
      _dragTo = null;
      _wrongLine = null;
      _wrongTimer?.cancel();
    });
  }

  /// ➡️: a skipped round breaks the streak (but not when the round was
  /// already won and we're only waiting out the pause).
  void _skip() {
    if (!_won) _streak.miss();
    _nextRound(newGame: true);
  }

  /// The Korean to read aloud after a win: what the player entered when the
  /// answer is Korean, otherwise the Korean prompt (number games included).
  String _spokenAnswer(Object r, {String? entered}) {
    if (r is ColorRound) return r.answer;
    if (r is TimeRound) return r.spokenFor(entered ?? '');
    // Link Up: the Korean of the last line, which finished the board.
    if (r is LinkRound) return entered ?? '';
    if (r is ChoiceRound) {
      if (r.optionsAreKorean) return r.correctAnswer;
      return r.promptIsKorean ? r.prompt : '';
    }
    final t = r as TypingRound;
    if (t.answerIsKorean) {
      final e = entered?.trim() ?? '';
      return containsHangul(e) ? e : t.answer1;
    }
    return t.promptIsKorean ? t.prompt : '';
  }

  /// The word a round is about (null for 7️⃣ 8️⃣ 9️⃣).
  static VocabEntry? _wordOf(Object r) => r is ChoiceRound
      ? r.word
      : r is TypingRound
      ? r.word
      : null;

  /// resetGame(True): count the win, celebrate, read the answer aloud, wait,
  /// start a new round.
  Future<void> _win({String? entered}) async {
    final r = _round;
    if (r == null) return;
    final id = _roundId;
    _won = true;
    _streak.hit();
    if (appState.vibration) Buzz.right();
    _confetti.play();
    setState(() {
      _locked = true;
      _cheer = appState.showStreak && _streak.isMilestone
          ? '${_streak.label}!'
          : pick(winCheers, _rand);
      _cheerId++;
    });
    unawaited(
      appState.recordWin(
        _game,
        inShuffle: widget.shuffle,
        word: _wordOf(r),
        words: r is LinkRound ? r.words : const [],
      ),
    );
    final text = _spokenAnswer(r, entered: entered);
    await WinPause.run(
      spokenAnswer: appState.spokenAnswer && text.isNotEmpty,
      speak: () => Speaker.instance.speakAndWait(text),
    );
    if (mounted && id == _roundId) await _maybeDigitalPrompt();
    if (mounted && id == _roundId) await _maybeNativePrompt();
    if (mounted && id == _roundId) _nextRound(newGame: true);
  }

  /// 🖐️ played directly: every 5 in a row offers a bigger number range,
  /// until the range has ever been set to 99.
  Future<void> _maybeNativePrompt() async {
    if (widget.shuffle || _game != 8) return;
    final n = _streak.count;
    if (n == 0 || n % 5 != 0) return;
    if (appState.nativeMax >= 99 || appState.native99Reached) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('native_prompt'),
        title: Text('🔥 $n in a row! Ready for bigger numbers?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Raise the top number and keep counting!'),
            SizedBox(height: 12),
            NativeRangeOption(),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('native_prompt_done'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// 🕒 played directly: the first 5x streak ever offers turning ⌚ off.
  /// Shown once (also counted as shown if ⌚ is already off).
  Future<void> _maybeDigitalPrompt() async {
    if (widget.shuffle || _game != GameEngine.timeGame) return;
    if (_streak.count < 5 || appState.digitalPromptShown) return;
    unawaited(appState.markDigitalPromptShown());
    if (!appState.showDigitalTime) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('digital_prompt'),
        title: const Text('🔥 5 in a row! Ready for a bigger challenge?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Turn off the digital time and read the clock hands only!'),
            SizedBox(height: 12),
            DigitalTimeOption(),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('digital_prompt_done'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// A wrong attempt: light tick, streak broken.
  void _miss() {
    _streak.miss();
    if (appState.vibration) Buzz.wrong();
  }

  Future<void> _delay() => Future<void>.delayed(WinPause.quick);

  // ---------------------------------------------------------------- shared input (typing, keypad, tiles)

  /// Filled slot tapped: its tile goes back to the pile, leaving a gap.
  void _onSlot(int i) {
    if (_locked || _slots?.tileAt(i) == null) return;
    setState(() {
      _slots!.removeAt(i);
      _fieldFlash = null;
    });
  }

  /// Replace the field text in one go (cursor at the end, no composing region).
  /// Only used by the on-screen keypad, never while the user is typing.
  void _setInput(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _backspace() {
    if (_locked) return;
    final slots = _slots;
    if (slots != null) {
      setState(() {
        slots.backspace();
        _fieldFlash = null;
      });
      return;
    }
    if (_input.text.isEmpty) return;
    final chars = _input.text.characters;
    _setInput(chars.take(chars.length - 1).toString());
    setState(() {});
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      colors: _info.gradient == null
          ? [
              Color.lerp(_info.color, Colors.white, 0.82)!,
              const Color(0xFFFFF8E1),
              Color.lerp(_info.color, Colors.white, 0.7)!,
            ]
          // 9️⃣: a pale rainbow.
          : _info.shades(Colors.white, 0.84),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.shuffle ? shuffleInfo.emoji : _info.emoji,
            style: const TextStyle(fontSize: 30),
          ),
          actions: [
            if (_game == 7 || _game == 8)
              NumberHelpButton(
                _game == 7 ? sinoNumberHelp : nativeNumberHelp,
                key: const ValueKey('number_help'),
              ),
            if (_game == GameEngine.timeGame)
              const NumberHelpButton(timeHelp, key: ValueKey('number_help')),
            if (_hintUsed && _ghostChars != null)
              IconButton(
                key: const ValueKey('hint_speak'),
                tooltip: 'Hear the answer',
                onPressed: () => Speaker.instance.speak(_hintSpeech),
                icon: const Text('🔊', style: TextStyle(fontSize: 24)),
              ),
            ListenableBuilder(
              listenable: appState,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (appState.showStreak)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: _streak.label == null
                          ? const SizedBox.shrink(key: ValueKey('no-streak'))
                          : Container(
                              key: ValueKey('streak-${_streak.count}'),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9F1C),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _streak.label!,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  if (appState.showWins)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        '🏆 ${widget.shuffle ? appState.shuffleSessionWins : appState.sessionWins[_game]}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(child: _round == null ? _notEnoughWords() : _roundBody()),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                emissionFrequency: 0.08,
                gravity: 0.25,
                colors: const [
                  Color(0xFFFF5C8A),
                  Color(0xFFFF9F1C),
                  Color(0xFF2EC4B6),
                  Color(0xFF7B5CFF),
                  Color(0xFFFFE600),
                  Color(0xFF3DDC84),
                ],
              ),
            ),
            if (_cheer != null)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_cheerId),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    builder: (_, t, _) {
                      final scale = t < 0.25 ? Curves.elasticOut.transform(t / 0.25) : 1.0;
                      final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                      return Opacity(
                        opacity: opacity.clamp(0, 1),
                        child: Transform.scale(
                          scale: scale,
                          child: Center(
                            child: Text(
                              _cheer!,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                                shadows: [Shadow(color: Colors.white, blurRadius: 12)],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 🔀 Shuffle when none of the switched-on games can be played.
  bool get _noShuffleGame => widget.shuffle && _game == 0;

  Widget _notEnoughWords() => Center(
    key: ValueKey(_noShuffleGame ? 'no_shuffle_game' : 'not_enough_words'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🙀', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 12),
          Text(
            _noShuffleGame ? 'No 🔀 Shuffle games to play!' : 'Not enough words to play!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _red),
          ),
          const SizedBox(height: 8),
          Text(
            _noShuffleGame
                ? 'The games switched on for 🔀 Shuffle need at least 3 words. '
                      'Turn on a word pack, or switch on more games in 🔀 Shuffle games.'
                : 'You need at least $_wordsNeeded words. Turn on a word pack or add some of your own words.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _ink),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              BouncyButton(
                color: const Color(0xFF00B4FF),
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const BundlesScreen()));
                  if (mounted) _nextRound();
                },
                child: const Text('📦 Word Packs', style: TextStyle(fontSize: 18)),
              ),
              if (_noShuffleGame) ...[
                BouncyButton(
                  key: const ValueKey('open_shuffle_games'),
                  color: shuffleInfo.color,
                  onTap: () async {
                    await Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ShuffleGamesScreen()));
                    if (mounted) _nextRound(newGame: true);
                  },
                  child: const Text('🔀', style: TextStyle(fontSize: 26)),
                ),
              ],
              BouncyButton(
                color: const Color(0xFFFF5C8A),
                onTap: () => Navigator.of(context).pop(),
                child: const Text('↩️', style: TextStyle(fontSize: 26)),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Words a game needs: a full Link Up board, or 3 for the others.
  int get _wordsNeeded => _game == GameEngine.linkUpGame ? LinkRound.size : GameEngine.answerCount;

  Widget _roundBody() {
    final r = _round!;
    if (r is LinkRound) return _linkBody(r);

    return ListView(
      key: ValueKey(_roundId),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        if (widget.shuffle) _shuffleBanner(),
        if (r is ColorRound)
          ..._colorBody(r)
        else if (r is TimeRound)
          ..._timeBody(r)
        else if (r is ChoiceRound)
          ..._choice(r)
        else
          ..._typing(r as TypingRound),
      ],
    );
  }

  /// 🔀 Shuffle: which game this is, e.g. '5️⃣ 🧩 Syllable scramble'.
  Widget _shuffleBanner() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: _info.fill(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(_info.gradient?.last ?? _info.color, Colors.black, 0.25)!,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _info.tileName,
          key: const ValueKey('shuffle_game_name'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: _info.gradient == null ? null : _textShadow,
          ),
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------- shared widgets

  Widget _promptCard(String text, bool isKorean, {String english = ''}) {
    final size = baseSizeFor(text);
    return ThemedBorderBox(
      key: const ValueKey('prompt_card'),
      info: _info,
      width: 4,
      radius: 28,
      fillColor: Colors.white,
      margin: const EdgeInsets.only(top: 34, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      boxShadow: [
        BoxShadow(
          color: (_info.gradient?.last ?? _info.color).withValues(alpha: 0.35),
          offset: const Offset(0, 6),
        ),
      ],
      child: Row(
        children: [
          Expanded(
            child: english.isNotEmpty
                ? EmojiPeek(
                    emoji: text,
                    english: english,
                    showEnglish: _peek,
                    emojiSize: size,
                    color: _ink,
                    onTap: () => setState(() => _peek = !_peek),
                  )
                : isKorean
                ? Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: _ink),
                  )
                // English (or an emoji, or digits): shrinks to fit, never overflows.
                : FitText(
                    text,
                    key: const ValueKey('prompt_text'),
                    base: size,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
                  ),
          ),
          if (isKorean) SpeakButton(text: () => text, size: 36),
        ],
      ),
    );
  }

  /// Answer-button text size (⚙️ 🔠 Button Font Size).
  double get _bf => appState.buttonFontSize;

  List<Widget> _typing(TypingRound r) {
    final slots = _slots;
    final keypad = isKeypadRound(r);
    return [
      _promptCard(r.prompt, r.promptIsKorean, english: r.promptEnglish),
      // Hint text (answer), toggled by the ? button.
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _hintVisible && slots == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        r.answer1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B4E8C),
                        ),
                      ),
                    ),
                    if (r.answerIsKorean) SpeakButton(text: () => r.answer1),
                  ],
                ),
              )
            : const SizedBox(height: 12, width: double.infinity),
      ),
      if (slots != null)
        ..._slotBody(r, slots)
      else if (keypad)
        ..._keypadBody(r)
      else
        _textFieldRow(r),
      if (r.repetitions > 1) _progress(r),
      const SizedBox(height: 18),
      _controlRow(r.answer1.isNotEmpty ? _toggleHint : null),
    ];
  }

  Widget _slotBox(int i, TileSlots slots, double box) => GestureDetector(
    key: ValueKey('slot_$i'),
    onTap: () => _onSlot(i),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: box,
      height: box * 1.15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            _fieldFlash ??
            (slots.tileAt(i) == null ? Colors.white.withValues(alpha: 0.7) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slots.tileAt(i) == null ? _info.color.withValues(alpha: 0.5) : _info.color,
          width: 3,
        ),
      ),
      child: slots.charAt(i) == null && _hintVisible && _ghostChars != null
          ? Text(
              _ghostChars![i],
              key: ValueKey('ghost_$i'),
              style: TextStyle(
                fontSize: box * 0.55,
                fontWeight: FontWeight.w900,
                color: _ink.withValues(alpha: 0.25),
              ),
            )
          : Text(
              slots.charAt(i) ?? '',
              style: TextStyle(fontSize: box * 0.55, fontWeight: FontWeight.w900, color: _ink),
            ),
    ),
  );

  /// The correct letter per slot, for 🕒/🧩/🌀 (null in other rounds).
  List<String>? get _ghostChars {
    final r = _round;
    if (_slots == null) return null;
    if (r is TimeRound) return r.syllables;
    if (r is TypingRound) return r.answer1.split('').where((c) => c.trim().isNotEmpty).toList();
    return null;
  }

  /// What 🔊 reads after a hint: the full answer (🕒 with 오전/오후).
  String get _hintSpeech {
    final r = _round;
    return r is TimeRound ? r.korean : (r as TypingRound).answer1;
  }

  void _toggleHint() => setState(() {
    _hintVisible = !_hintVisible;
    if (_ghostChars != null) _hintUsed = true;
  });

  /// 🕒: the 9 syllable tiles and ⌫ as two rows of 5 equal buttons.
  Widget _timeTiles(List<String> tiles, TileSlots slots, void Function(int) onTile) {
    Widget cell(Widget b) => Expanded(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b),
    );
    Widget button(int i) {
      if (i == tiles.length) {
        return BouncyButton(
          key: const ValueKey('tile_backspace'),
          color: const Color(0xFF9E9E9E),
          padding: const EdgeInsets.symmetric(vertical: 12),
          radius: 16,
          onTap: _backspace,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('⌫', style: TextStyle(fontSize: _bf)),
          ),
        );
      }
      return AnimatedOpacity(
        key: ValueKey('tile_$i'),
        duration: const Duration(milliseconds: 150),
        opacity: slots.isUsed(i) ? 0.2 : 1,
        child: BouncyButton(
          color: _helperPalette[i % _helperPalette.length],
          padding: const EdgeInsets.symmetric(vertical: 12),
          radius: 16,
          onTap: slots.isUsed(i) ? null : () => onTile(i),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tiles[i], style: TextStyle(fontSize: _bf)),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('time_tiles'),
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
            child: Row(children: [for (var c = 0; c < 5; c++) cell(button(row * 5 + c))]),
          ),
      ],
    );
  }

  /// ➡️ next (no score), ↩️ back to the menu, ? hint (typing rounds only).
  Widget _controlRow(VoidCallback? onHint) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      BouncyButton(
        color: const Color(0xFFFF9F1C),
        onTap: _skip,
        child: const Text('➡️', style: TextStyle(fontSize: 30)),
      ),
      const SizedBox(width: 16),
      BouncyButton(
        color: const Color(0xFFFF5C8A),
        onTap: () => Navigator.of(context).pop(),
        child: const Text('↩️', style: TextStyle(fontSize: 30)),
      ),
      if (onHint != null) ...[
        const SizedBox(width: 16),
        BouncyButton(
          color: const Color(0xFF7B5CFF),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          onTap: onHint,
          child: const Text('?', style: TextStyle(fontSize: 30)),
        ),
      ],
    ],
  );
}
