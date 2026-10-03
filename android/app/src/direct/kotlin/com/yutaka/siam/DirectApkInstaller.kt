package com.yutaka.siam

import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File

/** APK installer used only by the direct/GitHub Android flavor. */
internal object DirectApkInstaller {
    private const val statusStore = "yutaka_update_install_status"

    fun recordStatus(context: Context, state: String, message: String = "") {
        // Persist results so Flutter can read them after Android replaces the app.
        context.getSharedPreferences(statusStore, Context.MODE_PRIVATE).edit()
            .putString("state", state).putString("message", message).commit()
    }

    fun installationStatus(activity: FlutterFragmentActivity, resumed: Boolean): Map<String, String> {
        val prefs = activity.getSharedPreferences(statusStore, Context.MODE_PRIVATE)
        val state = prefs.getString("state", "idle") ?: "idle"
        val message = prefs.getString("message", "") ?: ""
        if (state == "success" || state == "failure") {
            prefs.edit().clear().apply()
            return mapOf("state" to state, "message" to message)
        }
        if (activity.packageManager.packageInstaller.mySessions.any { it.appPackageName == activity.packageName }) {
            return mapOf("state" to if (state == "confirmation") "confirmation" else "installing")
        }
        if (state == "external" && !resumed) return mapOf("state" to "external")
        // No active session remains. Do not infer success from an installer handoff.
        if (state == "external" && resumed) prefs.edit().clear().apply()
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return installSession(activity, apkFile)
        }
        val apkUri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.grantUriPermission(activity.packageName, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(intent)
        recordStatus(activity, "external")
        return true
    }

    /** Android 12+ permits eligible self-updates without confirmation. */
    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private fun installSession(activity: FlutterFragmentActivity, apkFile: File): Boolean {
        val installer = activity.packageManager.packageInstaller
        // Avoid duplicate sessions if the app resumes or the user taps again.
        if (installer.mySessions.any { it.appPackageName == activity.packageName }) {
            recordStatus(activity, "installing")
            return true
        }
        val archive = activity.packageManager.getPackageArchiveInfo(apkFile.path, 0)
            ?: throw IllegalArgumentException("The download is not a valid APK.")
        require(archive.packageName == activity.packageName) { "The APK belongs to another app." }
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(activity.packageName)
            setSize(apkFile.length())
            setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        recordStatus(activity, "installing")
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
            installer.abandonSession(sessionId)
            throw error
        }
    }
}
