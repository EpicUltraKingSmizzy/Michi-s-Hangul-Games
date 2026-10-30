import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/speaker.dart';

class GameInfo {
  final String keycap;
  final String subtitle;
  final String emoji;
  final Color color;

  /// Optional tile gradient (diagonal, top-left → bottom-right). When null the
  /// tile is the solid [color]. Remove it to go back to a solid tile.
  final List<Color>? gradient;
  const GameInfo(this.keycap, this.subtitle, this.emoji, this.color, {this.gradient});

  /// The diagonal tile gradient, or null for a solid tile.
  LinearGradient? get linearGradient => gradient == null
      ? null
      : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient!);

  /// [gradient] (or [color]) blended toward [to] by [t]; for edges and tints.
  List<Color> shades(Color to, double t) => [
    for (final c in gradient ?? [color, color]) Color.lerp(c, to, t)!,
  ];

  /// A box filled with this game's theme: the gradient when there is one,
  /// otherwise the solid colour.
  BoxDecoration fill({BorderRadius? borderRadius, List<BoxShadow>? boxShadow}) => BoxDecoration(
    color: gradient == null ? color : null,
    gradient: linearGradient,
    borderRadius: borderRadius,
    boxShadow: boxShadow,
  );

  /// Full tile name, e.g. '🧩 Syllable scramble'. The [keycap] is internal
  /// only and never shown.
  String get tileName => [emoji, subtitle].where((s) => s.isNotEmpty).join(' ');
}

/// Rainbow for 9️⃣ 🎨 Color match, slightly deepened so white text stays readable.
const List<Color> rainbowGradient = [
  Color(0xFFE53950), // red
  Color(0xFFF57C1F), // orange
  Color(0xFFF2B200), // yellow (deepened)
  Color(0xFF34B04A), // green
  Color(0xFF1E88E5), // blue
  Color(0xFF8E44D9), // purple
];

/// Never "Game X" and no keycap numbers on screen: each game is its emoji + name.
const List<GameInfo> gameInfos = [
  GameInfo('1️⃣', 'Pick the meaning', '🔍', Color(0xFFFF5C8A)),
  // 2 was 🎯 Pick the Korean (now a format of 🔍 Pick the meaning).
  GameInfo('2️⃣', 'What Time Is It?', '🕒', Color(0xFF7CB518)),
  GameInfo('3️⃣', 'Typing practice', '✍️', Color(0xFF2EC4B6)),
  GameInfo('4️⃣', 'From memory', '🧠', Color(0xFF7B5CFF)),
  GameInfo('5️⃣', 'Syllable scramble', '🧩', Color(0xFFE040FB)),
  GameInfo('6️⃣', 'Scramble + decoys', '🌀', Color(0xFFFF6B35)),
  GameInfo('7️⃣', 'Sino numbers', '🔢', Color(0xFF3DDC84)),
  GameInfo('8️⃣', 'Native numbers', '🖐️', Color(0xFF00B4FF)),
  // 9️⃣'s solid colour is only a fallback; its theme is the rainbow gradient.
  GameInfo('9️⃣', 'Color match', '🎨', Color(0xFF1E88E5), gradient: rainbowGradient),
  GameInfo('🔟', 'Link Up', '🔗', Color(0xFFFF9F1C)),
  GameInfo('1️⃣1️⃣', 'Sentence Builder', '🧱', Color(0xFF9C6644)),
];

/// Games in 📊 Stats and 🔀 Shuffle games order.
const List<int> gameOrder = [1, 9, 3, 4, 5, 6, 11, 7, 8, 2, 10];

/// Home tiles (rows of two): 🧩 Syllable scramble's tile also opens
/// 🌀 Scramble + decoys (see [scrambleTile]).
const List<int> homeTileOrder = [1, 9, 3, 4, 5, 11, 7, 8, 2, 10];

/// The home tile 🧩 and 🌀 share: it keeps 🧩's look and offers both.
const int scrambleTile = 5;
const List<int> scrambleTileGames = [5, 6];

/// The last home tile: a random game after every win.
const GameInfo shuffleInfo = GameInfo('', 'Shuffle', '🔀', Color(0xFF3F51B5));

const winCheers = [
  '대박! 🎉',
  '최고! 🌟',
  'Nailed it! 🥳',
  '잘했어요! 💯',
  'Woohoo! 🚀',
  '짱! 🐯',
  'Boom! 💥',
  '천재! 🤓',
];

