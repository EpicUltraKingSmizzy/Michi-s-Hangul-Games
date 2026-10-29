import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/speaker.dart';
import 'package:hangul_hooray/logic/game_engine.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:hangul_hooray/widgets/common.dart';
import 'package:hangul_hooray/widgets/number_help.dart';
import 'package:hangul_hooray/widgets/time_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

TimeRound _r(int h, int m, {bool sky = false}) =>
    TimeRound(time: h * 60 + m, showSky: sky, tiles: const []);

Future<void> _setUp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppState.kSpokenAnswer: true,
    AppState.kVibration: false,
    ...prefs,
  });
  await tester.runAsync(appState.load);
  Speaker.debugSpoken = [];
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// Seed whose first 🕒 round has (or lacks) the sky window.
int _seed({required bool sky}) {
  for (var s = 0; ; s++) {
    if ((GameEngine([], random: Random(s)).newRound(2) as TimeRound).showSky == sky) return s;
  }
}

dynamic _state(WidgetTester t) => t.state(find.byType(GameScreen));

/// Taps the tiles that spell [text] (spaces ignored).
Future<void> _spell(WidgetTester tester, TimeRound r, String text) async {
  final used = <int>{};
  for (final c in text.replaceAll(' ', '').split('')) {
    final i = [for (var i = 0; i < r.tiles.length; i++) i]
        .firstWhere((i) => r.tiles[i] == c && !used.contains(i));
    used.add(i);
    await tester.tap(find.byKey(ValueKey('tile_$i')));
    await tester.pump();
  }
}

