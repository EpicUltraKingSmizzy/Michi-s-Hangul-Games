import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/logic/number_translation.dart';

void main() {
  String sino(int n) => numberTranslation(n);
  String native(int n) => numberTranslation(n, useNativeKorean: true);

  group('Sino-Korean', () {
    test('zero is randomly 영, 령 or 공', () {
      final seen = <String>{};
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        seen.add(numberTranslation(0, random: r));
      }
      expect(seen, {'영', '령', '공'});
    });
    test('digits', () {
      expect(sino(1), '일');
      expect(sino(6), '육');
      expect(sino(9), '구');
    });
    test('육 is never turned into 륙', () {
      expect(sino(16), '십육');
      expect(sino(106), '백육');
      expect(sino(66), '육십육');
      expect(sino(60), '육십');
      expect(sino(6000), '육천');
      expect(sino(1600), '천육백');
      for (var n = 0; n < 2000; n++) {
        expect(sino(n).contains('륙'), isFalse);
      }
    });
    test('leading one is dropped before units', () {
      expect(sino(10), '십');
      expect(sino(100), '백');
      expect(sino(1000), '천');
      expect(sino(10000), '만');
      expect(sino(100000000), '억');
    });
    test('bigger numbers', () {
      expect(sino(11), '십일');
      expect(sino(29), '이십구');
      expect(sino(1004), '천사');
      expect(sino(2908), '이천구백팔');
      expect(sino(100000), '십만');
      expect(sino(123456), '십이만삼천사백오십육');
      expect(sino(999999), '구십구만구천구백구십구');
    });
  });

  group('Native Korean', () {
    test('examples', () {
      expect(native(1), '하나');
      expect(native(5), '다섯');
      expect(native(10), '열');
      expect(native(20), '스물');
      expect(native(21), '스물하나');
      expect(native(99), '아흔아홉');
    });
  });
}
