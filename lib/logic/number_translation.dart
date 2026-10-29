import 'dart:math';

const sinoDigits = ['영', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
const nativeDigits = ['', '하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉'];
const sinoZero = ['영', '령', '공'];

const _sinoLargeUnits = [(100000000, '억'), (10000, '만'), (1000, '천'), (100, '백'), (10, '십')];
const _nativeLargeUnits = [
  (90, '아흔'),
  (80, '여든'),
  (70, '일흔'),
  (60, '예순'),
  (50, '쉰'),
  (40, '마흔'),
  (30, '서른'),
  (20, '스물'),
  (10, '열'),
];

/// Exact port of the VB.NET `NumberTranslation` function.
///
/// Notes kept from the original:
/// * 0 in Sino-Korean is randomly 영, 령 or 공.
/// * Changed from the original: 육 is always 육 (16 → 십육, 106 → 백육); the old
///   육 → 륙 rewrite produced non-standard spellings.
/// * Leading "one" before a unit is dropped (100 → 백, 10000 → 만).
String numberTranslation(int num, {bool useNativeKorean = false, Random? random}) {
  final rand = random ?? Random();
  final largeUnits = useNativeKorean ? _nativeLargeUnits : _sinoLargeUnits;
  var out = '';

  for (final unit in largeUnits) {
    if (num >= unit.$1) {
      final numStr = num.toString();
      final partLen = numStr.length - unit.$1.toString().length + 1;
      final numPart = int.tryParse(numStr.substring(0, partLen)) ?? 0;
      if (numPart != 1 && !useNativeKorean) {
        out += numberTranslation(numPart, useNativeKorean: useNativeKorean, random: rand);
      }
      out += unit.$2;
      num = num % unit.$1;
    }
  }

  if (num == 0) {
    if (out.isEmpty && !useNativeKorean) {
      out = sinoZero[rand.nextInt(sinoZero.length)];
    }
  } else if (!useNativeKorean) {
    out += sinoDigits[num];
  } else {
    out += nativeDigits[num];
  }

  return out;
}
