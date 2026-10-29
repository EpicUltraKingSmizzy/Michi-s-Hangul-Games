part of '../game_screen.dart';

/// 🕒 What Time Is It?
extension _TimeGame on _GameScreenState {
  /// 🕒 tile tapped: into the first empty slot, then check.
  Future<void> _onTimeTile(TimeRound r, int tile) async {
    final slots = _slots;
    if (_locked || slots == null || slots.place(tile) < 0) return;
    _update(() {});
    final syllable = r.tiles[tile];
    final done = isTimeBuilt(r, slots.text);
    if (shouldSpeakSyllable(
      syllable,
      winsNow: done && (!r.showSky || _period == r.period),
      spokenAnswer: appState.spokenAnswer,
    )) {
      unawaited(Speaker.instance.speak(syllable));
    }
    await _checkTime(r);
  }

  /// 🕒 오전 / 오후 tapped.
  Future<void> _onPeriod(TimeRound r, String p) async {
    if (_locked) return;
    _update(() => _period = p);
    await _checkTime(r);
  }

  /// Wins when the syllables say the time (반 counts for :30, which needs
  /// fewer slots) and, in sky rounds, the right 오전 / 오후 is picked.
  /// Full slots that are wrong, or a wrong 오전 / 오후 once the syllables
  /// are right, are a miss.
  Future<void> _checkTime(TimeRound r) async {
    final slots = _slots!;
    final built = isTimeBuilt(r, slots.text);
    final id = _roundId;
    if (built && (!r.showSky || _period == r.period)) {
      _update(() => _fieldFlash = _green);
      await _win(entered: slots.text);
      return;
    }
    final wrongPeriod = built && _period != null && _period != r.period;
    if (!wrongPeriod && (built || !slots.isFull)) return;
    _miss();
    _update(() {
      _fieldFlash = _red;
      _shake++;
      if (wrongPeriod) _period = null;
    });
    await _delay();
    if (mounted && id == _roundId) _update(() => _fieldFlash = null);
  }

  /// 🕒: the clock (always), the digital time (⚙️ ⌚ Digital time), the
  /// sky window with 오전 / 오후 in some rounds, then slots and tiles.
  /// Slots come in word groups (세 시 | 십오 분), so spaces are never tiles.
  List<Widget> _timeBody(TimeRound r) {
    final slots = _slots!;
    final groups = [for (final w in r.words) w.length];
    return [
      const SizedBox(height: 10),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CartoonClock(
              key: const ValueKey('time_clock'),
              hour: r.hour12,
              minute: r.minute,
              color: _info.color,
              size: r.showSky ? 160 : 200,
            ),
            if (r.showSky) ...[
              const SizedBox(width: 14),
              SkyWindow(key: const ValueKey('time_sky'), scene: r.scene!),
            ],
          ],
        ),
      ),
      if (appState.showDigitalTime)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: Text(
              r.digital,
              key: const ValueKey('time_digital'),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
        ),
      if (r.showSky) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final p in const ['오전', '오후']) ...[
              BouncyButton(
                key: ValueKey('period_$p'),
                color: _period == p ? _info.color : const Color(0xFF6B4E8C),
                borderColor: _period == p
                    ? _ink
                    : (_hintVisible && p == r.period ? _ink.withValues(alpha: 0.35) : null),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                onTap: () => _onPeriod(r, p),
                child: Text(p, style: TextStyle(fontSize: _bf)),
              ),
              if (p == '오전') const SizedBox(width: 18),
            ],
          ],
        ),
      ],
      const SizedBox(height: 16),
      Shaker(
        trigger: _shake,
        child: SlotLine(
          key: const ValueKey('time_slots'),
          groups: groups,
          slot: (i) => _slotBox(i, slots, 46),
        ),
      ),
      const SizedBox(height: 16),
      _timeTiles(r.tiles, slots, (i) => _onTimeTile(r, i)),
      const SizedBox(height: 18),
      _controlRow(_toggleHint),
    ];
  }
}
