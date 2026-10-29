import 'package:flutter/material.dart';

import '../logic/link_game.dart';
import 'common.dart';
import 'emoji_peek.dart';

/// One card on a Link Up board: the Korean column ([left]) or the
/// emoji/English column, and its row.
typedef LinkSpot = ({bool left, int row});

/// Colours for locked-in lines, in the order they are made (never red: red
/// means a wrong line).
const linkPairColors = [
  Color(0xFF7B5CFF), // purple
  Color(0xFF00A6E8), // blue
  Color(0xFFFF8A00), // orange
  Color(0xFF14B8A6), // teal
  Color(0xFFE040FB), // magenta
  Color(0xFF2FAE5B), // green
];

const linkWrongColor = Color(0xFFFF4D4D);
const _ink = Color(0xFF3A1D5C);

/// Where the cards sit on a board [size] big: two columns of
/// [LinkRound.size] cards with a gap in the middle for the lines.
class LinkGeometry {
  final Size size;
  static const gap = 10.0;
  static const middle = 56.0;
  const LinkGeometry(this.size);

  double get cardHeight => (size.height - gap * (LinkRound.size - 1)) / LinkRound.size;
  double get columnWidth => (size.width - middle) / 2;

  Rect card(LinkSpot s) => Rect.fromLTWH(
    s.left ? 0 : size.width - columnWidth,
    s.row * (cardHeight + gap),
    columnWidth,
    cardHeight,
  );

  /// Where a line meets a card: the inner edge, halfway down.
  Offset anchor(LinkSpot s) {
    final r = card(s);
    return s.left ? r.centerRight : r.centerLeft;
  }

  /// The card under [p]: its half of the board and its row (the gaps between
  /// cards count too, so a sloppy finger still lands).
  LinkSpot? hit(Offset p) {
    if (p.dx < 0 || p.dx > size.width || p.dy < 0 || p.dy > size.height) return null;
    final row = ((p.dy + gap / 2) / (cardHeight + gap)).floor().clamp(0, LinkRound.size - 1);
    return (left: p.dx < size.width / 2, row: row);
  }
}

/// A line to paint from [a] to [b].
class LinkLine {
  final Offset a, b;
  final Color color;
  final bool dashed;
  const LinkLine(this.a, this.b, this.color, {this.dashed = false});
}

class _LinePainter extends CustomPainter {
  final List<LinkLine> lines;
  _LinePainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final paint = Paint()
        ..color = l.color
        ..strokeWidth = l.dashed ? 5 : 7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(l.a, l.b, paint);
      final dot = Paint()..color = l.color;
      canvas.drawCircle(l.a, 7, dot);
      canvas.drawCircle(l.b, 7, dot);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

/// The Link Up board: Korean cards on the left, emoji/English on the right,
/// locked lines in their colours, the line being drawn, and a red wrong line.
/// Pointer events come back as cards ([LinkSpot]) via the callbacks; all
/// game logic lives with the caller.
class LinkBoardView extends StatelessWidget {
  final LinkRound round;

  /// Card text size (⚙️ 🔠 Button Font Size); emoji cards stay 32.
  final double textSize;
  final LinkBoard board;
  final Color theme;

  /// Card picked with a tap, waiting for its partner.
  final LinkSpot? selected;

  /// The card a line is being dragged from, and where the finger is.
  final LinkSpot? dragFrom;
  final Offset? dragTo;

  /// (left row, right slot) of a wrong line, shown red for a moment.
  final (int, int)? wrong;
  final int shake;

  final void Function(LinkSpot? spot, Offset at) onDown;
  final void Function(Offset at) onMove;
  final void Function(LinkSpot? spot, Offset at) onUp;

  const LinkBoardView({
    super.key,
    required this.round,
    this.textSize = 22,
    required this.board,
    required this.theme,
    required this.selected,
    required this.dragFrom,
    required this.dragTo,
    required this.wrong,
    required this.shake,
    required this.onDown,
    required this.onMove,
    required this.onUp,
  });

  Color? _lockedColor(LinkSpot s) {
    final left = s.left
        ? s.row
        : board.locked.entries.where((e) => e.value == s.row).firstOrNull?.key;
    final order = left == null ? null : board.lockOrder(left);
    return order == null ? null : linkPairColors[order % linkPairColors.length];
  }

  bool _isWrong(LinkSpot s) => wrong != null && (s.left ? wrong!.$1 : wrong!.$2) == s.row;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final geo = LinkGeometry(Size(box.maxWidth, box.maxHeight));
      final lines = <LinkLine>[
        for (final e in board.locked.entries)
          LinkLine(
            geo.anchor((left: true, row: e.key)),
            geo.anchor((left: false, row: e.value)),
            _lockedColor((left: true, row: e.key))!,
          ),
        if (wrong case (final l, final r))
          LinkLine(
            geo.anchor((left: true, row: l)),
            geo.anchor((left: false, row: r)),
            linkWrongColor,
          ),
        if (dragFrom != null && dragTo != null)
          LinkLine(geo.anchor(dragFrom!), dragTo!, theme.withValues(alpha: 0.8), dashed: true),
      ];
      return Listener(
        key: const ValueKey('link_board'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => onDown(geo.hit(e.localPosition), e.localPosition),
        onPointerMove: (e) => onMove(e.localPosition),
        onPointerUp: (e) => onUp(geo.hit(e.localPosition), e.localPosition),
        child: Stack(
          children: [
            for (final left in [true, false])
              for (var row = 0; row < round.pairs.length; row++)
                Positioned.fromRect(
                  rect: geo.card((left: left, row: row)),
                  child: _card((left: left, row: row)),
                ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _LinePainter(lines))),
            ),
          ],
        ),
      );
    },
  );

  Widget _card(LinkSpot s) {
    final text = s.left ? round.leftText(s.row) : round.rightText(s.row);
    final locked = _lockedColor(s);
    final isWrong = _isWrong(s);
    final picked = !isWrong && locked == null && (s == selected || s == dragFrom);
    final accent = isWrong ? linkWrongColor : locked ?? (picked ? theme : null);
    final emojiOnly = !s.left && !RegExp(r'[A-Za-z0-9]').hasMatch(text);
    return Shaker(
      trigger: isWrong ? shake : 0,
      child: AnimatedContainer(
        key: ValueKey('link_${s.left ? 'left' : 'right'}_${s.row}'),
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent == null ? Colors.white : Color.lerp(accent, Colors.white, 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent ?? Color.lerp(theme, Colors.white, 0.35)!,
            width: accent == null ? 2.5 : 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(accent ?? theme, Colors.black, 0.2)!.withValues(alpha: 0.35),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FitText(
          text,
          key: ValueKey('link_text_${s.left ? 'left' : 'right'}_${s.row}'),
          base: emojiOnly ? 32 : textSize,
          min: 11,
          maxLines: 2,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: accent == null || picked ? _ink : Color.lerp(accent, Colors.black, 0.3),
          ),
        ),
      ),
    );
  }
}
