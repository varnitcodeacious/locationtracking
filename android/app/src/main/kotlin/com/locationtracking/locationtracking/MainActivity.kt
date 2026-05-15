package com.locationtracking.locationtracking

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startService(Intent(this, TaskRemovedWatcherService::class.java))
        } catch (_: Throwable) {
        }
    }
}
