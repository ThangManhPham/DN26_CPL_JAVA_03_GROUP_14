package com.ourspace.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ourspace.mobile/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showPhoto" -> {
                        val bytes = call.arguments as? ByteArray
                        if (bytes == null || bytes.size > 10 * 1024 * 1024) {
                            result.error("INVALID_PHOTO", "Photo cache is invalid", null)
                        } else {
                            OurSpaceWidgetProvider.save(this, bytes)
                            result.success(null)
                        }
                    }
                    "clear" -> {
                        OurSpaceWidgetProvider.clear(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