void main() {
  tearDown(() => Speaker.debugSpoken = null);

  group('🕒 times', () {
    test('5-minute steps from 7:00 AM to 1:00 AM, never 1:01–6:59 AM', () {
      expect(playableTimes, hasLength(217));
      expect(playableTimes.first, 7 * 60);
      expect(playableTimes.last, 60);
      for (final t in playableTimes) {
        expect(t % 5, 0);
        expect(t > 60 && t < 7 * 60, isFalse, reason: '$t');
      }
      expect(playableTimes, containsAll([0, 12 * 60, 23 * 60 + 55]));
      final rand = Random(3);
      final recent = ListQueue<String>();
      for (var i = 0; i < 2000; i++) {
        final r = newTimeRound(rand, recent: recent);
        expect(playableTimes, contains(r.time));
        expect(r.tiles.toSet(), containsAll(r.syllables.toSet()));
        expect(r.tiles, hasLength(timeTileCount), reason: '${r.digital} ${r.tiles}');
        if (r.minute == 30) expect(r.tiles, contains('반'));
      }
    });

    test('every hour in native Korean + 시', () {
      const want = ['한', '두', '세', '네', '다섯', '여섯', '일곱', '여덟', '아홉', '열', '열한', '열두'];
      for (var h = 0; h < 24; h++) {
        expect(_r(h, 0).korean, '${want[(h + 11) % 12]} 시', reason: '$h:00');
      }
      expect(_r(0, 0).korean, '열두 시');
      expect(_r(12, 0).korean, '열두 시');
      expect(_r(13, 0).korean, '한 시');
    });

    test('every minute in Sino-Korean + 분; :00 is the hour only', () {
      const ones = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
      for (var m = 1; m < 60; m++) {
        final tens = m ~/ 10;
        final w =
            '${tens == 0 ? '' : (tens == 1 ? '' : ones[tens])}${tens == 0 ? '' : '십'}${ones[m % 10]}';
        expect(sinoMinutes(m), w, reason: '$m');
      }
      expect(_r(17, 5).korean, '다섯 시 오 분');
      expect(_r(11, 45).korean, '열한 시 사십오 분');
      expect(_r(9, 10).korean, '아홉 시 십 분');
      expect(_r(8, 0).words, ['여덟', '시']);
    });

    test(':30 takes 삼십 분 or 반', () {
      final r = _r(15, 30);
      expect(r.accepted, {'세시삼십분', '세시반'});
      expect(isTimeBuilt(r, '세시반'), isTrue);
      expect(isTimeBuilt(r, '세시삼십분'), isTrue);
      expect(isTimeBuilt(r, '세시'), isFalse);
      expect(r.spokenFor('세시반'), '세 시 반');
      expect(_r(15, 30, sky: true).spokenFor('세시반'), '오후 세 시 반');
      expect(_r(15, 35).accepted, {'세시삼십오분'});
    });

    test('sky: morning 7–11:55 AM, afternoon 12–6:55 PM, night 7–11:55 PM, none 12–1 AM', () {
      for (final t in playableTimes) {
        final h = t ~/ 60;
        final s = skySceneFor(t);
        if (h < 7) {
          expect(s, isNull, reason: '$t');
        } else if (h < 12) {
          expect(s, SkyScene.morning);
        } else if (h < 19) {
          expect(s, SkyScene.afternoon);
        } else {
          expect(s, SkyScene.night);
        }
      }
      final rand = Random(1);
      var sky = 0;
      for (var i = 0; i < 3000; i++) {
        final r = newTimeRound(rand);
        if (r.showSky) {
          sky++;
          expect(r.time ~/ 60, greaterThanOrEqualTo(7));
        }
      }
      expect(sky / 3000, closeTo(0.4 * 205 / 217, 0.04));
    });

    test('AM/PM and 오전/오후 only with the sky', () {
      expect(_r(17, 5).digital, '5:05');
      expect(_r(17, 5, sky: true).digital, '5:05 PM');
      expect(_r(11, 45, sky: true).digital, '11:45 AM');
      expect(_r(0, 15).digital, '12:15');
      expect(_r(17, 5, sky: true).korean, '오후 다섯 시 오 분');
      expect(_r(9, 0, sky: true).korean, '오전 아홉 시');
      expect(_r(12, 0, sky: true).period, '오후');
    });

    test('decoys never spell part of the answer', () {
      final rand = Random(9);
      for (final t in playableTimes) {
        final r = TimeRound(time: t, showSky: false, tiles: const []);
        final d = timeDecoys(r, rand);
        expect(d, hasLength(3));
        expect(d.toSet().intersection(r.syllables.toSet()), isEmpty);
      }
    });
  });

  group('🔍 Pick the meaning (merged)', () {
    test('plays both formats at random', () {
      final words = [
        for (var i = 0; i < 8; i++)
          VocabEntry(sectionName: 's$i', english1: 'Word $i', korean1: '말$i'),
      ];
      final e = GameEngine(words, random: Random(2));
      var korean = 0, meaning = 0;
      for (var i = 0; i < 200; i++) {
        final r = e.newRound(1) as ChoiceRound;
        r.optionsAreKorean ? korean++ : meaning++;
      }
      expect(korean, greaterThan(50));
      expect(meaning, greaterThan(50));
      expect(gameInfos[0].tileName, contains('Pick the meaning'));
    });

    test('🕒 needs no words and gives no pack credit', () {
      final e = GameEngine([]);
      expect(e.canPlay(GameEngine.timeGame), isTrue);
      expect(GameEngine.usesVocab(GameEngine.timeGame), isFalse);
      expect(gameInfos[1].tileName, contains('What Time Is It?'));
      expect(gameInfos[1].color, const Color(0xFF7CB518));
      expect(gameOrder, [1, 9, 3, 4, 5, 6, 7, 8, 2, 10]);
    });
  });

  group('migration', () {
    final day = {
      '2026-10-01': {'1': 3, '2': 4, '3': 1},
      '2026-10-02': {'2': 2},
    };
    testWidgets('🎯 wins move into 🔍 once; packs untouched', (tester) async {
      await _setUp(
        tester,
        prefs: {'wins_by_day': jsonEncode(day), AppState.kPackWins: '{"2026-10-01":{"food":5}}'},
      );
      expect(appState.winsByDay['2026-10-01'], {1: 7, 3: 1});
      expect(appState.winsByDay['2026-10-02'], {1: 2});
      expect(appState.allTimeTotal, 10);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kMergedGame2), isTrue);
      expect(prefs.getString(AppState.kPackWins), '{"2026-10-01":{"food":5}}');
      // 🕒 wins after the merge stay 🕒 wins on the next start.
      appState.winsByDay['2026-10-02']![2] = 5;
      await prefs.setString(
        'wins_by_day',
        jsonEncode({
          '2026-10-01': {'1': 7, '3': 1},
          '2026-10-02': {'1': 2, '2': 5},
        }),
      );
      await tester.runAsync(appState.load);
      expect(appState.winsByDay['2026-10-01'], {1: 7, 3: 1});
      expect(appState.winsByDay['2026-10-02'], {1: 2, 2: 5});
    });

    for (final (off, want1) in [
      (['1'], true),
      (['2'], true),
      (['1', '2'], false),
    ]) {
      testWidgets('🔀 Shuffle off $off → 🔍 ${want1 ? 'on' : 'off'}, 🕒 on', (tester) async {
        await _setUp(tester, prefs: {AppState.kShuffleOff: off});
        expect(appState.shuffleIncludes(1), want1);
        expect(appState.shuffleIncludes(2), isTrue);
        await tester.runAsync(appState.load);
        expect(appState.shuffleIncludes(1), want1, reason: 'idempotent');
      });
    }

    testWidgets('all others off and 🎯 was the only one on: 🔍 comes on', (tester) async {
      await _setUp(
        tester,
        prefs: {
          AppState.kShuffleOff: ['1', '3', '4', '5', '6', '7', '8', '9', '10'],
        },
      );
      expect(appState.shuffleIncludes(1), isTrue);
      expect(appState.shuffleIncludes(2), isTrue);
    });
  });

  group('🕒 9 tiles + ⌫', () {
    test('answers never need more than 9 tiles (max 7 + 반)', () {
      var most = 0;
      for (final t in playableTimes) {
        final r = TimeRound(time: t, showSky: false, tiles: const []);
        final n = r.syllables.length + (r.minute == 30 ? 1 : 0);
        most = max(most, r.syllables.length);
        expect(n, lessThanOrEqualTo(timeTileCount), reason: r.korean);
      }
      expect(most, 7); // 열두 시 오십오 분
    });

    test('every time, many seeds: exactly 9, answer kept, native/Sino decoys first', () {
      for (var seed = 0; seed < 5; seed++) {
        final rand = Random(seed);
        for (final t in playableTimes) {
          final bare = TimeRound(time: t, showSky: false, tiles: const []);
          final need = timeTileCount - bare.syllables.length - (bare.minute == 30 ? 1 : 0);
          final d = timeDecoys(bare, rand, count: need);
          expect(d, hasLength(need), reason: bare.korean);
          expect(d.toSet().intersection(bare.syllables.toSet()), isEmpty);
          if (bare.minute == 30) expect(d, isNot(contains('반')));
          // The Sino form of the hour (삼 for 세) is always offered when it
          // isn't in the answer.
          const sino = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
          final h = bare.hour12;
          final s = h >= 10 ? '십' : sino[h];
          if (!bare.syllables.contains(s)) expect(d, contains(s), reason: bare.korean);
        }
      }
    });

    testWidgets('two rows of 5 at 320 wide', (tester) async {
      await _setUp(tester);
      tester.view.physicalSize = const Size(320 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      appState.engine = GameEngine([], random: Random(_seed(sky: true)));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      final rects = [
        for (var i = 0; i < 9; i++) tester.getRect(find.byKey(ValueKey('tile_$i'))),
        tester.getRect(find.byKey(const ValueKey('tile_backspace'))),
      ];
      expect(find.byKey(const ValueKey('tile_9')), findsNothing);
      for (var i = 0; i < 10; i++) {
        expect(rects[i].top, closeTo(rects[i < 5 ? 0 : 5].top, 0.5), reason: 'tile $i');
        expect(rects[i].width, closeTo(rects[0].width, 0.5));
        expect(rects[i].right, lessThanOrEqualTo(320));
      }
      expect(rects[5].top, greaterThan(rects[0].bottom));
      expect(tester.takeException(), isNull);
      await _done(tester);
    });
  });

  group('🕒 answer slots on one line', () {
    for (final w in [320.0, 360.0, 412.0]) {
      testWidgets('all 217 times at ${w.toInt()} wide', (tester) async {
        tester.view.physicalSize = Size(w * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        for (final t in playableTimes) {
          final r = TimeRound(time: t, showSky: false, tiles: const []);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SlotLine(
                      groups: [for (final x in r.words) x.length],
                      slot: (i) => SizedBox(key: ValueKey('s$i'), width: 46, height: 53),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: r.korean);
          final top = tester.getRect(find.byKey(const ValueKey('s0'))).top;
          for (var i = 0; i < r.syllables.length; i++) {
            final b = tester.getRect(find.byKey(ValueKey('s$i')));
            expect(b.top, closeTo(top, 0.01), reason: '${r.korean}: slot $i');
            expect(b.left, greaterThanOrEqualTo(16));
            expect(b.right, lessThanOrEqualTo(w - 16));
          }
        }
      });
    }

    testWidgets('in the game at 320 wide, 9:55 stays one line', (tester) async {
      await _setUp(tester);
      tester.view.physicalSize = const Size(320 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      var seed = 0;
      while ((GameEngine([], random: Random(seed)).newRound(2) as TimeRound).syllables.length < 7) {
        seed++;
      }
      appState.engine = GameEngine([], random: Random(seed));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      final r = _state(tester).currentRound as TimeRound;
      final top = tester.getRect(find.byKey(const ValueKey('slot_0'))).top;
      for (var i = 0; i < r.syllables.length; i++) {
        final b = tester.getRect(find.byKey(ValueKey('slot_$i')));
        expect(b.top, closeTo(top, 0.01));
        expect(b.right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
      await _done(tester);
    });
  });

  group('🕒 screen', () {
    testWidgets('no sky: clock + digital, no 오전/오후; spelling wins and speaks', (tester) async {
      await _setUp(tester);
      appState.engine = GameEngine([], random: Random(_seed(sky: false)));
      final before = appState.sessionWins[2]!;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      final r = _state(tester).currentRound as TimeRound;
      expect(find.byKey(const ValueKey('time_clock')), findsOneWidget);
      expect(find.byKey(const ValueKey('time_sky')), findsNothing);
      expect(find.byKey(const ValueKey('period_오전')), findsNothing);
      expect(find.text(r.digital), findsOneWidget);
      expect(find.byKey(const ValueKey('number_help')), findsOneWidget);
      await _spell(tester, r, r.korean);
      await tester.pump(const Duration(milliseconds: 100));
      expect(appState.sessionWins[2], before + 1);
      expect(Speaker.debugSpoken, contains(r.korean));
      expect(tester.takeException(), isNull);
      await _done(tester);
    });

    testWidgets('sky: 오전/오후 must be right too', (tester) async {
      await _setUp(tester);
      appState.engine = GameEngine([], random: Random(_seed(sky: true)));
      final before = appState.sessionWins[2]!;
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      final r = _state(tester).currentRound as TimeRound;
      expect(find.byKey(const ValueKey('time_sky')), findsOneWidget);
      expect(find.byKey(const ValueKey('time_clock')), findsOneWidget);
      expect(find.text(r.digital), findsOneWidget);
      expect(r.digital, endsWith(r.isPm ? 'PM' : 'AM'));
      await _spell(tester, r, r.words.join());
      expect(appState.sessionWins[2], before, reason: 'no period yet');
      final wrong = r.period == '오전' ? '오후' : '오전';
      await tester.tap(find.byKey(ValueKey('period_$wrong')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(appState.sessionWins[2], before);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(ValueKey('period_${r.period}')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(appState.sessionWins[2], before + 1);
      expect(Speaker.debugSpoken, contains(r.korean));
      await _done(tester);
    });

    testWidgets('❓ opens 🕒 Telling Time with the approved text', (tester) async {
      await _setUp(tester);
      appState.engine = GameEngine([], random: Random(1));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('number_help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('number_help_dialog')), findsOneWidget);
      expect(timeHelp.allText.toList(), [
        '🕒 Telling Time',
        'Koreans say the hour with native Korean numbers followed by 시, and the minutes with '
            'Sino-Korean numbers followed by 분.',
        'Before 시, some hours use a short form: 하나 becomes 한, 둘 becomes 두, 셋 becomes 세, '
            '넷 becomes 네, 열하나 becomes 열한 and 열둘 becomes 열두.',
        'On the hour, say only the hour: 3:00 is 세 시.',
        '반 means "half" and can replace 삼십 분 at half past the hour: 2:30 is 두 시 반 or '
            '두 시 삼십 분.',
        '오전 (AM) and 오후 (PM) go before the time:\n오전 아홉 시 (9:00 AM)\n'
            '오후 세 시 십오 분 (3:15 PM)\n오후 열한 시 반 (11:30 PM)',
      ]);
      expect(timeHelp.blocks.whereType<NumberHelpTable>(), isEmpty);
      for (final t in timeHelp.allText) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.byKey(const ValueKey('number_help_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('number_help_dialog')), findsNothing);
      await _done(tester);
    });

    testWidgets('⌚ Digital time off hides the numbers, keeps the clock', (tester) async {
      await _setUp(tester, prefs: {AppState.kShowDigitalTime: false});
      expect(appState.showDigitalTime, isFalse);
      appState.engine = GameEngine([], random: Random(_seed(sky: false)));
      await tester.pumpWidget(MaterialApp(home: GameScreen(key: UniqueKey(), game: 2)));
      await tester.pump();
      expect(find.byKey(const ValueKey('time_digital')), findsNothing);
      expect(find.byKey(const ValueKey('time_clock')), findsOneWidget);
      await _done(tester);
    });

    testWidgets('⌚ Digital time option: on by default, switch saves', (tester) async {
      await _setUp(tester);
      expect(appState.showDigitalTime, isTrue);
      await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
      await tester.pump();
      final opt = find.byKey(const ValueKey('opt_show_digital_time'));
      await tester.scrollUntilVisible(opt, 200);
      await tester.pumpAndSettle();
      expect(find.text('Digital time'), findsOneWidget);
      await tester.tap(opt);
      await tester.pumpAndSettle();
      expect(appState.showDigitalTime, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.kShowDigitalTime), isFalse);
      await _done(tester);
    });
  });
}
