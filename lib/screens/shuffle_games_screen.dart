import 'package:flutter/material.dart';

import '../logic/game_engine.dart';
import '../main.dart';
import '../widgets/common.dart';

const _ink = Color(0xFF3A1D5C);

/// ⚙️ Options › 🔀 Shuffle games: which games can come up in 🔀 Shuffle.
/// All on by default; the last game that is on cannot be switched off.
class ShuffleGamesScreen extends StatelessWidget {
  const ShuffleGamesScreen({super.key});

  static const lastGameMessage = 'Keep at least one game in 🔀 Shuffle!';

  Future<void> _toggle(BuildContext context, int game, bool on) async {
    final ok = await appState.setShuffleGame(game, on);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            lastGameMessage,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          backgroundColor: shuffleInfo.color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '🔀 Shuffle games',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Pick the games that can come up in 🔀 Shuffle. '
                  '${appState.shuffleGameCount}\u00A0of\u00A0${GameEngine.gameCount}\u00A0games are on.',
                  key: const ValueKey('shuffle_games_intro'),
                  style: const TextStyle(fontSize: 16, color: Color(0xFF6B4E8C)),
                ),
              ),
              for (final g in gameOrder) _gameCard(context, g),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameCard(BuildContext context, int game) {
    final info = gameInfos[game - 1];
    final on = appState.shuffleIncludes(game);
    final accent = info.gradient?.last ?? info.color;
    return ThemedBorderBox(
      key: ValueKey('shuffle_game_$game'),
      info: info,
      radius: 20,
      fillColor: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.3), offset: const Offset(0, 4))],
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: SwitchListTile(
          key: ValueKey('shuffle_switch_$game'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          activeThumbColor: info.color,
          title: Text(
            info.tileName,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: on ? _ink : _ink.withValues(alpha: 0.45),
            ),
          ),
          value: on,
          onChanged: (v) => _toggle(context, game, v),
        ),
      ),
    );
  }
}
