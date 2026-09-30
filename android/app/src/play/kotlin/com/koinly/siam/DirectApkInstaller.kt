package com.koinly.siam

import io.flutter.embedding.android.FlutterFragmentActivity

/** Play builds intentionally contain no APK installation implementation. */
internal object DirectApkInstaller {
    fun canInstallPackages(activity: FlutterFragmentActivity): Boolean = false
    fun openInstallPermissionSettings(activity: FlutterFragmentActivity) = Unit
    fun installApk(activity: FlutterFragmentActivity, path: String): Boolean = false
}
