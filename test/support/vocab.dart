import 'dart:io';

import 'package:hangul_hooray/logic/ini_parser.dart';
import 'package:hangul_hooray/models/vocab_entry.dart';

String readVocabIndex() => File(vocabIndexAsset).readAsStringSync();
String readPackFile(String id) => File(packAsset(id)).readAsStringSync();

/// Every built-in word, loaded from `assets/vocab/` exactly like the app does.
List<VocabEntry> diskVocab() =>
    loadBuiltInVocab(readVocabIndex(), readPackFile);
