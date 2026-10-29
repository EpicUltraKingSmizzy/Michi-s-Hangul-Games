import 'package:flutter/material.dart';

import 'common.dart';

/// Phone-style layout: 1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ✔
const keypadRows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['⌫', '0', '✔'],
];

/// Big, thumb-sized digit keys for the number-button rounds.
class NumberKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  const NumberKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  static const _digitColor = Color(0xFF7B5CFF);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final row in keypadRows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              for (final k in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: SizedBox(
                      height: 64,
                      child: BouncyButton(
                        key: ValueKey('key_$k'),
                        color: switch (k) {
                          '⌫' => const Color(0xFF9E9E9E),
                          '✔' => const Color(0xFF3DDC84),
                          _ => _digitColor,
                        },
                        padding: EdgeInsets.zero,
                        radius: 18,
                        onTap: switch (k) {
                          '⌫' => onBackspace,
                          '✔' => onSubmit,
                          _ => () => onDigit(k),
                        },
                        child: Center(
                          child: Text(
                            k,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
