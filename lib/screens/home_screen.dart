import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/common.dart';
import 'bundles_screen.dart';
import 'game_screen.dart';
import 'options_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Home tile number of 🔀 Shuffle.
  static const shuffleTile = 0;

  /// Game tiles in rows of two, left to right (2 is 🕒 What Time Is It?;
  /// 5 is 🧩 and 🌀 together).
  static const tileOrder = homeTileOrder;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// 🧩/🌀 shared tile: its two bubbles, anchored to the tile.
  final _scrambleBubbles = OverlayPortalController();
  final _scrambleLink = LayerLink();

  /// The two bubbles over the 🧩 tile; a tap anywhere else closes them.
  Widget _bubbles(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('bubbles_dismiss'),
          behavior: HitTestBehavior.opaque,
          onTap: _scrambleBubbles.hide,
        ),
      ),
      CompositedTransformFollower(
        link: _scrambleLink,
        targetAnchor: Alignment.center,
        followerAnchor: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (_, t, child) => Transform.scale(scale: t, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in scrambleTileGames) ...[
                if (g != scrambleTileGames.first) const SizedBox(height: 10),
                BouncyButton(
                  key: ValueKey('bubble_$g'),
                  color: gameInfos[g - 1].color,
                  radius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  onTap: () {
                    _scrambleBubbles.hide();
                    _open(GameScreen(game: g));
                  },
                  child: Text(gameInfos[g - 1].tileName, style: const TextStyle(fontSize: 21)),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: appState,
            builder: (context, _) => LayoutBuilder(builder: _body),
          ),
        ),
      ),
    );
  }

  static const _gap = 12.0;

  /// Heights: a game row is 5 parts, the 🔀 Shuffle bar 3.
  static const _rowFlex = 5, _barFlex = 3;

  /// Header, 5 rows of uniform game tiles, a shorter full-width 🔀 Shuffle
  /// bar and the bottom buttons share one screen: the tiles take whatever
  /// height is left (all the game tiles the same size). If that
  /// would make them too squat (big system font), the page is laid out
  /// taller and shrunk to fit, so it never scrolls.
  Widget _body(BuildContext context, BoxConstraints box) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Generous estimates of the header / bottom row, plus a minimum tile.
    final minPage = (134 + 104) * scale + (5 + _barFlex / _rowFlex) * (72 * scale) + 5 * _gap;
    final fits = box.maxHeight >= minPage;
    final page = _page();
    if (fits) return page;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: box.maxWidth * minPage / box.maxHeight, height: minPage, child: page),
    );
  }

  Widget _page() => Column(
    children: [
      _header(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var row = 0; row < 5; row++) ...[
                if (row > 0) const SizedBox(height: _gap),
                Expanded(
                  flex: _rowFlex,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _gameTile(HomeScreen.tileOrder[row * 2])),
                      const SizedBox(width: _gap),
                      Expanded(child: _gameTile(HomeScreen.tileOrder[row * 2 + 1])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: _gap),
              Expanded(
                flex: _barFlex,
                child: SizedBox(width: double.infinity, child: _gameTile(HomeScreen.shuffleTile)),
              ),
            ],
          ),
        ),
      ),
      _bottomButtons(),
    ],
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: _wiggle,
          builder: (_, child) => Transform.rotate(angle: (_wiggle.value - 0.5) * 0.5, child: child),
          child: const Text('🇰🇷', style: TextStyle(fontSize: 54)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big titles; on a narrow phone each shrinks to stay on one line.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFFF5C8A), Color(0xFFFF9F1C), Color(0xFF7B5CFF)],
                  ).createShader(r),
                  child: const Text(
                    '미시의 한글 게임',
                    key: ValueKey('title_ko'),
                    style: TextStyle(
                      fontSize: 38,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Michi’s Hangul Games',
                  key: ValueKey('title_en'),
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7B5CFF),
                  ),
                ),
              ),
              Text(
                wordsInPlay(appState.activeVocab().length),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B4E8C),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Game tiles by game number (🧩's tile also offers 🌀); tile 0 is the
  /// 🔀 Shuffle bar.
  Widget _gameTile(int game) {
    final shuffle = game == HomeScreen.shuffleTile;
    final both = game == scrambleTile;
    final info = shuffle ? shuffleInfo : gameInfos[game - 1];
    final wins = shuffle
        ? appState.shuffleSessionWins
        : both
        ? scrambleTileGames.fold(0, (a, g) => a + (appState.sessionWins[g] ?? 0))
        : appState.sessionWins[game] ?? 0;
    final tile = BouncyButton(
      key: ValueKey('tile_$game'),
      color: info.color,
      gradient: info.gradient,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: both
          ? _scrambleBubbles.show
          : () => _open(shuffle ? const GameScreen.shuffle() : GameScreen(game: game)),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) => _tileFace(game, info, box.maxWidth)),
          ),
          if (wins > 0 && appState.showWins)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _winBadgeText(info, wins),
              ),
            ),
        ],
      ),
    );
    if (!both) return tile;
    return CompositedTransformTarget(
      link: _scrambleLink,
      child: OverlayPortal(
        controller: _scrambleBubbles,
        overlayChildBuilder: _bubbles,
        child: tile,
      ),
    );
  }

  /// '🏆 W:n' in the tile's colour; a gradient tile gets gradient text
  /// (deepened so it reads on white).
  Widget _winBadgeText(GameInfo info, int wins) {
    const style = TextStyle(fontWeight: FontWeight.w900, fontSize: 12);
    if (info.gradient == null) {
      return Text('🏆 W:$wins', style: style.copyWith(color: info.color));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🏆 ', style: style),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) =>
              LinearGradient(colors: info.shades(Colors.black, 0.2)).createShader(rect),
          child: Text(
            'W:$wins',
            key: const ValueKey('rainbow_badge'),
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Tile face: keycap + game emoji side by side at the same size, with the
  /// short subtitle large underneath. If a tile is too small (narrow phone,
  /// big system font) the whole face scales down together, so it never
  /// overflows.
  Widget _tileFace(int game, GameInfo info, double width) => game == HomeScreen.shuffleTile
      ? _barFace(game, info)
      : Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      info.emoji,
                      key: ValueKey('tile_emoji_$game'),
                      style: const TextStyle(fontSize: 40, height: 1.15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.subtitle,
                    key: ValueKey('tile_text_$game'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 21, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        );

  /// The 🔀 Shuffle bar: emoji and name side by side.
  Widget _barFace(int game, GameInfo info) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.emoji,
            key: ValueKey('tile_emoji_$game'),
            style: const TextStyle(fontSize: 36, height: 1.15),
          ),
          const SizedBox(width: 12),
          Text(
            info.subtitle,
            key: ValueKey('tile_text_$game'),
            maxLines: 1,
            style: const TextStyle(fontSize: 26, height: 1.1),
          ),
        ],
      ),
    ),
  );

  Widget _bottomButtons() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: _smallButton(
            '📦',
            'Word Packs',
            const Color(0xFF00B4FF),
            () => _open(const BundlesScreen()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallButton(
            '⚙️',
            'Options',
            const Color(0xFFFF9F1C),
            () => _open(const OptionsScreen()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallButton(
            '📊',
            'Stats',
            const Color(0xFF3DDC84),
            () => _open(const StatsScreen()),
          ),
        ),
      ],
    ),
  );

  Widget _smallButton(String emoji, String label, Color color, VoidCallback onTap) => BouncyButton(
    color: color,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    onTap: onTap,
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}
