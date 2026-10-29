import 'dart:async';

import 'support/vocab.dart';

/// Loads the built-in packs from `assets/vocab/` before every test file, so
/// `builtInBundles` is populated just as it is after the app starts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  diskVocab();
  await testMain();
}
