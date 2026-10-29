part of '../game_screen.dart';

/// 🎨 Color match.
extension _ColorGame on _GameScreenState {
  Future<void> _onColor(ColorRound r, int i) async {
    if (_locked) return;
    if (r.options[i].id == r.target.id) {
      _update(() => _optionColors[i] = _green);
      await _win();
    } else {
      _miss();
      _update(() {
        _optionColors[i] = _red;
        _shake++;
        _cheer = pick(oopsCheers, _rand);
        _cheerId++;
      });
    }
  }


  /// 9️⃣: either a box painted in the colour with Korean-name buttons, or a
  /// Korean name with colour buttons. No English or emoji in the round itself,
  /// except the English a tap on the colour box peeks at. The colour buttons
  /// are answers (a tap answers), just like emoji answer buttons.
  List<Widget> _colorBody(ColorRound r) => [
    if (r.colorInBox) _colorBox(r.target) else _promptCard(r.answer, true),
    const SizedBox(height: 16),
    for (var i = 0; i < r.options.length; i++)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Shaker(
                trigger: _optionColors[i] == _red ? _shake : 0,
                child: r.colorInBox
                    ? BouncyButton(
                        key: ValueKey('color_option_$i'),
                        // Neutral buttons: a coloured button would give the answer away.
                        color: _optionColors[i] ?? _ink,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        onTap: () => _onColor(r, i),
                        child: FitText(
                          r.nameOf(r.options[i]),
                          key: ValueKey('option_text_$i'),
                          base: _bf,
                          min: 12,
                          maxLines: 2,
                          style: const TextStyle(),
                        ),
                      )
                    : _colorButton(r, i),
              ),
            ),
            if (r.colorInBox) SpeakButton(text: () => r.nameOf(r.options[i])),
          ],
        ),
      ),
    const SizedBox(height: 18),
    _controlRow(null),
  ];

  /// The colour prompt; a tap peeks at its English name (like an emoji
  /// prompt), which never affects wins or the streak.
  Widget _colorBox(GameColor c) => ColorPeek(
    color: Color(c.argb),
    english: appState.displayEnglish(c.english),
    darkText: c.wantsDarkText,
    outlined: c.isLight,
    showEnglish: _peek,
    onTap: () => _update(() => _peek = !_peek),
  );

  /// A solid colour button; a ✓ / ✗ mark (icons, not text) shows the result
  /// without hiding the colour.
  Widget _colorButton(ColorRound r, int i) {
    final c = r.options[i];
    final state = _optionColors[i];
    return BouncyButton(
      key: ValueKey('color_option_$i'),
      color: Color(c.argb),
      borderColor: c.isLight ? Colors.black38 : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onTap: () => _onColor(r, i),
      child: SizedBox(
        height: 48,
        child: state == null
            ? null
            : Center(
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(
                    state == _green ? Icons.check_rounded : Icons.close_rounded,
                    color: state,
                    size: 34,
                  ),
                ),
              ),
      ),
    );
  }
}
