import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Fun picks for a new Word Pack's emoji. Any emoji can be typed or pasted too.
// dart format off
const List<String> packEmojiChoices = [
  '⭐', '🌟', '🔥', '💖', '🌸', '🌻', '🍀', '🌈',
  '🐶', '🐱', '🐼', '🦊', '🐸', '🐙', '🦄', '🐝',
  '🍕', '🍩', '🍓', '🍉', '🧋', '🍙', '🍦', '🥟',
  '⚽', '🎮', '🎨', '🎵', '🎬', '📚', '🧸', '🎁',
  '🚀', '✈️', '🚲', '🏖️', '🏔️', '🏰', '🌙', '☀️',
  '💼', '🏫', '🏥', '🛒', '💎', '👑', '🎉', '🧠',
];
// dart format on

/// Shown when a saved word would start a new Word Pack. Pops with the chosen
/// emoji, or null when the player backs out (nothing is saved then).
class EmojiPickerScreen extends StatefulWidget {
  final String packName;
  final String initialEmoji;
  const EmojiPickerScreen({super.key, required this.packName, this.initialEmoji = ''});

  @override
  State<EmojiPickerScreen> createState() => _EmojiPickerScreenState();
}

class _EmojiPickerScreenState extends State<EmojiPickerScreen> {
  late String _emoji = widget.initialEmoji;
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _onTyped(String v) {
    final t = v.trim();
    // Keep a single emoji (one grapheme cluster, so 👨‍👩‍👧 and flags stay whole).
    setState(() => _emoji = t.isEmpty ? '' : t.characters.first);
  }

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('🎨 Pick a pack emoji')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        _emoji.isEmpty ? '❔' : _emoji,
                        key: const ValueKey('emoji_preview'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your new Word Pack', style: TextStyle(fontSize: 14)),
                          Text(
                            widget.packName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final e in packEmojiChoices)
                  InkWell(
                    key: ValueKey('emoji_choice_$e'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _emoji = e;
                      _typed.clear();
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _emoji == e ? const Color(0xFFFFE08A) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(child: Text(e, style: const TextStyle(fontSize: 28))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('emoji_field'),
              controller: _typed,
              onChanged: _onTyped,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'Or type / paste any emoji',
                hintText: 'e.g. 🦖',
              ),
            ),
            const SizedBox(height: 20),
            Opacity(
              opacity: _emoji.isEmpty ? 0.45 : 1,
              child: BouncyButton(
                key: const ValueKey('emoji_confirm'),
                color: const Color(0xFF3DDC84),
                onTap: _emoji.isEmpty ? null : () => Navigator.of(context).pop(_emoji),
                child: const Center(
                  child: Text('✅ Create pack & save', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
