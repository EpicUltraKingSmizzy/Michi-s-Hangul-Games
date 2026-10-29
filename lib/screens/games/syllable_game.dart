part of '../game_screen.dart';

/// 🧩 Syllable scramble and 🌀 Scramble + decoys: tiles into slots.
extension _SyllableGame on _GameScreenState {
  /// Tile tapped (5️⃣/6️⃣): it drops into the first empty slot.
  Future<void> _onTile(TypingRound r, int tile) async {
    final slots = _slots;
    if (_locked || slots == null || slots.place(tile) < 0) return;
    _update(() {});
    final syllable = r.charButtons[tile];
    if (shouldSpeakSyllable(
      syllable,
      winsNow: slots.isFull && isTypedAnswerCorrect(slots.text, r),
      spokenAnswer: appState.spokenAnswer,
    )) {
      unawaited(Speaker.instance.speak(syllable));
    }
    await _checkSlots(r);
  }


  Future<void> _checkSlots(TypingRound r) async {
    final slots = _slots!;
    if (!slots.isFull) return;
    final id = _roundId;
    if (isTypedAnswerCorrect(slots.text, r)) {
      _update(() => _fieldFlash = _green);
      await _win(entered: slots.text);
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

  /// 5️⃣/6️⃣: one box per answer letter, then the tile pile and ⌫.
  List<Widget> _slotBody(TypingRound r, TileSlots slots) {
    final box = slots.length <= 5 ? 58.0 : (slots.length <= 8 ? 46.0 : 38.0);
    return [
      Shaker(
        trigger: _shake,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: [for (var i = 0; i < slots.length; i++) _slotBox(i, slots, box)],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 12,
        children: [
          for (var i = 0; i < r.charButtons.length; i++)
            AnimatedOpacity(
              key: ValueKey('tile_$i'),
              duration: const Duration(milliseconds: 150),
              opacity: slots.isUsed(i) ? 0.2 : 1,
              child: BouncyButton(
                color: _helperPalette[i % _helperPalette.length],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                radius: 16,
                onTap: slots.isUsed(i) ? null : () => _onTile(r, i),
                child: Text(r.charButtons[i], style: TextStyle(fontSize: _bf)),
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
    ];
  }
}
