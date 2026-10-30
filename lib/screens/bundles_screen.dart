import 'package:flutter/material.dart';

import '../data/bundles.dart';
import '../data/packs.dart';
import '../main.dart';
import '../models/vocab_entry.dart';
import '../widgets/number_help.dart';
import '../widgets/common.dart';
import 'custom_words_screen.dart';

class BundlesScreen extends StatelessWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📦 Word Packs'),
                const SizedBox(width: 10),
                // Master switch: every built-in and user pack (never My Words).
                Switch(
                  key: const ValueKey('all_packs'),
                  value: appState.allPacksOn,
                  onChanged: appState.setAllPacks,
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${wordsInPlay(appState.activeVocab().length)}.',
                  key: const ValueKey('packs_in_play'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (appState.verbPackIds.isNotEmpty)
                Card(
                  key: const ValueKey('verb_packs_button'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  child: ListTile(
                    title: const Text(
                      'Verb Packs',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text('${appState.verbPackIds.length} packs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const VerbPacksScreen())),
                  ),
                ),
              for (final id in appState.builtInPackIds) _builtInCard(id),
              for (final p in appState.userPacks)
                _BundleCard(
                  key: ValueKey('pack_${p.id}'),
                  emoji: p.emoji,
                  name: p.name,
                  blurb: 'Your own pack.',
                  words: appState.wordsInPack(p.id),
                  enabled: appState.enabledBundles.contains(p.id),
                  onChanged: (v) => appState.setBundleEnabled(p.id, v),
                ),
              _BundleCard(
                key: const ValueKey('pack_$customBundleId'),
                emoji: myWordsEmoji,
                name: myWordsName,
                blurb: 'Words you added yourself.',
                words: appState.wordsInPack(customBundleId),
                enabled: appState.enabledBundles.contains(customBundleId),
                onChanged: (v) => appState.setBundleEnabled(customBundleId, v),
                trailing: TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const CustomWordsScreen())),
                  child: const Text('Add & manage ✏️'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A built-in pack's card (the main list and the Verb Packs screen).
Widget _builtInCard(String id) {
  final b = builtInBundleById(id)!;
  return _BundleCard(
    key: ValueKey('pack_$id'),
    emoji: b.emoji,
    name: b.name,
    blurb: b.blurb,
    words: appState.wordsInPack(id),
    enabled: appState.enabledBundles.contains(id),
    onChanged: (v) => appState.setBundleEnabled(id, v),
    help: numberHelpForPack(id),
    helpKey: 'pack_help_$id',
  );
}

/// The Verb Packs, opened from the Word Packs screen. Same cards as the
/// main list (switch, expand, tap to hear, long press to edit).
class VerbPacksScreen extends StatelessWidget {
  const VerbPacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Verb Packs')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Verbs will appear in sentences in a game coming soon.',
                  key: ValueKey('verb_packs_note'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              for (final id in appState.verbPackIds) _builtInCard(id),
            ],
          ),
        ),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  final String emoji, name, blurb;
  final List<VocabEntry> words;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  /// A ❓ explainer next to the switch (number packs).
  final NumberHelp? help;
  final String? helpKey;
  const _BundleCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.blurb,
    required this.words,
    required this.enabled,
    required this.onChanged,
    this.trailing,
    this.help,
    this.helpKey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: enabled ? Colors.white : const Color(0xFFF1F1F1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: ExpansionTile(
        shape: const Border(),
        leading: Text(emoji, style: const TextStyle(fontSize: 34)),
        title: Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${words.isEmpty ? 'Empty' : packCountLabel(words)} • $blurb',
          key: ValueKey('pack_count_$name'),
        ),
        trailing: help == null
            ? Switch(value: enabled, onChanged: onChanged)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NumberHelpButton(help!, key: ValueKey<String>(helpKey!)),
                  Switch(value: enabled, onChanged: onChanged),
                ],
              ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?trailing,
          if (words.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 16, 6),
              child: Text(
                'Tap a word to hear it. Long press to edit it.',
                key: ValueKey('long_press_hint'),
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black54),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in words)
                  GestureDetector(
                    key: ValueKey('word_${w.sectionName}'),
                    // Tap = hear the Korean; long press = edit (silent).
                    onTap: () => speakKorean(context, w.korean1),
                    onLongPress: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => EditWordScreen(entry: w))),
                    child: Chip(
                      label: Text(
                        '${w.emoji.isNotEmpty ? '${w.emoji} ' : ''}${appState.displayEnglish(w.english1)} = ${w.korean1}',
                      ),
                    ),
                  ),
                if (words.isEmpty) const Text('Nothing here yet!'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String wordCount(int n) => n == 1 ? '1 word' : '$n words';

String phraseCount(int n) => n == 1 ? '1 phrase' : '$n phrases';

/// A pack's counter: words and phrases (IsFullPhrase) separately, leaving
/// out a count of 0, e.g. '18 words · 6 phrases', '24 phrases', '1 word'.
/// An empty pack gives '' (the card then says 'Empty').
String packCountLabel(List<VocabEntry> entries) {
  final phrases = entries.where((e) => e.isFullPhrase).length;
  final words = entries.length - phrases;
  return [if (words > 0) wordCount(words), if (phrases > 0) phraseCount(phrases)].join(' · ');
}
