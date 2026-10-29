import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/main.dart';
import 'package:hangul_hooray/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('typing fields let Gboard use Korean and have no placeholder', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(appState.load);
    for (final game in [3, 4]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: UniqueKey(), game: game),
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      // enableSuggestions:false is sent to Android as VISIBLE_PASSWORD (Latin-only Gboard).
      expect(field.enableSuggestions, isTrue);
      expect(field.obscureText, isFalse);
      expect(field.readOnly, isFalse);
      expect(field.inputFormatters, isNull);
      expect(field.keyboardType, TextInputType.text);
      expect(field.decoration?.hintText, isNull);
      expect(field.decoration?.labelText, isNull);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.enableSuggestions, isTrue);
      expect(editable.keyboardType, TextInputType.text);
      // 3️⃣ shows its hint at start, but never a 💡 label (a prompt word such as
      // "Idea 💡" may legitimately contain one).
      final prompt =
          ((tester.state(find.byType(GameScreen)) as dynamic).currentRound).prompt as String;
      if (!prompt.contains('💡')) expect(find.textContaining('💡'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
