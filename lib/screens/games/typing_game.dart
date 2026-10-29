part of '../game_screen.dart';

/// ✍️ Typing practice and 🧠 From memory: type the answer.
extension _TypingGame on _GameScreenState {
  Future<void> _submit(TypingRound r) async {
    if (_locked) return;
    final id = _roundId;
    final entered = _input.text;
    if (isTypedAnswerCorrect(entered, r)) {
      _update(() => _fieldFlash = _green);
      if (r.repetitions == 1 || _reps + 1 == r.repetitions) {
        if (r.repetitions > 1) _update(() => _reps++);
        await _win(entered: entered);
        return;
      }
      // 3️⃣ repetition: buzz + speak, but don't hold up the next attempt.
      _update(() => _locked = true);
      if (appState.vibration) Buzz.right();
      if (appState.spokenAnswer) {
        unawaited(Speaker.instance.speak(_spokenAnswer(r, entered: entered)));
      }
      await _delay();
      if (!mounted || id != _roundId) return;
      _update(() {
        _reps++;
        _fieldFlash = null;
        _locked = false;
        _input.value = TextEditingValue.empty;
        _hintVisible = false;
      });
      _focus.requestFocus();
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

  /// Typed rounds check every text change, so a right answer wins without ✔.
  /// Partial or wrong text is never marked wrong here; only ✔ / Enter does that.
  void _onTyped(TypingRound r) {
    if (_locked || !isTypedAnswerCorrect(_input.text, r)) return;
    _endComposition();
    _submit(r);
  }

  /// Commit Gboard's in-progress syllable (the composing region) without
  /// changing the text, in one atomic value update, so the IME finishes its
  /// composition cleanly before the field is locked / cleared.
  void _endComposition() {
    final v = _input.value;
    if (!v.composing.isValid || v.composing.isCollapsed) return;
    _input.value = TextEditingValue(
      text: v.text,
      selection: TextSelection.collapsed(offset: v.text.length),
    );
  }

  Widget _textFieldRow(TypingRound r) => Shaker(
    trigger: _shake,
    child: Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _fieldFlash ?? Colors.white,
            ),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              autofocus: true,
              // Never toggle readOnly (that closes/reopens the IME connection) and
              // never set enableSuggestions:false: on Android the Flutter engine
              // maps it to TYPE_TEXT_VARIATION_VISIBLE_PASSWORD, which makes
              // Gboard refuse to switch to its Korean layout.
              textInputAction: TextInputAction.done,
              keyboardType: RegExp(r'^[0-9]+$').hasMatch(r.answer1)
                  ? TextInputType.number
                  : TextInputType.text,
              autocorrect: false,
              enableSuggestions: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink),
              decoration: InputDecoration(
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _info.color, width: 3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _info.color, width: 4),
                ),
              ),
              onEditingComplete: () {}, // keep the keyboard open
              onChanged: (_) {
                _dismissTypingTip();
                _onTyped(r);
              },
              onSubmitted: (_) {
                _endComposition();
                _submit(r);
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        BouncyButton(
          color: _green,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: () {
            _endComposition();
            _submit(r);
          },
          child: const Text('✔', style: TextStyle(fontSize: 26)),
        ),
      ],
    ),
  );

  /// 3️⃣: the green bar fills per correct repetition; 'x / 5' sits centred
  /// inside it (dark ink reads on both the green and the grey part).
  Widget _progress(TypingRound r) {
    final frac = _reps / r.repetitions;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ClipRRect(
        key: const ValueKey('reps_bar'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 32,
          color: const Color(0xFFDDDDDD),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: frac,
                  heightFactor: 1,
                  child: Container(color: _green),
                ),
              ),
              Center(
                child: Text(
                  '$_reps / ${r.repetitions}',
                  key: const ValueKey('reps_label'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    shadows: [Shadow(color: Color(0x88FFFFFF), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Only when ✍️ Typing practice is opened directly, never in 🔀 Shuffle.
  bool get _showTypingTip => !widget.shuffle && _game == 3 && !_typingTipDismissed;

  void _dismissTypingTip() {
    if (_showTypingTip) _update(() => _typingTipDismissed = true);
  }

  Widget _typingTip() => const Padding(
    key: ValueKey('typing_tip'),
    padding: EdgeInsets.fromLTRB(8, 14, 8, 0),
    child: Text(
      'Tip: Use voice-to-text on your phone keyboard to turn this into speaking practice. '
      'I use Gboard with the Korean language installed.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF8A7A9E)),
    ),
  );
}
