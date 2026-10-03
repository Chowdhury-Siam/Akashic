package com.yutaka.siam

import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.Manifest
import android.content.Intent
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File

/** APK installer used only by the direct/GitHub Android flavor. */
internal object DirectApkInstaller {
    private const val statusStore = "yutaka_update_install_status"
    private const val completionChannel = "yutaka_update_completed"
    private const val completionTag = "yutaka_update_completed"
    private const val completionNotificationId = 903
    private const val requestLifetimeMillis = 30 * 60 * 1000L

    @Synchronized
    fun recordStatus(context: Context, state: String, message: String = "") {
        // Persist results so Flutter can read them after Android replaces the app.
        val editor = context.getSharedPreferences(statusStore, Context.MODE_PRIVATE).edit()
            .putString("state", state).putString("message", message)
        if (state == "failure") {
            editor.remove("expected_version").remove("requested_at").remove("session_id")
        }
        editor.commit()
    }

    private fun recordRequest(context: Context, state: String, expectedVersion: Long, sessionId: Int = -1) {
        context.getSharedPreferences(statusStore, Context.MODE_PRIVATE).edit()
            .putString("state", state).putString("message", "")
            .putLong("expected_version", expectedVersion)
            .putLong("requested_at", System.currentTimeMillis())
            .putInt("session_id", sessionId)
            .remove("completed_version").commit()
    }

    /** Do not let delayed callbacks replace a newer request or completed result. */
    @Synchronized
    fun acceptsSessionResult(context: Context, sessionId: Int): Boolean {
        val prefs = context.getSharedPreferences(statusStore, Context.MODE_PRIVATE)
        val expectedSession = prefs.getInt("session_id", -1)
        if (expectedSession >= 0) return expectedSession == sessionId
        // Older updater versions did not store a session ID. Accept their first
        // result, but reject duplicates after either completion path has run.
        return prefs.getLong("completed_version", -1) != BuildConfig.VERSION_CODE.toLong()
    }

    /** A replacement broadcast must belong to a recent update started in Yutaka. */
    @Synchronized
    fun finishUpdateAndReopen(context: Context, verifiedSession: Boolean = false, sessionId: Int = -1) {
        val prefs = context.getSharedPreferences(statusStore, Context.MODE_PRIVATE)
        val version = BuildConfig.VERSION_CODE.toLong()
        if (prefs.getLong("completed_version", -1) == version) return
        val expected = prefs.getLong("expected_version", -1)
        // Ignore a delayed result from an earlier session once a newer update
        // has started. The old updater has no marker, so its verified success
        // callback is still accepted on the first upgrade to this version.
        if (expected >= 0 && expected != version) return
        val expectedSession = prefs.getInt("session_id", -1)
        if (verifiedSession && expectedSession >= 0 && expectedSession != sessionId) return
        if (!verifiedSession) {
            val age = System.currentTimeMillis() - prefs.getLong("requested_at", 0)
            if (expected != version || age !in 0..requestLifetimeMillis) return
            if (prefs.getString("state", "idle") !in setOf("installing", "confirmation", "external")) return
        }
        // Keep this result until Flutter consumes it. Deduplicate the session
        // callback and MY_PACKAGE_REPLACED, which may arrive in either order.
        prefs.edit().putString("state", "success")
            .putString("message", "Yutaka updated successfully.")
            .putLong("completed_version", version)
            .remove("expected_version").remove("requested_at").remove("session_id").commit()

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        Toast.makeText(context, "Yutaka updated.", Toast.LENGTH_SHORT).show()
        if (launch == null) return
        // Android can silently block a background start without throwing. Post
        // the fallback first; onResume/onNewIntent removes it when the app opens.
        postCompletionNotification(context, launch)
        try {
            context.startActivity(launch)
        } catch (error: Exception) {
            Log.w("YutakaUpdater", "Android did not allow reopening after the update", error)
        }
    }

