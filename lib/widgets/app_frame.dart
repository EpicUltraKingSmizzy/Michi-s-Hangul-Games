import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Wraps every screen of the app (MaterialApp.builder): shrinks the whole
/// app to fit small windows and, in 💼 Business mode, turns it greyscale.
class AppFrame extends StatelessWidget {
  final bool businessMode;
  final Widget child;
  const AppFrame({super.key, required this.businessMode, required this.child});

  @override
  Widget build(BuildContext context) => ShrinkToFit(
    child: BusinessGreyscale(enabled: businessMode, child: child),
  );
}

/// Lays the app out at least [minWidth] x [minHeight] and scales it down to
/// the real window when that is smaller (a small browser window, browser
/// zoom, phone split view). Layouts are never rearranged, only shrunk.
class ShrinkToFit extends StatelessWidget {
  static const minWidth = 360.0, minHeight = 600.0;
  final Widget child;
  const ShrinkToFit({super.key, required this.child});

  /// How much a [size] window shrinks the app (1 = not at all).
  static double scaleFor(Size size) =>
      math.min(1.0, math.min(size.width / minWidth, size.height / minHeight));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (!box.hasBoundedWidth || !box.hasBoundedHeight) return child;
      final real = box.biggest;
      final s = scaleFor(real);
      if (s >= 1 || s <= 0) return child;
      final size = real / s;
      final mq = MediaQuery.of(context);
      return FittedBox(
        key: const ValueKey('shrink_to_fit'),
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: mq.copyWith(
              size: size,
              padding: mq.padding / s,
              viewPadding: mq.viewPadding / s,
              viewInsets: mq.viewInsets / s,
              systemGestureInsets: mq.systemGestureInsets / s,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Luminance greyscale.
const List<double> greyscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Places drawn under a [KeepColor] on screen right now.
class _KeepColorRegistry extends ChangeNotifier {
  final Set<RenderKeepColor> boxes = {};
  void add(RenderKeepColor b) {
    boxes.add(b);
    _changed();
  }

  void remove(RenderKeepColor b) {
    boxes.remove(b);
    _changed();
  }

  // Boxes come and go during layout; tell listeners after the frame.
  bool _scheduled = false;
  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

final _keepColor = _KeepColorRegistry();

/// 💼 Business mode: draws everything under it in greyscale, except the
/// spots marked with [KeepColor] (the colours in 🎨 Color match).
class BusinessGreyscale extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const BusinessGreyscale({super.key, required this.enabled, required this.child});

  @override
  State<BusinessGreyscale> createState() => _BusinessGreyscaleState();
}

class _BusinessGreyscaleState extends State<BusinessGreyscale> with SingleTickerProviderStateMixin {
  final _layerKey = GlobalKey();

  /// Ticks every frame while a [KeepColor] is on screen, so its hole follows
  /// presses, shakes and page slides.
  final _reclip = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker((_) => _reclip.value++);

  @override
  void initState() {
    super.initState();
    _keepColor.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(BusinessGreyscale old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && _keepColor.boxes.isNotEmpty;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _reclip.value++;
    }
  }

  @override
  void dispose() {
    _keepColor.removeListener(_sync);
    _ticker.dispose();
    _reclip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      if (widget.enabled)
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              key: _layerKey,
              clipper: _HoleClipper(_layerKey, _reclip),
              child: const BackdropFilter(
                key: ValueKey('business_greyscale'),
                filter: ColorFilter.matrix(greyscaleMatrix),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
    ],
  );
}

/// The whole screen minus every visible [KeepColor] spot.
class _HoleClipper extends CustomClipper<Path> {
  final GlobalKey layer;
  _HoleClipper(this.layer, Listenable reclip) : super(reclip: reclip);

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final me = layer.currentContext?.findRenderObject();
    if (me is! RenderBox || !me.attached) return path;
    for (final b in _keepColor.boxes) {
      if (!b.attached || !b.hasSize || !b.visible) continue;
      final hole = Path()..addRRect(b.holeRRect);
      path.addPath(hole, Offset.zero, matrix4: b.getTransformTo(me).storage);
    }
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper old) => true;
}

/// Keeps its spot in colour while 💼 Business mode greys out the app. The
/// spot is this widget's box grown by [outset] (negative shrinks), with
/// corners of [radius]. Only shown while its page is the top one, so a
/// pop-up over it stays grey.
class KeepColor extends StatelessWidget {
  final Widget child;
  final EdgeInsets outset;
  final double radius;
  const KeepColor({super.key, required this.child, this.outset = EdgeInsets.zero, this.radius = 0});

  @override
  Widget build(BuildContext context) =>
      _KeepColorBox(route: ModalRoute.of(context), outset: outset, radius: radius, child: child);
}

class _KeepColorBox extends SingleChildRenderObjectWidget {
  final ModalRoute<dynamic>? route;
  final EdgeInsets outset;
  final double radius;
  const _KeepColorBox({
    required this.route,
    required this.outset,
    required this.radius,
    super.child,
  });

  @override
  RenderKeepColor createRenderObject(BuildContext context) =>
      RenderKeepColor(route: route, outset: outset, radius: radius);

  @override
  void updateRenderObject(BuildContext context, RenderKeepColor r) => r
    ..route = route
    ..outset = outset
    ..radius = radius;
}

class RenderKeepColor extends RenderProxyBox {
  ModalRoute<dynamic>? route;
  EdgeInsets outset;
  double radius;
  RenderKeepColor({required this.route, required this.outset, required this.radius});

  bool get visible => route == null || route!.isCurrent;

  RRect get holeRRect =>
      RRect.fromRectAndRadius(outset.inflateRect(Offset.zero & size), Radius.circular(radius));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _keepColor.add(this);
  }

  @override
  void detach() {
    _keepColor.remove(this);
    super.detach();
  }
}

/// How many [KeepColor] spots are on screen (for tests).
@visibleForTesting
int get keepColorCount => _keepColor.boxes.length;
