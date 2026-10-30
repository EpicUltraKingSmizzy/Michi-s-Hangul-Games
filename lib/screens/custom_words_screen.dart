import 'package:flutter/material.dart';

import '../data/bundles.dart';
import '../data/packs.dart';
import '../data/speaker.dart';
import '../main.dart';
import '../models/vocab_entry.dart';
import '../widgets/common.dart';
import 'emoji_picker_screen.dart';

class CustomWordsScreen extends StatelessWidget {
  const CustomWordsScreen({super.key});

  Future<void> _edit(BuildContext context, [VocabEntry? e]) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditWordScreen(entry: e)));

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('✏️ My Words')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Text('➕', style: TextStyle(fontSize: 22)),
          label: const Text('Add a word', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final words = appState.customWords;
            if (words.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    '🦄\nNo custom words yet!\nTap ➕ to add your first one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: words.length,
              itemBuilder: (context, i) {
                final w = words[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: Text(
                      w.emoji.isNotEmpty ? w.emoji : '📝',
                      style: const TextStyle(fontSize: 30),
                    ),
                    title: Text(
                      '${w.korean1}${w.korean2.isNotEmpty ? ' / ${w.korean2}' : ''}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        appState.displayEnglish(w.english1),
                        if (w.english2.isNotEmpty) appState.displayEnglish(w.english2),
                        '${appState.packLabel(w.packId).emoji} ${appState.packLabel(w.packId).name}',
                        if (w.isFullPhrase) '💬 phrase',
                      ].join(' • '),
                    ),
                    onTap: () => _edit(context, w),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SpeakButton(text: () => w.korean1, size: 24),
                        IconButton(
                          icon: const Text('🗑️', style: TextStyle(fontSize: 22)),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete this word? 🥺'),
                                content: Text(
                                  '${appState.displayEnglish(w.english1)} = ${w.korean1}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Keep it'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) await appState.deleteCustomWord(w);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// New Word and Edit Word: the same screen, only the title differs.
/// Works for custom words and built-in words (saved as a local edit, with
/// Reset to bring back the original).
class EditWordScreen extends StatefulWidget {
  final VocabEntry? entry;
  const EditWordScreen({super.key, this.entry});
  @override
  State<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends State<EditWordScreen> {
  final _form = GlobalKey<FormState>();
  late final _english1 = TextEditingController(text: widget.entry?.english1);
  late final _english2 = TextEditingController(text: widget.entry?.english2);
  late final _emoji = TextEditingController(text: widget.entry?.emoji);
  late final _korean1 = TextEditingController(text: widget.entry?.korean1);
  late final _korean2 = TextEditingController(text: widget.entry?.korean2);
  late final _pack = TextEditingController(
    text: widget.entry == null ? '' : appState.packLabel(widget.entry!.packId).name,
  )..addListener(() => setState(() {}));
  late bool _phrase = widget.entry?.isFullPhrase ?? false;
  late final bool _builtIn = widget.entry != null && appState.isBuiltInWord(widget.entry!);

  /// Edit Verb: a word in a Verb Pack. No Emoji field, Korean read-only (the
  /// sentence grammar hangs on it), and only Verb Packs to pick from.
  late final bool _verb = widget.entry != null && appState.isVerbPack(widget.entry!.packId);

  @override
  void dispose() {
    for (final c in [_english1, _english2, _emoji, _korean1, _korean2, _pack]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    bool required = false,
    bool readOnly = false,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextFormField(
      controller: c,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
      style: const TextStyle(fontSize: 18),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'This one is needed! 🙏' : null
          : null,
    ),
  );

  /// Edit Word only: 🔊 by Korean 1, reading what is typed there now;
  /// greyed out while the field is empty or has no Hangul.
  Widget _speakKorean1() => ListenableBuilder(
    listenable: _korean1,
    builder: (context, _) => SpeakButton(
      key: const ValueKey('speak_korean1'),
      text: () => _korean1.text,
      size: 26,
      enabled: containsHangul(_korean1.text),
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final choice = appState.resolvePack(_pack.text, verbs: _verb);
    var packEmoji = '';
    if (choice.kind == PackKind.newPack) {
      final picked = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => EmojiPickerScreen(packName: choice.name, initialEmoji: choice.typedEmoji),
        ),
      );
      if (picked == null) return; // backed out: stay on the form, nothing saved
      packEmoji = picked;
    }
    await appState.saveWord(
      VocabEntry(
        sectionName: widget.entry?.sectionName ?? '',
        english1: _english1.text.trim(),
        english2: _english2.text.trim(),
        emoji: _emoji.text.trim(),
        korean1: _korean1.text.trim(),
        korean2: _korean2.text.trim(),
        isFullPhrase: _phrase,
      ),
      packChoice: choice,
      newPackEmoji: packEmoji,
      verb: _verb,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _reset() async {
    final e = widget.entry!;
    final original = appState.originalOf(e)!;
    final ok = await _confirm(
      'Reset this word? ↩️',
      'Back to the original: ${appState.displayEnglish(original.english1)} = ${original.korean1} '
          '(${appState.packLabel(original.packId).name}).',
      'Reset',
    );
    if (!ok) return;
    await appState.resetBuiltInWord(e);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    final ok = await _confirm(
      'Delete this word? 🥺',
      '${appState.displayEnglish(e.english1)} = ${e.korean1}',
      'Delete',
    );
    if (!ok) return;
    await appState.deleteCustomWord(e);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final choice = appState.resolvePack(_pack.text, verbs: _verb);
    final picks = <({String id, String emoji, String name})>[
      if (_verb) ...[
        for (final id in appState.verbPackIds)
          (id: id, emoji: appState.packLabel(id).emoji, name: appState.packLabel(id).name),
        for (final p in appState.userVerbPacks) (id: p.id, emoji: p.emoji, name: p.name),
      ] else ...[
        (id: customBundleId, emoji: myWordsEmoji, name: myWordsName),
        for (final id in appState.builtInPackIds)
          (id: id, emoji: appState.packLabel(id).emoji, name: appState.packLabel(id).name),
        for (final p in appState.userWordPacks) (id: p.id, emoji: p.emoji, name: p.name),
      ],
    ];
    final edited = _builtIn && appState.isOverridden(widget.entry!);
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.entry == null
                ? '➕ New Word'
                : _verb
                ? '✏️ Edit Verb'
                : '✏️ Edit Word',
          ),
        ),
        // Save (and Reset / Delete) stay on screen however long the pack list is.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: BouncyButton(
                    key: const ValueKey('save_word'),
                    color: const Color(0xFF3DDC84),
                    onTap: _save,
                    child: const Center(
                      heightFactor: 1,
                      child: Text('💾 Save', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                if (_builtIn) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Opacity(
                      opacity: edited ? 1 : 0.45,
                      child: BouncyButton(
                        key: const ValueKey('reset_word'),
                        color: const Color(0xFFFFD166),
                        onTap: edited ? _reset : null,
                        child: const Center(
                          heightFactor: 1,
                          child: Text('↩️ Reset', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.entry != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BouncyButton(
                      key: const ValueKey('delete_word'),
                      color: const Color(0xFFFF8FA3),
                      onTap: _delete,
                      child: const Center(
                        heightFactor: 1,
                        child: Text('🗑️ Delete', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
            children: [
              _field(
                _korean1,
                'Korean 1 *',
                'e.g. 고양이',
                required: true,
                readOnly: _verb,
                suffix: widget.entry == null ? null : _speakKorean1(),
              ),
              // Edit Verb: no Korean 2 field (its saved value is kept as is).
              if (!_verb) _field(_korean2, 'Korean 2 (another accepted answer)', 'optional'),
              _field(_english1, 'English 1 *', 'e.g. Cat', required: true),
              _field(_english2, 'English 2', 'optional'),
              if (!_verb) _field(_emoji, 'Emoji', 'optional, e.g. 🐱 (shown instead of English)'),
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: TextFormField(
                  key: const ValueKey('pack_field'),
                  controller: _pack,
                  decoration: InputDecoration(
                    labelText: _verb ? 'Verb Pack' : 'Word Pack',
                    hintText: _verb
                        ? 'pick a Verb Pack, or name a new pack'
                        : 'blank = My Words, or name a new pack',
                  ),
                  style: const TextStyle(fontSize: 18),
                  validator: _verb
                      ? (_) => appState.resolvePack(_pack.text, verbs: true).name.isEmpty
                            ? 'This one is needed! 🙏'
                            : null
                      : null,
                ),
              ),
              // Only a new pack name gets a note (its emoji is picked next).
              if (choice.kind == PackKind.newPack && choice.name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    '✨ New pack "${choice.name}"! You will pick its emoji next.',
                    key: const ValueKey('pack_note'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in picks)
                    ChoiceChip(
                      key: ValueKey('pack_pick_${p.id}'),
                      label: Text('${p.emoji} ${p.name}'),
                      selected: choice.kind != PackKind.newPack && choice.id == p.id,
                      onSelected: (_) => _pack.text = p.name,
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '💬 This is a full phrase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                value: _phrase,
                onChanged: (v) => setState(() => _phrase = v),
              ),
              if (edited)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'You changed this built-in word. ↩️ Reset brings back the original.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
