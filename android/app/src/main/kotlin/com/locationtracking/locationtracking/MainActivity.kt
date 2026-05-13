package com.locationtracking.locationtracking

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val driverId = call.argument<String>("driverId")
                    if (driverId.isNullOrBlank()) {
                        result.error("missing_driver_id", "Driver id is required.", null)
                        return@setMethodCallHandler
                    }

                    val intent = DriverLocationService.startIntent(this, driverId)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    startService(DriverLocationService.stopIntent(this))
                    result.success(true)
                }
                "status" -> result.success(DriverLocationService.status(this))
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val CHANNEL = "com.locationtracking.locationtracking/driver_location"
    }
}
