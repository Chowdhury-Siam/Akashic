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
        val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
        if (!DirectApkInstaller.acceptsSessionResult(context, sessionId)) return
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                DirectApkInstaller.recordStatus(context, "confirmation")
                // Android retains the final decision; show its confirmation if needed.
                @Suppress("DEPRECATION")
                val confirmation = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                try {
                    requireNotNull(confirmation) { "Missing installation confirmation." }
                    confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirmation)
                } catch (error: Exception) {
                    if (sessionId >= 0) {
                        try {
                            context.packageManager.packageInstaller.abandonSession(sessionId)
                        } catch (_: Exception) {
                            // Android may already have discarded the session.
                        }
                    }
                    Log.e("YutakaUpdater", "Could not open update confirmation", error)
                    DirectApkInstaller.recordStatus(context, "failure", "Could not open update confirmation. Retry from Updates.")
                    Toast.makeText(context, "Could not open update confirmation. Retry from Updates.", Toast.LENGTH_LONG).show()
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                // A preapproval success is not an installed update.
                if (intent.getBooleanExtra(PackageInstaller.EXTRA_PRE_APPROVAL, false)) return
                if (intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME) != context.packageName) return
                DirectApkInstaller.finishUpdateAndReopen(
                    context, verifiedSession = true, sessionId = sessionId
                )
            }
            else -> {
                val cancelled = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1) == PackageInstaller.STATUS_FAILURE_ABORTED
                DirectApkInstaller.recordStatus(context, "failure", if (cancelled) "Installation was cancelled." else "Android could not install the update. Retry from Updates.")
                Log.w("YutakaUpdater", intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "Update failed")
                Toast.makeText(context, "Update was cancelled or failed. Retry from Updates.", Toast.LENGTH_LONG).show()
            }
        }
    }
}

/** Covers older external installers and devices that deliver replacement first. */
class UpdateReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            DirectApkInstaller.finishUpdateAndReopen(context)
        }
    }
}
