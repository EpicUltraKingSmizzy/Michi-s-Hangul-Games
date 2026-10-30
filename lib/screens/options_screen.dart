import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/game_engine.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'shuffle_games_screen.dart';

const _ink = Color(0xFF3A1D5C);

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '⚙️ Options',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink),
          ),
        ),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _OptionCard(
                key: const ValueKey('opt_vibration'),
                emoji: '📳',
                title: 'Vibration',
                value: appState.vibration,
                color: const Color(0xFFFF9F1C),
                onChanged: appState.setVibration,
              ),
              _OptionCard(
                key: const ValueKey('opt_show_streak'),
                emoji: '🔥',
                title: 'Streak count',
                value: appState.showStreak,
                color: const Color(0xFFFF5C8A),
                onChanged: appState.setShowStreak,
              ),
              _OptionCard(
                key: const ValueKey('opt_show_wins'),
                emoji: '🏆',
                title: 'Win count',
                blurb: 'Show the 🏆 win counters. Wins are always saved to 📊 Stats.',
                value: appState.showWins,
                color: const Color(0xFF3DDC84),
                onChanged: appState.setShowWins,
              ),
              _OptionCard(
                key: const ValueKey('opt_spoken_answer'),
                emoji: '🔊',
                title: 'Spoken Answer',
                blurb: 'Read the Korean answer aloud when you win, and the syllable buttons when you tap them.',
                value: appState.spokenAnswer,
                color: const Color(0xFF7B5CFF),
                onChanged: appState.setSpokenAnswer,
              ),
              _OptionCard(
                key: const ValueKey('opt_use_emoji'),
                emoji: '😀',
                title: 'Emoji',
                blurb: 'Words show up as emojis like 🍎 in the games. Turn off to see the English word instead.',
                value: appState.useEmoji,
                color: const Color(0xFF00B4D8),
                onChanged: appState.setUseEmoji,
              ),
              _OptionCard(
                key: const ValueKey('opt_show_bracket_notes'),
                emoji: '📑',
                title: 'Bracket notes',
                blurb: 'Show context in brackets like Orange (color) and Orange (fruit).',
                value: appState.showBracketNotes,
                color: const Color(0xFFFFB703),
                onChanged: appState.setShowBracketNotes,
              ),
              _SliderCard(
                key: const ValueKey('opt_button_font'),
                emoji: '🔠',
                title: 'Button Font Size',
                blurb: 'Text size on the answer buttons in every game.',
                value: appState.buttonFont,
                min: 0,
                max: AppState.buttonFontSizes.length - 1,
                labels: AppState.buttonFontLabels,
                color: const Color(0xFF8E7DBE),
                onChanged: appState.setButtonFont,
              ),
              _NavCard(
                key: const ValueKey('opt_shuffle_games'),
                emoji: shuffleInfo.emoji,
                title: 'Shuffle games',
                summary: '${appState.shuffleGameCount} of ${GameEngine.gameCount} games',
                color: shuffleInfo.color,
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ShuffleGamesScreen())),
              ),
              _SliderCard(
                key: const ValueKey('opt_game3_repetitions'),
                emoji: '🔁',
                title: 'Typing repetitions',
                blurb: 'How many times to type each word in ✍️ Typing practice.',
                value: appState.game3Repetitions,
                min: GameEngine.minGame3Repetitions,
                max: GameEngine.maxGame3Repetitions,
                color: const Color(0xFF2EC4B6),
                onChanged: appState.setGame3Repetitions,
              ),
              _SliderCard(
                key: const ValueKey('opt_game7_max_digits'),
                emoji: gameInfos[6].emoji,
                title: 'Number length',
                blurb: 'The most digits a number can have in 🔢 Sino numbers.',
                value: appState.game7MaxDigits,
                min: GameEngine.minGame7MaxDigits,
                max: GameEngine.maxGame7MaxDigits,
                color: gameInfos[6].color,
                onChanged: appState.setGame7MaxDigits,
              ),
              const NativeRangeOption(),
              const DigitalTimeOption(),
              const SentenceLevelOption(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji, title;
  final String? blurb;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _OptionCard({
    super.key,
    required this.emoji,
    required this.title,
    this.blurb,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color, width: 3),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), offset: const Offset(0, 5))],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        activeThumbColor: color,
        secondary: Text(emoji, style: const TextStyle(fontSize: 34)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink),
        ),
        subtitle: blurb == null
            ? null
            : Text(blurb!, style: const TextStyle(fontSize: 14, color: Color(0xFF6B4E8C))),
        value: value,
        onChanged: onChanged,
      ),
    ),
  );
}

