import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short vibrations for right / wrong answers.
///
/// Android: a tiny platform channel to the system Vibrator (needs the VIBRATE
/// permission, no network), so the buzz works even when the phone's "touch
/// feedback" setting is off. Elsewhere it falls back to HapticFeedback.
class Buzz {
  static const _channel = MethodChannel('michi/vibrate');

  /// Right answer: a firm 70 ms buzz.
  static Future<void> right() => _buzz(70, 255, HapticFeedback.heavyImpact);

  /// Wrong answer: a light 25 ms tick.
  static Future<void> wrong() => _buzz(25, 70, HapticFeedback.lightImpact);

  static Future<void> _buzz(int ms, int amplitude, Future<void> Function() fallback) async {
    if (kIsWeb) return; // no vibration on the web
    try {
      await _channel.invokeMethod('vibrate', {'ms': ms, 'amplitude': amplitude});
    } on MissingPluginException {
      await fallback();
    } on PlatformException {
      await fallback();
    }
  }
}
