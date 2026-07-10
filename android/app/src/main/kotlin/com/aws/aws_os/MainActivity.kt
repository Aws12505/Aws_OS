package com.aws.aws_os

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // App-clone channels (Stage 3): installed apps + Shizuku for OBB/data.
        MethodChannel(messenger, AppsChannel.CHANNEL)
            .setMethodCallHandler(AppsChannel(applicationContext))
        MethodChannel(messenger, ShizukuChannel.CHANNEL)
            .setMethodCallHandler(ShizukuChannel(applicationContext))

        // Local sharing: deep-links to system network settings for guided hotspot.
        MethodChannel(messenger, "com.aws.aws_os/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHotspotSettings" -> {
                        if (!openTetherSettings()) {
                            startActivity(
                                Intent(Settings.ACTION_WIRELESS_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                        result.success(null)
                    }
                    "openWifiSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_WIFI_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openTetherSettings(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN)
            intent.setClassName("com.android.settings", "com.android.settings.TetherSettings")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
