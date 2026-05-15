package com.locationtracking.locationtracking

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

/**
 * Receives onTaskRemoved when the user clears this app from the recent-tasks list.
 * That callback exists on Service, not Application.
 *
 * Preference key matches Flutter SharedPreferences on Android: flutter.last_app_state_label.
 */
class TaskRemovedWatcherService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("flutter.last_app_state_label", "swiped").commit()
        } catch (_: Throwable) {
        }
        stopSelf()
    }
}
