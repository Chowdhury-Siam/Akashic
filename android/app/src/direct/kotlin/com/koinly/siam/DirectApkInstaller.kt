package com.koinly.siam

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File

/** APK installer used only by the direct/GitHub Android flavor. */
internal object DirectApkInstaller {
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

    fun installApk(activity: FlutterFragmentActivity, path: String): Boolean {
        val apkFile = File(path)
        if (!apkFile.exists()) return false
        val apkUri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", apkFile)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.grantUriPermission(activity.packageName, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(intent)
        return true
    }
}
