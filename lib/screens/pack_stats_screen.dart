import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../main.dart';
import '../widgets/common.dart';

const _ink = Color(0xFF3A1D5C);
const _numW = 50.0;
const _starW = 30.0;

/// 📊 Stats ▸ 📦 Word Pack Stats: every Word Pack (on or off) with its wins
/// this session, today and all time, and a ⭐ once every word it has now has
/// been the word of a won round. A win counts for each pack its word is in.
class PackStatsScreen extends StatelessWidget {
  const PackStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('📦 Word Pack Stats')),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final today = dayKey(DateTime.now());
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
              children: [
                _header(),
                for (final id in appState.statsPackIds) _packRow(id, today),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Text(
                    'A word in two packs counts for both. ⭐ = every word in the pack won at '
                    'least once. A 🔗 Link Up board is one win per pack and wins all 6 of its words. '
                    '🔢 Sino numbers, 🖐️ Native numbers and 🎨 Color match don\'t use Word Packs.',
                    key: ValueKey('pack_stats_note'),
                    style: TextStyle(fontSize: 13, color: _ink),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
    child: Row(
      children: [
        const Expanded(child: SizedBox()),
        for (final (emoji, label) in const [('🎮', 'Session'), ('☀️', 'Today'), ('🏆', 'All time')])
          SizedBox(
            width: _numW,
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _ink),
                ),
              ],
            ),
          ),
        const SizedBox(width: _starW),
      ],
    ),
  );

  Widget _packRow(String id, String today) {
    final label = appState.packLabel(id);
    final progress = appState.packWordProgress(id);
    final starred = appState.packStarred(id);
    return Card(
      key: ValueKey('pack_stats_$id'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 38, child: Text(label.emoji, style: const TextStyle(fontSize: 26))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  Text(
                    '${progress.won}/${progress.total} words won',
                    key: ValueKey('pack_progress_$id'),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            _num('session_$id', appState.packSessionWins[id] ?? 0, const Color(0xFFFF9F1C)),
            _num('today_$id', appState.packWinsOnDay(id, today), const Color(0xFF00B4FF)),
            _num('alltime_$id', appState.packAllTime(id), const Color(0xFFFF5C8A)),
            // Always there, so the rows line up; the star shows once earned.
            SizedBox(
              key: ValueKey('pack_star_slot_$id'),
              width: _starW,
              child: starred
                  ? const Text(
                      '⭐',
                      key: ValueKey('pack_star'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(String key, int n, Color color) => SizedBox(
    width: _numW,
    child: Text(
      '$n',
      key: ValueKey('pack_$key'),
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: n == 0 ? Colors.black26 : color,
      ),
    ),
  );
}
