import 'dart:collection';
import 'dart:math';

/// 🕒 What Time Is It?: the sky window shown in some rounds.
enum SkyScene { morning, afternoon, night }

/// Native Korean hour words, 1-12 (used before 시).
const hourWords = ['한', '두', '세', '네', '다섯', '여섯', '일곱', '여덟', '아홉', '열', '열한', '열두'];

const _sinoDigits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

/// Sino-Korean minutes (1-59) before 분: 5 → 오, 10 → 십, 25 → 이십오.
String sinoMinutes(int m) {
  final tens = m ~/ 10, ones = m % 10;
  final t = tens == 0 ? '' : (tens == 1 ? '십' : '${_sinoDigits[tens]}십');
  return '$t${_sinoDigits[ones]}';
}

/// Earliest and latest playable times, as minutes after midnight (7:00 AM
/// and 1:00 AM the next day). 1:01-6:59 AM never comes up.
const timeFirst = 7 * 60, timeLast = 25 * 60;

/// Every playable time in 5-minute steps, as minutes after midnight (0-1439).
final List<int> playableTimes = [for (var t = timeFirst; t <= timeLast; t += 5) t % (24 * 60)];

/// One 🕒 round.
class TimeRound {
  /// Minutes after midnight (0-1439).
  final int time;

  /// Whether this round shows the sky window and the 오전 / 오후 buttons.
  final bool showSky;

  /// Syllable tiles: the answer's syllables plus decoys, shuffled.
  final List<String> tiles;

  const TimeRound({required this.time, required this.showSky, required this.tiles});

  int get hour24 => time ~/ 60;
  int get minute => time % 60;

  /// 1-12 on the clock face.
  int get hour12 => hour24 % 12 == 0 ? 12 : hour24 % 12;
  bool get isPm => hour24 >= 12;

  /// 오전 (before noon) or 오후.
  String get period => isPm ? '오후' : '오전';

  SkyScene? get scene => skySceneFor(time);

  /// The words to assemble (no 오전/오후): ['세', '시'] or ['세', '시', '십오', '분'].
  List<String> get words => [
    hourWords[hour12 - 1],
    '시',
    if (minute != 0) ...[sinoMinutes(minute), '분'],
  ];

  /// The tiles' answer, syllable by syllable (spaces are not tiles).
  List<String> get syllables => words.join().split('');

  /// Every accepted assembly, spaces removed: the canonical one, and at :30
  /// also 'X시반'.
  Set<String> get accepted => {words.join(), if (minute == 30) '${hourWords[hour12 - 1]}시반'};

  /// The Korean as written / read aloud: '세 시 십오 분', with 오전/오후 in
  /// rounds that show the sky.
  String get korean => [if (showSky) period, ...words].join(' ');

  /// Korean for what the player built ([built] without spaces), e.g. '세 시 반'.
  String spokenFor(String built) {
    final pre = showSky ? '$period ' : '';
    if (minute == 30 && built.endsWith('반')) return '$pre${hourWords[hour12 - 1]} 시 반';
    return korean;
  }

  /// '5:05' or, in sky rounds, '5:05 PM'.
  String get digital =>
      '$hour12:${minute.toString().padLeft(2, '0')}${showSky ? (isPm ? ' PM' : ' AM') : ''}';
}

/// Morning 7:00-11:55 AM, afternoon 12:00-6:55 PM, night 7:00-11:55 PM;
/// null for 12:00-1:00 AM (a night sky there would be read as 오후).
SkyScene? skySceneFor(int time) {
  final h = time ~/ 60;
  if (h >= 7 && h < 12) return SkyScene.morning;
  if (h >= 12 && h < 19) return SkyScene.afternoon;
  if (h >= 19) return SkyScene.night;
  return null;
}

const _nativeCount = ['', '하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉'];
const _nativeTens = ['', '열', '스물', '서른', '마흔', '쉰'];

/// Decoy syllables for native / Sino mix-ups: the hour said in Sino-Korean
/// (삼 for 세, 십 for 열) or in counting form (셋), and the minutes said in
/// native Korean (열 for 십) come first; plain number syllables fill up
/// the rest. Never a syllable of the answer.
List<String> timeDecoys(TimeRound r, Random rand, {int count = 3}) {
  final h = r.hour12, m = r.minute;
  // Most instructive first: the hour in Sino-Korean (삼 시 for 세 시).
  final sinoHour = (h >= 10 ? '십${_sinoDigits[h - 10]}' : _sinoDigits[h]).split('')..shuffle(rand);
  final pool = <String>[
    ...(h >= 10 ? '열${_nativeCount[h - 10]}' : _nativeCount[h]).split(''),
    if (m != 0) ...'${_nativeTens[m ~/ 10]}${_nativeCount[m % 10]}'.split(''),
    if (m != 30 && rand.nextInt(4) == 0) '반',
  ];
  final answer = r.syllables.toSet();
  final picked = <String>[];
  for (final s in [...sinoHour, ...pool..shuffle(rand)]) {
    if (picked.length == count) break;
    if (!answer.contains(s) && !picked.contains(s)) picked.add(s);
  }
  for (final s in [
    '셋',
    '삼',
    '열',
    '십',
    '넷',
    '사',
    '둘',
    '이',
    '오',
    '육',
    '하',
    '나',
    '일',
    '칠',
  ]..shuffle(rand)) {
    if (picked.length == count) break;
    if (!answer.contains(s) && !picked.contains(s)) picked.add(s);
  }
  return picked;
}

/// Syllable tiles per 🕒 round: with ⌫ they make two rows of 5.
const timeTileCount = 9;

/// A new round, avoiding the times in [recent] (which it updates).
TimeRound newTimeRound(Random rand, {ListQueue<String>? recent, double skyChance = 0.4}) {
  var time = playableTimes[rand.nextInt(playableTimes.length)];
  for (var i = 0; i < 20 && (recent?.contains('$time') ?? false); i++) {
    time = playableTimes[rand.nextInt(playableTimes.length)];
  }
  recent?.addLast('$time');
  while ((recent?.length ?? 0) > 5) {
    recent!.removeFirst();
  }
  final sky = skySceneFor(time) != null && rand.nextDouble() < skyChance;
  final bare = TimeRound(time: time, showSky: sky, tiles: const []);
  final answer = [...bare.syllables, if (bare.minute == 30) '반'];
  final tiles = [...answer, ...timeDecoys(bare, rand, count: timeTileCount - answer.length)]
    ..shuffle(rand);
  return TimeRound(time: time, showSky: sky, tiles: tiles);
}

/// Whether [built] (tiles in order, spaces ignored) says the round's time.
bool isTimeBuilt(TimeRound r, String built) => r.accepted.contains(built.replaceAll(' ', ''));
