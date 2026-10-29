import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';

import 'support/vocab.dart';

void main() {
  test('the vocab files in assets/vocab are valid', () {
    expect(validateVocab(readVocabIndex(), readPackFile), isEmpty);
  });

  test('validation catches the mistakes it should', () {
    const index = 'a\nb';
    const files = {
      'a':
          '[Pack]\nId = a\nEmoji = 🅰️\nName = A\nBlurb = x\nDefaultOn = true\n'
          '[W1]\nEnglish1 = one\nKorean1 = 하나\nAlsoPacks = b, zzz\n'
          '[W2]\nEnglish1 = two\nKorean2 = 둘\nColour = red\n',
      'b':
          '[Pack]\nId = bee\nName = A\nBlurb = y\nDefaultOn = maybe\nShape = round\n'
          '[W1]\nKorean1 = 하나\n',
    };
    final errors = validateVocab(index, (id) => files[id]!).join('\n');
    for (final want in [
      'unknown AlsoPacks id zzz',
      'a [W2]: missing Korean1',
      'a [W2]: unknown key colour',
      'b [Pack]: Id must be "b"',
      'b [Pack]: missing emoji',
      'b [Pack]: DefaultOn must be true or false',
      'b [Pack]: unknown key shape',
      'b [Pack]: duplicate name',
      'b [W1]: duplicate section',
      'b [W1]: missing English1',
    ]) {
      expect(errors, contains(want));
    }
    expect(errors, isNot(contains('AlsoPacks id b')));
  });
}
