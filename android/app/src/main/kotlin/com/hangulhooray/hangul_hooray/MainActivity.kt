package com.hangulhooray.hangul_hooray

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "michi/vibrate")
            .setMethodCallHandler { call, result ->
                if (call.method != "vibrate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val ms = (call.argument<Int>("ms") ?: 50).toLong()
                val amplitude = (call.argument<Int>("amplitude") ?: 255).coerceIn(1, 255)
                try {
                    val vibrator: Vibrator =
                        if (Build.VERSION.SDK_INT >= 31) {
                            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                                .defaultVibrator
                        } else {
                            @Suppress("DEPRECATION")
                            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        }
                    if (!vibrator.hasVibrator()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= 26) {
                        val amp = if (vibrator.hasAmplitudeControl()) amplitude
                                  else VibrationEffect.DEFAULT_AMPLITUDE
                        vibrator.vibrate(VibrationEffect.createOneShot(ms, amp))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(ms)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("vibrate", e.message, null)
                }
            }
    }
}
