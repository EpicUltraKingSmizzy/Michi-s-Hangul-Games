part of '../game_screen.dart';

/// 🔢 Sino numbers and 🖐️ Native numbers: the on-screen keypad.
extension _NumberGame on _GameScreenState {
  /// Keypad digit (7️⃣/8️⃣ digit rounds).
  Future<void> _onDigit(TypingRound r, String d) async {
    if (_locked || _input.text.length >= 12) return;
    _setInput(_input.text + d);
    if (isHelperAnswerComplete(_input.text, r)) {
      _update(() => _fieldFlash = _green);
      await _win(entered: _input.text);
    } else {
      _update(() {});
    }
  }

  /// 7️⃣/8️⃣ digit rounds: a read-only display (no system keyboard) + keypad.
  List<Widget> _keypadBody(TypingRound r) => [
    Shaker(
      trigger: _shake,
      child: AnimatedContainer(
        key: const ValueKey('digit-display'),
        duration: const Duration(milliseconds: 120),
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _fieldFlash ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _info.color, width: 3),
        ),
        child: Text(
          _input.text,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: _ink,
            letterSpacing: 2,
          ),
        ),
      ),
    ),
    const SizedBox(height: 14),
    NumberKeypad(
      onDigit: (d) => _onDigit(r, d),
      onBackspace: _backspace,
      onSubmit: () => _submit(r),
    ),
  ];
}
