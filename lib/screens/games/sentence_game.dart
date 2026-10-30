part of '../game_screen.dart';

/// 🏗️ Sentence Builder: the English sentence, then its Korean built from
/// word tiles; the verb is already in place (Easy/Medium) or two pieces
/// to place last (Hard/Master).
extension _SentenceGame on _GameScreenState {
  /// Tile tapped: it drops into the first empty slot.
  Future<void> _onSentenceTile(SentenceRound r, int tile) async {
    final slots = _slots;
    if (_locked || slots == null || slots.place(tile) < 0) return;
    _update(() {});
    if (!slots.isFull) return;
    final id = _roundId;
    final placed = [for (var i = 0; i < slots.length; i++) slots.charAt(i)!];
    if (r.sentence.accepts(placed)) {
      _update(() => _fieldFlash = _green);
      await _win(entered: r.sentence.korean);
    } else {
      _miss();
      _update(() {
        _fieldFlash = _red;
        _shake++;
      });
      await _delay();
      if (mounted && id == _roundId) _update(() => _fieldFlash = null);
    }
  }

  List<Widget> _sentenceBody(SentenceRound r) {
    final slots = _slots!;
    final s = r.sentence;
    final open = s.negated ? slots.length - 1 : slots.length;
    return [
      _promptCard(s.english, false),
      const SizedBox(height: 12),
      // One line: the slots, then (공부) 안 and the verb, shrunk to fit.
      Shaker(
        trigger: _shake,
        child: FittedBox(
          key: const ValueKey('sentence_line'),
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.verbPlaced)
                for (var i = 0; i < slots.length; i++) _sentenceSlot(i, slots)
              else ...[
                for (var i = 0; i < open; i++) _sentenceSlot(i, slots),
                if (s.fixedBeforeNegation.isNotEmpty) _fixedChip(s.fixedBeforeNegation),
                if (s.negated) _sentenceSlot(slots.length - 1, slots),
                _fixedChip(s.verbChip, key: const ValueKey('verb_chip')),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 12,
        children: [
          for (var i = 0; i < r.tiles.length; i++)
            AnimatedOpacity(
              key: ValueKey('tile_$i'),
              duration: const Duration(milliseconds: 150),
              opacity: slots.isUsed(i) ? 0.2 : 1,
              child: BouncyButton(
                color: _helperPalette[i % _helperPalette.length],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                radius: 16,
                onTap: slots.isUsed(i) ? null : () => _onSentenceTile(r, i),
                child: Text(r.tiles[i], style: TextStyle(fontSize: _bf)),
              ),
            ),
          BouncyButton(
            key: const ValueKey('tile_backspace'),
            color: const Color(0xFF9E9E9E),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            radius: 16,
            onTap: _backspace,
            child: Text('⌫', style: TextStyle(fontSize: _bf)),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _controlRow(_toggleHint),
    ];
  }

  /// One word slot; as wide as its word (or the faded hint).
  Widget _sentenceSlot(int i, TileSlots slots) {
    final placed = slots.charAt(i);
    final ghost = placed == null && _hintVisible ? (_ghostChars?[i]) : null;
    return GestureDetector(
      key: ValueKey('slot_$i'),
      onTap: () => _onSlot(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        constraints: const BoxConstraints(minWidth: 52),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              _fieldFlash ?? (placed == null ? Colors.white.withValues(alpha: 0.7) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: placed == null ? _info.color.withValues(alpha: 0.5) : _info.color,
            width: 3,
          ),
        ),
        child: Text(
          placed ?? ghost ?? '',
          key: ghost != null ? ValueKey('ghost_$i') : null,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: ghost != null ? _ink.withValues(alpha: 0.25) : _ink,
          ),
        ),
      ),
    );
  }

  /// A word that is already in place (the verb, or 공부 before 안).
  Widget _fixedChip(String text, {Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.center,
    decoration: _info.fill(borderRadius: BorderRadius.circular(14)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
    ),
  );
}
