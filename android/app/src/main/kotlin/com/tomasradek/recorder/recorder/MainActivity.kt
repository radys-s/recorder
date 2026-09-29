package com.tomasradek.recorder.recorder

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Free space for the recorder's low-disk warning; Dart side:
        // lib/core/storage_info.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recorder/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    try {
                        result.success(StatFs(filesDir.absolutePath).availableBytes)
                    } catch (e: Exception) {
                        result.error("FAILED", "Free space is unknown", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
