package com.turbometa.rayban.services

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import ai.picovoice.porcupine.Porcupine
import ai.picovoice.porcupine.PorcupineManager
import ai.picovoice.porcupine.PorcupineManagerCallback
import ai.picovoice.porcupine.PorcupineException
import android.content.BroadcastReceiver
import android.content.IntentFilter
import com.turbometa.rayban.MainActivity
import com.turbometa.rayban.R

/**
 * Porcupine Wake Word Detection Service
 * Foreground service for continuous wake word detection ("Jarvis")
 * Triggers Quick Vision when wake word is detected
 */
class PorcupineWakeWordService : Service() {

    companion object {
        private const val TAG = "PorcupineWakeWordService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "porcupine_wake_word_channel"

        // Action for wake word detected broadcast
        const val ACTION_WAKE_WORD_DETECTED = "com.turbometa.rayban.WAKE_WORD_DETECTED"
        const val EXTRA_KEYWORD_INDEX = "keyword_index"

        // Service control actions
        const val ACTION_START = "com.turbometa.rayban.START_WAKE_WORD"
        const val ACTION_STOP = "com.turbometa.rayban.STOP_WAKE_WORD"

        // Picovoice Access Key - User needs to get this from https://console.picovoice.ai/
        // This should be stored securely (e.g., in EncryptedSharedPreferences)
        private const val PREFS_NAME = "porcupine_prefs"
        private const val KEY_ACCESS_KEY = "porcupine_access_key"

        // Debounce: prevent multiple triggers within this time window
        private const val DEBOUNCE_MS = 10000L // 10 seconds

        fun getAccessKey(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(KEY_ACCESS_KEY, null)
        }

        fun saveAccessKey(context: Context, accessKey: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_ACCESS_KEY, accessKey).apply()
        }

        fun hasAccessKey(context: Context): Boolean {
            return !getAccessKey(context).isNullOrBlank()
        }
    }

    private var porcupineManager: PorcupineManager? = null
    private var isListening = false

    // Debounce: track last trigger time to prevent multiple rapid triggers
    @Volatile
    private var lastTriggerTime = 0L
    @Volatile
    private var isProcessing = false

    // Broadcast receiver to listen for QuickVisionService completion
    private val quickVisionStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val status = intent?.getStringExtra(QuickVisionService.EXTRA_STATUS)
            Log.d(TAG, "QuickVision status received: $status")
            if (status == "finished" || status == "error") {
                isProcessing = false
                Log.d(TAG, "Reset isProcessing to false")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Register receiver to listen for QuickVisionService status
        val filter = IntentFilter(QuickVisionService.ACTION_QUICK_VISION_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(quickVisionStatusReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(quickVisionStatusReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startWakeWordDetection()
            ACTION_STOP -> stopWakeWordDetection()
            else -> startWakeWordDetection()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(quickVisionStatusReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        stopWakeWordDetection()
        super.onDestroy()
    }

    private fun startWakeWordDetection() {
        if (isListening) {
            Log.d(TAG, "Already listening for wake word")
            return
        }

        // Check microphone permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "Microphone permission not granted")
            stopSelf()
            return
        }

        // Get Picovoice access key
        val accessKey = getAccessKey(this)
        if (accessKey.isNullOrBlank()) {
            Log.e(TAG, "Picovoice access key not configured")
            stopSelf()
            return
        }

        try {
            // Create Porcupine manager with built-in "JARVIS" wake word
            porcupineManager = PorcupineManager.Builder()
                .setAccessKey(accessKey)
                .setKeyword(Porcupine.BuiltInKeyword.JARVIS)
                .setSensitivity(0.7f) // Adjust sensitivity (0.0 to 1.0)
                .build(this, porcupineCallback)

            porcupineManager?.start()
            isListening = true

            // Start foreground service with notification
            startForeground(NOTIFICATION_ID, createNotification())

            Log.d(TAG, "Wake word detection started - listening for 'JARVIS'")

        } catch (e: PorcupineException) {
            Log.e(TAG, "Failed to start Porcupine: ${e.message}")
            stopSelf()
        }
    }

    private fun stopWakeWordDetection() {
        try {
            porcupineManager?.stop()
            porcupineManager?.delete()
            porcupineManager = null
            isListening = false
            Log.d(TAG, "Wake word detection stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Porcupine: ${e.message}")
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private val porcupineCallback = PorcupineManagerCallback { keywordIndex ->
        val currentTime = System.currentTimeMillis()

        // Debounce: ignore if already processing or triggered recently
        if (isProcessing) {
            Log.d(TAG, "Wake word detected but already processing, ignoring")
            return@PorcupineManagerCallback
        }

        if (currentTime - lastTriggerTime < DEBOUNCE_MS) {
            Log.d(TAG, "Wake word detected but within debounce window (${currentTime - lastTriggerTime}ms), ignoring")
            return@PorcupineManagerCallback
        }

        Log.d(TAG, "Wake word detected! Keyword index: $keywordIndex")
        lastTriggerTime = currentTime
        isProcessing = true

        // Broadcast wake word detection
        val intent = Intent(ACTION_WAKE_WORD_DETECTED).apply {
            putExtra(EXTRA_KEYWORD_INDEX, keywordIndex)
            setPackage(packageName)
        }
        sendBroadcast(intent)

        // Trigger Quick Vision
        triggerQuickVision()
    }

    private fun triggerQuickVision() {
        Log.d(TAG, "Triggering Quick Vision...")

        // Start QuickVisionService to capture and analyze image
        val quickVisionIntent = Intent(this, QuickVisionService::class.java).apply {
            action = QuickVisionService.ACTION_CAPTURE_AND_ANALYZE
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(quickVisionIntent)
        } else {
            startService(quickVisionIntent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Quick Vision Wake Word",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Listening for wake word to trigger Quick Vision"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val stopIntent = Intent(this, PorcupineWakeWordService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Quick Vision Active")
            .setContentText("Say \"Jarvis\" to identify what you see")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
