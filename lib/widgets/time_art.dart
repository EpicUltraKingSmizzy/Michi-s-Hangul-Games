import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/time_game.dart';

/// 🕒: a cartoon analog clock (tick marks, hour and minute hands).
class CartoonClock extends StatelessWidget {
  final int hour, minute;
  final Color color;
  final double size;
  const CartoonClock({
    super.key,
    required this.hour,
    required this.minute,
    required this.color,
    this.size = 190,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: ClockPainter(hour % 12, minute, color)),
  );
}

class ClockPainter extends CustomPainter {
  final int hour, minute;
  final Color color;
  ClockPainter(this.hour, this.minute, this.color);

  /// Hand angles in radians, clockwise from 12 o'clock.
  static double hourAngle(int h, int m) => (h % 12 + m / 60) / 12 * 2 * pi;
  static double minuteAngle(int m) => m / 60 * 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c + const Offset(0, 5), r - 4, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(c, r - 4, Paint()..color = color);
    canvas.drawCircle(c, r - 14, Paint()..color = Colors.white);
    final ink = Paint()
      ..color = const Color(0xFF3A1D5C)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * pi;
      final big = i % 5 == 0;
      final d = Offset(sin(a), -cos(a));
      canvas.drawLine(
        c + d * (r - 20),
        c + d * (r - (big ? 34 : 25)),
        ink..strokeWidth = big ? 5 : 2,
      );
    }
    void hand(double a, double len, double w, Color col) => canvas.drawLine(
      c,
      c + Offset(sin(a), -cos(a)) * len,
      Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    hand(hourAngle(hour, minute), r * 0.45, 10, const Color(0xFF3A1D5C));
    hand(minuteAngle(minute), r * 0.68, 6, color);
    canvas.drawCircle(c, 9, Paint()..color = const Color(0xFF3A1D5C));
  }

  @override
  bool shouldRepaint(ClockPainter old) =>
      old.hour != hour || old.minute != minute || old.color != color;
}

/// 🕒: the AM/PM sky window (morning sun low left, afternoon sun high right,
/// night moon and stars).
class SkyWindow extends StatelessWidget {
  final SkyScene scene;
  final double width, height;
  const SkyWindow({super.key, required this.scene, this.width = 150, this.height = 110});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF8D5A3B), width: 6),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(painter: SkyPainter(scene)),
    ),
  );
}

class SkyPainter extends CustomPainter {
  final SkyScene scene;
  SkyPainter(this.scene);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final sky = switch (scene) {
      SkyScene.morning => [const Color(0xFFFFC6A5), const Color(0xFFBFE3FF)],
      SkyScene.afternoon => [const Color(0xFF2E9BFF), const Color(0xFF8ED1FF)],
      SkyScene.night => [const Color(0xFF0B1340), const Color(0xFF2A2F6B)],
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: scene == SkyScene.morning ? sky.reversed.toList() : sky,
        ).createShader(rect),
    );
    final w = s.width, h = s.height;
    switch (scene) {
      case SkyScene.morning:
        canvas.drawCircle(
          Offset(w * 0.22, h * 0.78),
          h * 0.2,
          Paint()..color = const Color(0xFFFFB300),
        );
      case SkyScene.afternoon:
        canvas.drawCircle(
          Offset(w * 0.78, h * 0.25),
          h * 0.17,
          Paint()..color = const Color(0xFFFFE135),
        );
      case SkyScene.night:
        final star = Paint()..color = Colors.white;
        for (final p in const [
          (0.12, 0.2),
          (0.35, 0.12),
          (0.5, 0.35),
          (0.15, 0.6),
          (0.62, 0.15),
          (0.9, 0.5),
        ]) {
          canvas.drawCircle(Offset(w * p.$1, h * p.$2), 1.8, star);
        }
        final moon = Offset(w * 0.75, h * 0.3);
        canvas.drawCircle(moon, h * 0.16, Paint()..color = const Color(0xFFFFF3B0));
        canvas.drawCircle(
          moon + Offset(h * 0.08, -h * 0.05),
          h * 0.14,
          Paint()..color = const Color(0xFF14194D),
        );
    }
    final cloud = Paint()
      ..color = scene == SkyScene.night ? const Color(0x88B0B8D8) : const Color(0xEEFFFFFF);
    void puff(double x, double y, double r) {
      canvas.drawCircle(Offset(w * x, h * y), h * r, cloud);
      canvas.drawCircle(Offset(w * x + h * r, h * y + h * r * 0.2), h * r * 0.8, cloud);
      canvas.drawCircle(Offset(w * x - h * r, h * y + h * r * 0.25), h * r * 0.7, cloud);
    }

    puff(0.6, 0.62, 0.1);
    puff(0.3, 0.3, 0.08);
    if (scene == SkyScene.afternoon) puff(0.85, 0.75, 0.07);
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.scene != scene;
}

/// 🕒 answer slots on one line, in word groups (세 시 | 십오 분). Shrinks
/// to the width on small phones instead of wrapping.
class SlotLine extends StatelessWidget {
  final List<int> groups;
  final Widget Function(int index) slot;
  const SlotLine({super.key, required this.groups, required this.slot});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var g = 0, start = 0; g < groups.length; start += groups[g], g++) ...[
          if (g > 0) const SizedBox(width: 14),
          for (var i = start; i < start + groups[g]; i++) ...[
            if (i > start) const SizedBox(width: 5),
            slot(i),
          ],
        ],
      ],
    ),
  );
}
