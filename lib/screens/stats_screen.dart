import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'pack_stats_screen.dart';

const _ink = Color(0xFF3A1D5C);

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('📊 Stats')),
        body: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final today = dayKey(DateTime.now());
            final session = appState.sessionWins.values.fold(0, (a, b) => a + b);
            final byGame = appState.allTimeByGame;
            final days = appState.winsByDay.keys.toList()..sort((a, b) => b.compareTo(a));
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
              children: [
                Row(
                  children: [
                    _bigNumber('🎮', 'This session', session, const Color(0xFFFF9F1C)),
                    _bigNumber('☀️', 'Today', appState.winsOnDay(today), const Color(0xFF00B4FF)),
                    _bigNumber('🏆', 'All time', appState.allTimeTotal, const Color(0xFFFF5C8A)),
                  ],
                ),
                const SizedBox(height: 14),
                BouncyButton(
                  key: const ValueKey('pack_stats_entry'),
                  color: const Color(0xFF8E44EC),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const PackStatsScreen())),
                  child: const Row(
                    children: [
                      Text('📦', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Word Pack Stats',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white, size: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _section('All-time wins by game', _gameGrid(byGame)),
                _section('Wins per day (last 14 days)', _DayChart(appState.winsByDay)),
                _section(
                  'Daily breakdown',
                  days.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No wins yet. Go play! 🚀', style: TextStyle(fontSize: 18)),
                        )
                      : Column(
                          children: [for (final d in days) _dayRow(d, appState.winsByDay[d]!)],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bigNumber(String emoji, String label, int n, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Color.lerp(color, Colors.black, 0.25)!, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          Text(
            '$n',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title, Widget child) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  Widget _gameGrid(Map<int, int> byGame) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final g in gameOrder)
        ThemedBorderBox(
          info: gameInfos[g - 1],
          width: 2,
          radius: 16,
          fillColor: gameInfos[g - 1].gradient == null
              ? gameInfos[g - 1].color.withValues(alpha: 0.18)
              : Colors.white,
          fillGradient: gameInfos[g - 1].gradient == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gameInfos[g - 1].shades(Colors.white, 0.8),
                ),
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(gameInfos[g - 1].emoji, style: const TextStyle(fontSize: 24)),
                Text(
                  '${byGame[g]}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _dayRow(String day, Map<int, int> games) {
    final total = games.values.fold(0, (a, b) => a + b);
    final keys = games.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '$day\n🏆 $total',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final g in keys)
                  if (games[g]! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: gameInfos[g - 1].fill(borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${gameInfos[g - 1].emoji} ${games[g]}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple stacked bar chart (one colour per game) for the last 14 days.
class _DayChart extends StatelessWidget {
  final Map<String, Map<int, int>> winsByDay;
  const _DayChart(this.winsByDay);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = [
      for (var i = 13; i >= 0; i--)
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    ];
    final totals = [for (final d in days) _sum(winsByDay[dayKey(d)])];
    final maxV = max(1, totals.reduce(max));
    const chartH = 150.0;
    return Column(
      children: [
        SizedBox(
          height: chartH + 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (totals[i] > 0)
                        Text(
                          '${totals[i]}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: chartH * totals[i] / maxV,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: Column(
                            children: [
                              for (final g in gameOrder.reversed)
                                if ((winsByDay[dayKey(days[i])]?[g] ?? 0) > 0)
                                  Expanded(
                                    flex: winsByDay[dayKey(days[i])]![g]!,
                                    child: Container(decoration: gameInfos[g - 1].fill()),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${days[i].day}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final g in gameOrder)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: gameInfos[g - 1].fill()),
                  const SizedBox(width: 3),
                  Text(gameInfos[g - 1].emoji),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static int _sum(Map<int, int>? m) => m == null ? 0 : m.values.fold(0, (a, b) => a + b);
}
