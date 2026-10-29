part of '../game_screen.dart';

/// 🔗 Link Up: draw a line between each pair.
extension _LinkUpGame on _GameScreenState {
  bool _spotLocked(LinkSpot s) => s.left ? _links!.leftLocked(s.row) : _links!.rightLocked(s.row);

  void _linkDown(LinkSpot? s, Offset at) {
    if (_locked || _links == null || s == null || _spotLocked(s)) return;
    _update(() {
      _dragFrom = s;
      _dragTo = at;
    });
  }

  void _linkMove(Offset at) {
    if (_dragFrom != null) _update(() => _dragTo = at);
  }

  /// A line dropped on a card in the other column links the two (dragging
  /// works either way). Lifting on the same card is a tap: it picks the card,
  /// and a tap on a card in the other column links it to the picked one.
  void _linkUp(LinkSpot? s, Offset at) {
    final from = _dragFrom;
    if (from == null) return;
    _update(() {
      _dragFrom = null;
      _dragTo = null;
    });
    if (_locked || s == null) return;
    if (s.left != from.left) {
      _update(() => _linkPick = null);
      _tryLink(from, s);
    } else if (s == from) {
      final pick = _linkPick;
      if (pick != null && pick.left != s.left) {
        _update(() => _linkPick = null);
        _tryLink(pick, s);
      } else {
        _update(() => _linkPick = pick == s ? null : s);
      }
    }
  }

  /// A right line locks in (in its own colour; the Korean is read aloud);
  /// the sixth one wins the board. A wrong line flashes red for a second,
  /// buzzes and disappears, and breaks the streak like any wrong answer.
  Future<void> _tryLink(LinkSpot a, LinkSpot b) async {
    final r = _round;
    final board = _links;
    if (r is! LinkRound || board == null || _locked) return;
    final left = a.left ? a.row : b.row;
    final right = a.left ? b.row : a.row;
    switch (board.tryLink(left, right)) {
      case LinkResult.ignored:
        return;
      case LinkResult.wrong:
        _miss();
        _wrongTimer?.cancel();
        _update(() {
          _wrongLine = (left, right);
          _shake++;
          _cheer = pick(oopsCheers, _rand);
          _cheerId++;
        });
        final id = _roundId;
        _wrongTimer = Timer(LinkRound.wrongFlash, () {
          if (mounted && id == _roundId) _update(() => _wrongLine = null);
        });
      case LinkResult.linked:
        final korean = r.leftText(left);
        if (_wrongLine case (final l, final rr) when l == left || rr == right) {
          _wrongTimer?.cancel();
          _wrongLine = null;
        }
        if (board.complete) {
          _update(() {});
          await _win(entered: korean);
          return;
        }
        if (appState.vibration) Buzz.right();
        if (appState.spokenAnswer) unawaited(Speaker.instance.speak(korean));
        _update(() {
          _cheer = pick(linkCheers, _rand);
          _cheerId++;
        });
    }
  }


  /// Link Up: no scrolling here, so a line can be drawn in any direction.
  Widget _linkBody(LinkRound r) {
    final board = _links!;
    return Padding(
      key: ValueKey(_roundId),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Column(
        children: [
          if (widget.shuffle) _shuffleBanner(),
          const SizedBox(height: 6),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Draw a line to link each pair! ✏️',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 540),
                child: LinkBoardView(
                  round: r,
                  textSize: _bf,
                  board: board,
                  theme: _info.color,
                  selected: _linkPick,
                  dragFrom: _dragFrom,
                  dragTo: _dragTo,
                  wrong: _wrongLine,
                  shake: _shake,
                  onDown: _linkDown,
                  onMove: _linkMove,
                  onUp: _linkUp,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _controlRow(null),
        ],
      ),
    );
  }
}
