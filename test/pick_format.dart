import 'package:hangul_hooray/logic/game_engine.dart';

/// The old 2️⃣ 🎯 Pick the Korean now lives inside 1️⃣ 🔍 Pick the meaning.
/// `legacyRound(e, 2)` plays 1️⃣ in that format; `legacyRound(e, 1)` plays
/// 1️⃣ in its Korean-prompt format; any other game plays as usual.
Object legacyRound(GameEngine e, int game) {
  GameEngine.pickKoreanFormat = switch (game) {
    1 => false,
    2 => true,
    _ => null,
  };
  try {
    return e.newRound(game == 2 ? 1 : game);
  } finally {
    GameEngine.pickKoreanFormat = null;
  }
}
