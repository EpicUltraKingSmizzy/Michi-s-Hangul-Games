import 'dart:math';

import 'package:flutter/material.dart';

/// Largest font size (≤ [base], ≥ [min]) at which [text] fits [maxWidth]
/// without breaking a word and in at most [maxLines] lines.
double fitFontSize(
  String text,
  TextStyle style,
  double maxWidth, {
  required double base,
  double min = 14,
  int maxLines = 3,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  for (var size = base; size > min; size -= 2) {
    final s = style.copyWith(fontSize: size);
    final wordsFit = words.every((w) {
      final tp = TextPainter(
        text: TextSpan(text: w, style: s),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return tp.width <= maxWidth;
    });
    if (!wordsFit) continue;
    final tp = TextPainter(
      text: TextSpan(text: text, style: s),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    if (!tp.didExceedMaxLines) return size;
  }
  return min;
}

/// Starting size for the English side, by length (same steps as the prompt).
double baseSizeFor(String text) {
  final len = text.characters.length;
  return len <= 4 ? 60.0 : (len <= 10 ? 44.0 : (len <= 20 ? 32.0 : 24.0));
}

/// An emoji prompt that flips to its English word when tapped (and back on
/// the next tap). Purely a peek: it never touches the round's result.
class EmojiPeek extends StatelessWidget {
  final String emoji;
  final String english;
  final bool showEnglish;
  final VoidCallback onTap;
  final double emojiSize;
  final Color color;
  const EmojiPeek({
    super.key,
    required this.emoji,
    required this.english,
    required this.showEnglish,
    required this.onTap,
    required this.emojiSize,
    required this.color,
  });

  static const duration = Duration(milliseconds: 320);

  /// The flip-in used by every peek (emoji prompt and 9️⃣'s colour box).
  static Widget flip(Widget child, Animation<double> anim) => AnimatedBuilder(
    animation: anim,
    child: child,
    builder: (context, child) {
      final v = anim.value;
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX((1 - v) * pi / 2),
          child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: FontWeight.w900, color: color);
    return GestureDetector(
      key: const ValueKey('prompt_peek'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        hint: showEnglish ? 'Tap to show the emoji' : 'Tap to show the English word',
        // A hidden copy of the emoji keeps the card at least emoji-tall, so the
        // answers below don't jump when a short English word is showing.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(emoji, style: style.copyWith(fontSize: emojiSize)),
            ),
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: flip,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.center, children: [...previous, ?current]),
              child: showEnglish
                  ? LayoutBuilder(
                      key: const ValueKey('peek_english'),
                      builder: (context, c) {
                        final scaler = MediaQuery.textScalerOf(context);
                        final size = fitFontSize(
                          english,
                          style,
                          c.maxWidth,
                          base: baseSizeFor(english),
                          textScaler: scaler,
                        );
                        return SizedBox(
                          width: c.maxWidth,
                          child: Text(
                            english,
                            key: const ValueKey('peek_english_text'),
                            textAlign: TextAlign.center,
                            style: style.copyWith(fontSize: size),
                          ),
                        );
                      },
                    )
                  : Text(
                      emoji,
                      key: const ValueKey('peek_emoji'),
                      textAlign: TextAlign.center,
                      style: style.copyWith(fontSize: emojiSize),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 9️⃣'s colour box: tapping it flips the colour's English name onto the box
/// (and off again on the next tap), like [EmojiPeek]. The box keeps its look;
/// the text is black or white, whichever reads better on the colour. Purely
/// a peek: it never touches the round's result.
class ColorPeek extends StatelessWidget {
  final Color color;
  final String english;
  final bool darkText;
  final bool outlined;
  final bool showEnglish;
  final VoidCallback onTap;
  const ColorPeek({
    super.key,
    required this.color,
    required this.english,
    required this.darkText,
    required this.outlined,
    required this.showEnglish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('color_box_peek'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Semantics(
      button: true,
      hint: showEnglish ? 'Tap to hide the English name' : 'Tap to show the English name',
      child: Container(
        key: const ValueKey('color_box'),
        height: 150,
        margin: const EdgeInsets.only(top: 34, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: outlined ? Border.all(color: Colors.black38, width: 1.5) : null,
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 5)),
          ],
        ),
        child: AnimatedSwitcher(
          duration: EmojiPeek.duration,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: EmojiPeek.flip,
          child: showEnglish
              ? FitText(
                  english,
                  key: const ValueKey('color_box_english'),
                  base: baseSizeFor(english),
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: darkText ? Colors.black : Colors.white,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('color_box_blank')),
        ),
      ),
    ),
  );
}

/// Text that starts at [base] and shrinks (down to [min]) until every word
/// fits the width and the whole text fits in [maxLines] lines.
class FitText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double base;
  final double min;
  final int maxLines;
  final TextAlign textAlign;
  const FitText(
    this.text, {
    super.key,
    required this.style,
    required this.base,
    this.min = 14,
    this.maxLines = 3,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // Measure with what will really be drawn (inherited weight/family too).
      final full = DefaultTextStyle.of(context).style.merge(style);
      final size = c.maxWidth.isFinite
          ? fitFontSize(
              text,
              full,
              c.maxWidth,
              base: base,
              min: min,
              maxLines: maxLines,
              textScaler: MediaQuery.textScalerOf(context),
            )
          : base;
      return Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(fontSize: size),
      );
    },
  );
}
