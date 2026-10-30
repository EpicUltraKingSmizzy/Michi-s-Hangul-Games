import 'dart:io';

import 'package:hangul_hooray/data/bundles.dart';
import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/logic/sentences.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

String readVocabIndex() => File(vocabIndexAsset).readAsStringSync();
String readPackFile(String id) => File(packAsset(id)).readAsStringSync();

/// Every built-in word, loaded from `assets/vocab/` exactly like the app does.
List<VocabEntry> diskVocab() =>
    loadBuiltInVocab(readVocabIndex(), readPackFile);

/// The 🏗️ sentence data, parsed and linked exactly like the app does.
SentenceBank diskSentences() {
  final ids = parsePackIndex(readVocabIndex());
  final verbIds = ids.where(isVerbPackId).toSet();
  final polite = {for (final id in verbIds) ...parsePoliteForms(readPackFile(id))};
  final bank = SentenceBank.parse(
    File(sentenceNounsAsset).readAsStringSync(),
    File(sentenceVerbsAsset).readAsStringSync(),
    polite: polite,
  );
  final errors = bank.link(diskVocab(), verbIds);
  if (errors.isNotEmpty) throw StateError(errors.join('\n'));
  return bank;
}
