import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device Korean text-to-speech (no network).
class Speaker {
  Speaker._();
  static final Speaker instance = Speaker._();

  final FlutterTts _tts = FlutterTts();

  /// Tests: when set, every requested utterance is recorded here.
  @visibleForTesting
  static List<String>? debugSpoken;
  bool _ready = false;
  bool? _koreanAvailable;

  Completer<bool>? _done;
  Completer<void>? _started;

  /// Ends the pending utterance: [ok] true = finished (or superseded),
  /// false = TTS failed / unavailable.
  void _finish([bool ok = true]) {
    final d = _done;
    _done = null;
    _started = null;
    if (d != null && !d.isCompleted) d.complete(ok);
  }

  /// Completion / cancel only count once *this* utterance has started, so a
  /// late cancel from stopping the previous one can't end it early.
  void _onEnd() {
    if (_started?.isCompleted ?? true) _finish();
  }

  void _onStart() {
    final st = _started;
    if (st != null && !st.isCompleted) st.complete();
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      _tts.setStartHandler(_onStart);
      _tts.setCompletionHandler(_onEnd);
      _tts.setCancelHandler(_onEnd);
      _tts.setErrorHandler((_) => _finish(false));
      final avail = await _tts.isLanguageAvailable('ko-KR');
      _koreanAvailable = avail == true || avail == 1;
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
    } catch (_) {
      _koreanAvailable = false;
    }
  }

  /// Speaks [text]. Returns false if no Korean voice seems to be installed.
  Future<bool> speak(String text) async {
    debugSpoken?.add(text);
    await _init();
    _finish(); // a newer utterance supersedes any pending one
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      return false;
    }
    return _koreanAvailable ?? true;
  }

  /// Speaks [text] and reports progress: [SpeechTracking.started] fires when
  /// the engine starts talking, [SpeechTracking.finished] gives true when it
  /// is done and false if TTS failed or no Korean voice is available.
  /// Callers should still cap the wait (see WinPause).
  SpeechTracking speakAndWait(String text) {
    debugSpoken?.add(text);
    final done = Completer<bool>();
    final started = Completer<void>();
    if (text.trim().isEmpty) {
      done.complete(false);
      return SpeechTracking(started.future, done.future);
    }
    () async {
      await _init();
      _finish();
      if (_koreanAvailable == false) return done.complete(false);
      _done = done;
      _started = started;
      try {
        await _tts.stop();
        await _tts.speak(text);
      } catch (_) {
        if (identical(_done, done)) _finish(false);
      }
    }();
    return SpeechTracking(started.future, done.future);
  }
}

/// Progress of one utterance.
class SpeechTracking {
  const SpeechTracking(this.started, this.finished);
  final Future<void> started;
  final Future<bool> finished;
}

final _hangul = RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]');
bool containsHangul(String s) => _hangul.hasMatch(s);
