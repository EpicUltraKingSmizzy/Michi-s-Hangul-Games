import 'package:flutter/material.dart';

/// One block of a ❓ number explainer: a paragraph or a two-row table.
sealed class NumberHelpBlock {
  const NumberHelpBlock();
}

/// A paragraph of text (may contain line breaks).
class NumberHelpText extends NumberHelpBlock {
  final String text;
  const NumberHelpText(this.text);
}

/// A two-row table: numerals on top, Korean underneath.
class NumberHelpTable extends NumberHelpBlock {
  final List<String> numerals;
  final List<String> korean;
  const NumberHelpTable(this.numerals, this.korean);
}

/// A ❓ number explainer: shown from the Word Packs screen and the 🔢 / 🖐️
/// game headers.
class NumberHelp {
  final String title;
  final List<NumberHelpBlock> blocks;
  const NumberHelp(this.title, this.blocks);

  /// Every piece of text, for tests.
  Iterable<String> get allText => [
    title,
    for (final b in blocks)
      ...switch (b) {
        NumberHelpText(:final text) => [text],
        NumberHelpTable(:final numerals, :final korean) => [...numerals, ...korean],
      },
  ];
}

const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

/// 🔢 Sino-Korean numbers (the 'numbers' pack, 🔢 Sino numbers).
const sinoNumberHelp = NumberHelp('🔢 Sino-Korean Numbers', [
  NumberHelpText(
    'Koreans use Sino-Korean numbers for dates, months, years, money, minutes, phone numbers, '
    'floors and most measurements.',
  ),
  NumberHelpTable(_digits, ['일', '이', '삼', '사', '오', '육', '칠', '팔', '구', '십']),
  NumberHelpText(
    'To count above 10, combine the words in order, from largest to smallest:\n'
    '11 is 십일 (10 + 1)\n'
    '20 is 이십 (2 × 10)\n'
    '25 is 이십오 (2 × 10 + 5)',
  ),
  NumberHelpText(
    'Larger units work the same way: 백 is 100, 천 is 1,000 and 만 is 10,000. Large numbers are '
    'grouped by 만 rather than by thousands, so 100,000 is 십만 (10 × 10,000). Don\'t put 일 in '
    'front of 십, 백, 천 or 만, so 10 is 십 and 100 is 백.',
  ),
  NumberHelpText('Zero is 영, or 공 in phone numbers.'),
]);

/// 🖐️ Native Korean numbers (the 'native' pack, 🖐️ Native numbers).
const nativeNumberHelp = NumberHelp('🖐️ Native Korean Numbers', [
  NumberHelpText(
    'Koreans use these numbers to count things and people, for age, and for the hour when '
    'telling time. Koreans mostly switch to Sino-Korean numbering when counting above 20, and '
    'this numbering is never used past 99.',
  ),
  NumberHelpTable(_digits, ['하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉', '열']),
  NumberHelpText(
    'To count above 10, put the tens word first and the ones word after it, so 11 is 열하나 and '
    '15 is 열다섯. Each multiple of ten has its own word:',
  ),
  NumberHelpTable(
    ['10', '20', '30', '40', '50', '60', '70', '80', '90'],
    ['열', '스물', '서른', '마흔', '쉰', '예순', '일흔', '여든', '아흔'],
  ),
  NumberHelpText(
    'So 23 is 스물셋 and 99 is 아흔아홉. Before a counter word, some numbers get shorter: 하나 '
    'becomes 한, 둘 becomes 두, 셋 becomes 세, 넷 becomes 네 and 스물 becomes 스무. For example, '
    '한 개 is one item and 스무 살 is 20 years old.',
  ),
]);

/// 🕒 How Koreans say the time (🕒 What Time Is It? header).
const timeHelp = NumberHelp('🕒 Telling Time', [
  NumberHelpText(
    'Koreans say the hour with native Korean numbers followed by 시, and the minutes with '
    'Sino-Korean numbers followed by 분.',
  ),
  NumberHelpText(
    'Before 시, some hours use a short form: 하나 becomes 한, 둘 becomes 두, 셋 becomes 세, '
    '넷 becomes 네, 열하나 becomes 열한 and 열둘 becomes 열두.',
  ),
  NumberHelpText('On the hour, say only the hour: 3:00 is 세 시.'),
  NumberHelpText(
    '반 means "half" and can replace 삼십 분 at half past the hour: 2:30 is 두 시 반 or '
    '두 시 삼십 분.',
  ),
  NumberHelpText(
    '오전 (AM) and 오후 (PM) go before the time:\n'
    '오전 아홉 시 (9:00 AM)\n'
    '오후 세 시 십오 분 (3:15 PM)\n'
    '오후 열한 시 반 (11:30 PM)',
  ),
]);

/// A bordered two-row table that scrolls sideways on narrow screens.
class _HelpTable extends StatelessWidget {
  final NumberHelpTable table;
  const _HelpTable(this.table);

  Widget _cell(String s, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEFEAFF)),
          children: [for (final n in table.numerals) _cell(n, bold: true)],
        ),
        TableRow(children: [for (final k in table.korean) _cell(k)]),
      ],
    ),
  );
}

/// Opens [help] in a scrollable dialog.
Future<void> showNumberHelp(BuildContext context, NumberHelp help) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    key: const ValueKey('number_help_dialog'),
    scrollable: true,
    title: Text(help.title, style: const TextStyle(fontWeight: FontWeight.w900)),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, b) in help.blocks.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          switch (b) {
            NumberHelpText(:final text) => Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.35),
            ),
            NumberHelpTable() => _HelpTable(b),
          },
        ],
      ],
    ),
    actions: [
      TextButton(
        key: const ValueKey('number_help_close'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Got it', style: TextStyle(fontSize: 17)),
      ),
    ],
  ),
);

/// The ❓ button that opens [help].
class NumberHelpButton extends StatelessWidget {
  final NumberHelp help;
  const NumberHelpButton(this.help, {super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'How these numbers work',
    onPressed: () => showNumberHelp(context, help),
    icon: const Text('❓', style: TextStyle(fontSize: 24)),
  );
}

/// The explainer for a pack id ('numbers' / 'native'), or null.
NumberHelp? numberHelpForPack(String id) => switch (id) {
  'numbers' => sinoNumberHelp,
  'native' => nativeNumberHelp,
  _ => null,
};
