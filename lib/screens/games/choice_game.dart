part of '../game_screen.dart';

/// 🔍 Pick the meaning: tap the answer.
extension _ChoiceGame on _GameScreenState {
  Future<void> _onOption(ChoiceRound r, int i) async {
    if (_locked) return;
    if (r.options[i] == r.correctAnswer) {
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

  List<Widget> _choice(ChoiceRound r) => [
    _promptCard(r.prompt, r.promptIsKorean, english: r.promptEnglish),
    const SizedBox(height: 16),
    for (var i = 0; i < r.options.length; i++)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Shaker(
                trigger: _optionColors[i] == _red ? _shake : 0,
                child: BouncyButton(
                  color: _optionColors[i] ?? _optionPalette[i % _optionPalette.length],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  onTap: () => _onOption(r, i),
                  child: r.optionsAreKorean
                      ? FitText(
                          r.options[i],
                          key: ValueKey('option_text_$i'),
                          base: _bf,
                          min: 12,
                          maxLines: 2,
                          style: const TextStyle(),
                        )
                      // 1️⃣ English/emoji answers: one line, shrunk to fit,
                      // so the buttons keep the emoji buttons' height.
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Visibility(
                              visible: false,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: Text('A', style: TextStyle(fontSize: _bf)),
                            ),
                            FitText(
                              r.options[i],
                              key: ValueKey('option_text_$i'),
                              base: _bf,
                              min: 12,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            if (r.optionsAreKorean) SpeakButton(text: () => r.options[i]),
          ],
        ),
      ),
    const SizedBox(height: 18),
    _controlRow(null),
  ];
}
