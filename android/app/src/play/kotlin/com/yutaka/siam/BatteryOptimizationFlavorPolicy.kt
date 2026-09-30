package com.yutaka.siam

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity

/** Google Play flavor: never requests direct Doze exemption. */
internal object BatteryOptimizationFlavorPolicy {
    fun openSettings(activity: FlutterFragmentActivity): Boolean {
        return try {
            activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (_: Exception) {
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${activity.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