    private fun postCompletionNotification(context: Context, launch: Intent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) return
            val manager = NotificationManagerCompat.from(context)
            if (!manager.areNotificationsEnabled()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nativeManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nativeManager.createNotificationChannel(NotificationChannel(
                    completionChannel, "Completed Yutaka updates", NotificationManager.IMPORTANCE_LOW
                ))
            }
            val open = PendingIntent.getActivity(
                context, completionNotificationId, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notification = NotificationCompat.Builder(context, completionChannel)
                .setSmallIcon(R.drawable.ic_stat_yutaka)
                .setContentTitle("Yutaka updated")
                .setContentText("Tap to open Yutaka.")
                .setContentIntent(open)
                .addAction(0, "Open Yutaka", open)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(true)
                .build()
            manager.notify(completionTag, completionNotificationId, notification)
        } catch (error: Exception) {
            // Notification delivery must not turn a successful install into a failure.
            Log.w("YutakaUpdater", "Could not show the update completion notification", error)
        }
    }

    fun onAppResumed(activity: FlutterFragmentActivity) {
        NotificationManagerCompat.from(activity).cancel(completionTag, completionNotificationId)
    }

    @Suppress("DEPRECATION")
    private fun versionOf(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
    }

    fun installationStatus(activity: FlutterFragmentActivity, resumed: Boolean): Map<String, String> {
        val prefs = activity.getSharedPreferences(statusStore, Context.MODE_PRIVATE)
        val state = prefs.getString("state", "idle") ?: "idle"
        val message = prefs.getString("message", "") ?: ""
        if (state == "success" || state == "failure") {
            prefs.edit().remove("state").remove("message").apply()
            return mapOf("state" to state, "message" to message)
        }
        if (activity.packageManager.packageInstaller.mySessions.any { it.appPackageName == activity.packageName }) {
            return mapOf("state" to if (state == "confirmation") "confirmation" else "installing")
        }
        if (state == "external" && !resumed) return mapOf("state" to "external")
        // No active session remains. Do not infer success from an installer handoff.
        if (state == "external" && resumed) {
            prefs.edit().remove("state").remove("message")
                .remove("expected_version").remove("requested_at").remove("session_id").apply()
        }
        return mapOf("state" to "idle")
    }

    fun canInstallPackages(activity: FlutterFragmentActivity): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    fun openInstallPermissionSettings(activity: FlutterFragmentActivity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${activity.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
        }
    }

    @Synchronized
    fun installApk(activity: FlutterFragmentActivity, path: String): Boolean {
        val apkFile = File(path)
        if (!apkFile.isFile || apkFile.length() == 0L) return false
        @Suppress("DEPRECATION")
        val archive = activity.packageManager.getPackageArchiveInfo(apkFile.path, 0)
            ?: throw IllegalArgumentException("The download is not a valid APK.")
        require(archive.packageName == activity.packageName) { "The APK belongs to another app." }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return installSession(activity, apkFile, versionOf(archive))
        }
        val apkUri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.grantUriPermission(activity.packageName, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        recordRequest(activity, "external", versionOf(archive))
        try {
            activity.startActivity(intent)
        } catch (error: Exception) {
            recordStatus(activity, "failure", "Could not open Android’s installer. Retry from Updates.")
            throw error
        }
        return true
    }

    /** Android 12+ permits eligible self-updates without confirmation. */
    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private fun installSession(activity: FlutterFragmentActivity, apkFile: File, expectedVersion: Long): Boolean {
        val installer = activity.packageManager.packageInstaller
        // Avoid duplicate sessions if the app resumes or the user taps again.
        if (installer.mySessions.any { it.appPackageName == activity.packageName }) {
            recordStatus(activity, "installing")
            return true
        }
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(activity.packageName)
            setSize(apkFile.length())
            setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        recordRequest(activity, "installing", expectedVersion, sessionId)
        try {
            installer.openSession(sessionId).use { session ->
                apkFile.inputStream().use { input ->
                    session.openWrite("base.apk", 0, apkFile.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                // Android fills the result extras; restrict this mutable callback
                // to the explicit, non-exported receiver in the direct flavor.
                val sender = PendingIntent.getBroadcast(
                    activity, sessionId, Intent(activity, UpdateInstallReceiver::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                session.commit(sender.intentSender)
            }
            return true
        } catch (error: Exception) {
            recordStatus(activity, "failure", "Android could not install the update. Retry from Updates.")
            try {
                installer.abandonSession(sessionId)
            } catch (_: Exception) {
                // The session may already have been discarded by Android.
            }
            throw error
        }
    }
}
