import 'package:flutter_test/flutter_test.dart';
import 'package:hangul_hooray/data/app_state.dart';
import 'package:hangul_hooray/data/bundles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('upgrade: new packs start on, switched-off packs stay off', () async {
    final known = [...builtInBundles.map((b) => b.id), 'custom']..remove('time');
    SharedPreferences.setMockInitialValues({
      'known_bundles': known,
      'enabled_bundles': [...known]..remove('food'),
    });
    final s = AppState();
    await s.load();
    expect(s.enabledBundles.contains('food'), isFalse);
    expect(s.enabledBundles.contains('time'), isTrue);
    await s.setBundleEnabled('colours', false);
    final again = AppState();
    await again.load();
    expect(again.enabledBundles.contains('colours'), isFalse);
    expect(again.enabledBundles.contains('animals'), isTrue);
  });

  test('fresh install: everything on except the new noun packs', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    expect(s.enabledBundles, {
      ...builtInBundles.map((b) => b.id).where((id) => !defaultOffBundles.contains(id)),
      'custom',
    });
  });
}
