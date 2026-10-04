package com.medyma.immortalwrt_app

import android.os.Build
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appearanceChannel: MethodChannel? = null

    private fun appearance(): Map<String, Any?> = mapOf(
        "dark" to ((resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES),
        "accent" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            resources.getColor(android.R.color.system_accent1_500, theme) else null
    )

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        appearanceChannel?.invokeMethod("appearanceChanged", appearance())
    }

    override fun onResume() {
        super.onResume()
        appearanceChannel?.invokeMethod("appearanceChanged", appearance())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appearanceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.medyma.immortalwrt/appearance")
        appearanceChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getAppearance") {
                result.success(appearance())
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        appearanceChannel?.setMethodCallHandler(null)
        appearanceChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
