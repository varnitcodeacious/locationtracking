package com.locationtracking.locationtracking

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.FirebaseApp
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue

class DriverLocationService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var driverId: String? = null

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let(::uploadLocation)
        }
    }

    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopLocationUpdates()
                markOffline()
                saveServiceState(isRunning = false, driverId = driverId)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                driverId = intent.getStringExtra(EXTRA_DRIVER_ID)
                if (driverId.isNullOrBlank() || !hasLocationPermission()) {
                    saveServiceState(isRunning = false, driverId = driverId)
                    stopSelf()
                    return START_NOT_STICKY
                }

                saveServiceState(isRunning = true, driverId = driverId)
                startForeground(NOTIFICATION_ID, buildNotification())
                startLocationUpdates()
            }
            else -> {
                if (!prefs().getBoolean(KEY_IS_RUNNING, false) || !hasLocationPermission()) {
                    stopSelf()
                    return START_NOT_STICKY
                }

                driverId = prefs().getString(KEY_DRIVER_ID, null)
                if (driverId.isNullOrBlank()) {
                    saveServiceState(isRunning = false, driverId = null)
                    stopSelf()
                    return START_NOT_STICKY
                }

                startForeground(NOTIFICATION_ID, buildNotification())
                startLocationUpdates()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopLocationUpdates()
        super.onDestroy()
    }

    private fun startLocationUpdates() {
        if (!hasLocationPermission()) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL_MS)
            .setMinUpdateIntervalMillis(FASTEST_UPDATE_INTERVAL_MS)
            .setMinUpdateDistanceMeters(MIN_DISTANCE_METERS)
            .build()

        fusedLocationClient.requestLocationUpdates(request, locationCallback, mainLooper)
    }

    private fun stopLocationUpdates() {
        if (::fusedLocationClient.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
    }

    private fun uploadLocation(location: Location) {
        val currentDriverId = driverId ?: return
        val db = FirebaseDatabase.getInstance()

        val liveUpdate = mapOf(
            "lat" to location.latitude,
            "lng" to location.longitude,
            "heading" to location.bearing,
            "speed" to location.speed,
            "last_updated" to ServerValue.TIMESTAMP,
            "is_online" to true
        )

        db.getReference("live_drivers").child(currentDriverId).setValue(liveUpdate)
        saveLastLocation(location)
    }

    private fun markOffline() {
        val currentDriverId = driverId ?: prefs().getString(KEY_DRIVER_ID, null) ?: return
        FirebaseDatabase.getInstance()
            .getReference("live_drivers")
            .child(currentDriverId)
            .updateChildren(
                mapOf(
                    "is_online" to false,
                    "last_updated" to ServerValue.TIMESTAMP
                )
            )
    }

    private fun buildNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Driver location active")
            .setContentText("Sharing live location while you are on duty.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    packageManager.getLaunchIntentForPackage(packageName),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Driver location",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun saveServiceState(isRunning: Boolean, driverId: String?) {
        prefs().edit()
            .putBoolean(KEY_IS_RUNNING, isRunning)
            .putString(KEY_DRIVER_ID, driverId)
            .apply()
    }

    private fun saveLastLocation(location: Location) {
        prefs().edit()
            .putFloat(KEY_LAST_LAT, location.latitude.toFloat())
            .putFloat(KEY_LAST_LNG, location.longitude.toFloat())
            .apply()
    }

    private fun prefs() = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val ACTION_START = "com.locationtracking.locationtracking.START_DRIVER_LOCATION"
        private const val ACTION_STOP = "com.locationtracking.locationtracking.STOP_DRIVER_LOCATION"
        private const val EXTRA_DRIVER_ID = "driverId"
        private const val CHANNEL_ID = "driver_location_service"
        private const val NOTIFICATION_ID = 3201
        private const val PREFS_NAME = "driver_location_service"
        private const val KEY_IS_RUNNING = "isRunning"
        private const val KEY_DRIVER_ID = "driverId"
        private const val KEY_LAST_LAT = "lastLat"
        private const val KEY_LAST_LNG = "lastLng"
        private const val UPDATE_INTERVAL_MS = 10_000L
        private const val FASTEST_UPDATE_INTERVAL_MS = 5_000L
        private const val MIN_DISTANCE_METERS = 10f

        fun startIntent(context: Context, driverId: String) =
            Intent(context, DriverLocationService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_DRIVER_ID, driverId)

        fun stopIntent(context: Context) =
            Intent(context, DriverLocationService::class.java).setAction(ACTION_STOP)

        fun status(context: Context): Map<String, Any?> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val hasLastLocation = prefs.contains(KEY_LAST_LAT) && prefs.contains(KEY_LAST_LNG)
            return mapOf(
                "isRunning" to prefs.getBoolean(KEY_IS_RUNNING, false),
                "driverId" to prefs.getString(KEY_DRIVER_ID, null),
                "lat" to if (hasLastLocation) prefs.getFloat(KEY_LAST_LAT, 0f).toDouble() else null,
                "lng" to if (hasLastLocation) prefs.getFloat(KEY_LAST_LNG, 0f).toDouble() else null
            )
        }
    }
}