/// An option card with a whole-number slider and the current value shown.
/// ⌚ Digital time option card, shared by Options and the 🕒 5x-streak pop-up.
class DigitalTimeOption extends StatelessWidget {
  const DigitalTimeOption({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (_, _) => _OptionCard(
      key: const ValueKey('opt_show_digital_time'),
      emoji: '⌚',
      title: 'Digital time',
      blurb: 'Show the time in numbers in 🕒 What Time Is It?',
      value: appState.showDigitalTime,
      color: gameInfos[GameEngine.timeGame - 1].color,
      onChanged: appState.setShowDigitalTime,
    ),
  );
}

/// 🖐️ Native numbers top number, shared by Options and the 🖐️ pop-up.
class NativeRangeOption extends StatelessWidget {
  const NativeRangeOption({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (_, _) => _SliderCard(
      key: const ValueKey('opt_native_max'),
      emoji: gameInfos[7].emoji,
      title: 'Number range',
      blurb: 'The biggest number in 🖐️ Native numbers.',
      value: GameEngine.nativeMaxStops.indexOf(appState.nativeMax),
      min: 0,
      max: GameEngine.nativeMaxStops.length - 1,
      labels: [for (final n in GameEngine.nativeMaxStops) '$n'],
      color: gameInfos[7].color,
      onChanged: (i) => appState.setNativeMax(GameEngine.nativeMaxStops[i]),
    ),
  );
}

/// 🤖 Sentence difficulty, shared by Options and the 🏗️ pop-up.
class SentenceLevelOption extends StatelessWidget {
  const SentenceLevelOption({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (_, _) => _SliderCard(
      key: const ValueKey('opt_sentence_level'),
      emoji: '🤖',
      title: 'Sentence difficulty',
      blurb: 'How long the sentences are in 🏗️ Sentence Builder, and in other games when Verb Packs are on.',
      value: appState.sentenceLevel,
      min: sentenceEasy,
      max: sentenceMaster,
      labels: sentenceLevelLabels,
      color: gameInfos[GameEngine.sentenceGame - 1].color,
      onChanged: appState.setSentenceLevel,
    ),
  );
}

class _SliderCard extends StatelessWidget {
  final String emoji, title, blurb;
  final int value, min, max;
  final Color color;
  final ValueChanged<int> onChanged;

  /// Names for the stops (min..max); null shows the numbers.
  final List<String>? labels;
  const _SliderCard({
    this.labels,
    super.key,
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  /// Key prefix for the value bubble and slider, e.g. 'opt_game7_max_digits'.
  String get _id => (key as ValueKey<String>).value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color, width: 3),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), offset: const Offset(0, 5))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  const SizedBox(height: 2),
                  Text(blurb, style: const TextStyle(fontSize: 14, color: Color(0xFF6B4E8C))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                labels == null
                    ? '$value'
                    : (labels![value - min].length <= 2
                          ? labels![value - min]
                          : labels![value - min][0]),
                key: ValueKey('${_id}_value'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.25),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            activeTickMarkColor: Colors.white,
            inactiveTickMarkColor: color,
            trackHeight: 6,
          ),
          child: Slider(
            key: ValueKey('${_id}_slider'),
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: labels == null ? '$value' : labels![value - min],
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = min; i <= max; i++)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels == null ? '$i' : labels![i - min],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: i == value ? FontWeight.w900 : FontWeight.w600,
                        color: i == value ? _ink : const Color(0xFF6B4E8C),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    ),
  );
}

/// A tappable option row that opens a sub-screen: emoji, title, a short
/// summary and a chevron.
class _NavCard extends StatelessWidget {
  final String emoji, title, summary;
  final Color color;
  final VoidCallback onTap;
  const _NavCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.summary,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color, width: 3),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), offset: const Offset(0, 5))],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        leading: Text(emoji, style: const TextStyle(fontSize: 34)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink),
        ),
        subtitle: Text(
          summary,
          key: const ValueKey('opt_shuffle_games_summary'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B4E8C),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, size: 36, color: color),
        onTap: onTap,
      ),
    ),
  );
}