/// One right line on a Link Up board (the full board gets [winCheers]).
const linkCheers = ['Linked! 🔗', 'Zap! ⚡', 'Snap! 👌', 'Click! ✨', 'Yesss! 🙌'];
const oopsCheers = ['Oops! 🙈', '아이고! 😵', 'Nope! 🙃', 'So close! 🤏'];
String pick(List<String> l, [Random? r]) => l[(r ?? Random()).nextInt(l.length)];

/// System bars over our light backgrounds: transparent, with dark icons
/// (clock, notifications, battery). statusBarBrightness is the iOS spelling.
const lightBackgroundOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

class FunBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  const FunBackground({super.key, required this.child, this.colors});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // Every screen sits on this light gradient, so ask for dark status-bar icons.
    value: lightBackgroundOverlay,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? const [Color(0xFFFFF0F6), Color(0xFFFFF8E1), Color(0xFFE8F8FF)],
        ),
      ),
      child: child,
    ),
  );
}

/// A rounded box with a [width] border in a game's theme: a solid border, or
/// for a gradient game (9️⃣ rainbow) a gradient ring around the inside fill.
class ThemedBorderBox extends StatelessWidget {
  final GameInfo info;
  final double width;
  final double radius;
  final Color? fillColor;
  final Gradient? fillGradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final Widget child;
  const ThemedBorderBox({
    super.key,
    required this.info,
    required this.child,
    this.width = 3,
    this.radius = 16,
    this.fillColor,
    this.fillGradient,
    this.padding,
    this.margin,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    if (info.gradient == null) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: fillColor,
          gradient: fillGradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: info.color, width: width),
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }
    return Container(
      margin: margin,
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(
        gradient: info.linearGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: boxShadow,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fillColor,
          gradient: fillGradient,
          borderRadius: BorderRadius.circular(max(0, radius - width)),
        ),
        child: child,
      ),
    );
  }
}

/// A chunky button that squishes when pressed.
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;

  /// Optional fill gradient colors (diagonal). The edge and drop shadow use a
  /// darker copy of the same gradient.
  final List<Color>? gradient;
  const BouncyButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.radius = 22,
    this.borderColor,
    this.gradient,
  });
  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final darker = Color.lerp(widget.color, Colors.black, 0.25)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.gradient != null
            ? _gradientFace(widget.gradient!)
            : AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(color: widget.borderColor ?? darker, width: 3),
                  boxShadow: [BoxShadow(color: darker, offset: Offset(0, _down ? 1 : 5))],
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  child: widget.child,
                ),
              ),
      ),
    );
  }

  /// Same shape as the solid face: a 3px darker edge plus a darker drop
  /// "shadow" under it, both drawn as a darker copy of the gradient.
  Widget _gradientFace(List<Color> colors) {
    const begin = Alignment.topLeft, end = Alignment.bottomRight;
    final dark = [for (final c in colors) Color.lerp(c, Colors.black, 0.3)!];
    final r = widget.radius;
    final drop = _down ? 1.0 : 5.0;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: drop,
          bottom: -drop,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: LinearGradient(colors: dark, begin: begin, end: end),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: LinearGradient(colors: dark, begin: begin, end: end),
          ),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r - 3),
              gradient: LinearGradient(colors: colors, begin: begin, end: end),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 3)],
              ),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reads [text] aloud (a newer call cuts off the previous one). Shows a hint
/// if no Korean voice is installed.
Future<void> speakKorean(BuildContext context, String text) async {
  final t = text.trim();
  if (t.isEmpty) return;
  final ok = await Speaker.instance.speak(t);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🔇 No Korean voice found. Install it in Settings → Text-to-speech → '
          'Speech Services by Google → Install voice data → Korean.',
        ),
      ),
    );
  }
}

/// 🔊 button that reads Korean text aloud with on-device TTS.
class SpeakButton extends StatelessWidget {
  final String Function() text;
  final double size;

  /// false: shown greyed out and does nothing.
  final bool enabled;
  const SpeakButton({super.key, required this.text, this.size = 30, this.enabled = true});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Read aloud',
    iconSize: size,
    onPressed: enabled ? () => speakKorean(context, text()) : null,
    icon: Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Text('🔊', style: TextStyle(fontSize: size * 0.8)),
    ),
  );
}

/// A gentle shake used for wrong answers.
class Shaker extends StatefulWidget {
  final Widget child;
  final int trigger; // change this to shake
  const Shaker({super.key, required this.child, required this.trigger});
  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  @override
  void didUpdateWidget(Shaker old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(sin(_c.value * pi * 6) * 10 * (1 - _c.value), 0),
      child: child,
    ),
    child: widget.child,
  );
}

/// "0 words in play", "1 word in play", "566 words in play".
String wordsInPlay(int n) => '$n ${n == 1 ? 'word' : 'words'} in play';
