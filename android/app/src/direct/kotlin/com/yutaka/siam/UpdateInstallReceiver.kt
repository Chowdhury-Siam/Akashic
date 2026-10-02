package com.yutaka.siam

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import android.widget.Toast

/** Receives results even if Android closes Yutaka while replacing its APK. */
class UpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // Android retains the final decision; show its confirmation if needed.
                @Suppress("DEPRECATION")
                val confirmation = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                try {
                    requireNotNull(confirmation) { "Missing installation confirmation." }
                    confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirmation)
                } catch (error: Exception) {
                    val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
                    if (sessionId >= 0) {
                        try {
                            context.packageManager.packageInstaller.abandonSession(sessionId)
                        } catch (_: Exception) {
                            // Android may already have discarded the session.
                        }
                    }
                    Log.e("YutakaUpdater", "Could not open update confirmation", error)
                    Toast.makeText(context, "Could not open update confirmation. Retry from Updates.", Toast.LENGTH_LONG).show()
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                Toast.makeText(context, "Yutaka updated.", Toast.LENGTH_SHORT).show()
            }
            else -> {
                Log.w("YutakaUpdater", intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "Update failed")
                Toast.makeText(context, "Update was cancelled or failed. Retry from Updates.", Toast.LENGTH_LONG).show()
            }
        }
    }
}
