package cc.merr.inout

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

class DufsForegroundService : Service() {

    private var dufsProcess: Process? = null

    companion object {
        private const val TAG = "inout"
        private const val CHANNEL_ID = "inout_server"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning = false
            private set
        @Volatile
        var currentPort = 0
            private set
        @Volatile
        var currentPath = ""
            private set
        @Volatile
        var lastError: String? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra("port", 0) ?: 0
        val path = intent?.getStringExtra("path") ?: ""
        val args = intent?.getStringArrayExtra("args") ?: emptyArray()

        if (port == 0 || path.isEmpty()) {
            Log.w(TAG, "Invalid start request: port=$port path=$path")
            stopSelf()
            return START_NOT_STICKY
        }

        // Already running with same config — no-op
        if (isRunning && port == currentPort && path == currentPath) {
            Log.d(TAG, "Already running on port=$port, skip")
            return START_STICKY
        }

        // Kill existing process if any
        killDufs()

        // Start new process (order matters: process first, state after)
        lastError = null
        val success = startDufs(port, path, args)
        if (!success) {
            Log.e(TAG, "Failed to start dufs, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        // Process started successfully — now update state
        currentPort = port
        currentPath = path
        isRunning = true

        val notification = buildNotification(port, path)
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "Service started: port=$port path=$path")
        return START_STICKY
    }

    /**
     * Start dufs process in a background thread with startup verification.
     * Returns true if process is alive after verification.
     */
    private fun startDufs(port: Int, path: String, args: Array<String>): Boolean {
        return try {
            val nativeLibDir = applicationInfo.nativeLibraryDir
            val dufsBin = "$nativeLibDir/libdufs.so"

            val fullArgs = mutableListOf(dufsBin)
            fullArgs.addAll(args)

            Log.d(TAG, "Starting dufs: ${fullArgs.joinToString(" ")}")

            val pb = ProcessBuilder(fullArgs)
            pb.directory(java.io.File(path))
            pb.redirectErrorStream(true)
            dufsProcess = pb.start()

            // Startup verification: wait 300ms then check if process is still alive
            Thread.sleep(300)
            val alive = try {
                dufsProcess?.exitValue()
                false // exitValue() didn't throw = process has exited
            } catch (e: IllegalThreadStateException) {
                true // thrown = process still running
            }

            if (!alive) {
                lastError = "dufs process exited immediately after start"
                Log.e(TAG, lastError)
                dufsProcess = null
                false
            } else {
                Log.d(TAG, "dufs verified alive on port=$port")
                true
            }
        } catch (e: Exception) {
            lastError = "Failed to start dufs: ${e.message}"
            Log.e(TAG, lastError, e)
            dufsProcess = null
            false
        }
    }

    private fun killDufs() {
        try {
            dufsProcess?.destroy()
            // Force kill on Android 8+ if destroy() didn't work
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try { dufsProcess?.destroyForcibly() } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        dufsProcess = null
        isRunning = false
        currentPort = 0
        currentPath = ""
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Service destroying, stopping dufs")
        killDufs()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "inout Server",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "inout 文件分享服务运行中"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(port: Int, path: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("inout 文件分享")
            .setContentText("服务运行中 (端口 $port)")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
