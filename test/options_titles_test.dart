import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Options: no tile title starts with an emoji (the emoji sits on the left)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(appState.load);
    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await tester.pump();
    final titles = [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.style?.fontSize == 20 && t.style?.fontWeight == FontWeight.w900) t.data ?? '',
    ];
    for (final want in [
      'Shuffle games',
      'Typing repetitions',
      'Number length',
      'Number range',
      'Sentence difficulty',
      'Digital time',
    ]) {
      expect(titles, contains(want));
    }
    final leading = RegExp(r'^[^\p{L}\p{N}]', unicode: true);
    expect(titles.where(leading.hasMatch), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
