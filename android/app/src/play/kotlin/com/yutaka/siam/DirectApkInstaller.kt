package com.yutaka.siam

import io.flutter.embedding.android.FlutterFragmentActivity

/** Play builds intentionally contain no APK installation implementation. */
internal object DirectApkInstaller {
    fun canInstallPackages(activity: FlutterFragmentActivity): Boolean = false
    fun openInstallPermissionSettings(activity: FlutterFragmentActivity) = Unit
    fun installApk(activity: FlutterFragmentActivity, path: String): Boolean = false
    fun installationStatus(activity: FlutterFragmentActivity, resumed: Boolean): Map<String, String> = mapOf("state" to "idle")
    fun onAppResumed(activity: FlutterFragmentActivity) = Unit
}
