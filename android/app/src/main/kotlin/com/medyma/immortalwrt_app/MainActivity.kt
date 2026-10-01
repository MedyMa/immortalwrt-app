package com.medyma.immortalwrt_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.medyma.immortalwrt/appearance").setMethodCallHandler { call, result ->
            if (call.method != "accentColor") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                result.success(resources.getColor(android.R.color.system_accent1_500, theme))
            } else {
                result.success(null)
            }
        }
    }
}
