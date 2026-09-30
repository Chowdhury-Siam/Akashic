package com.yutaka.siam

import android.app.NotificationManager
import android.content.Context
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

private const val nativeUpdatePeriodicWork = "yutaka-native-periodic-update-check"
private const val nativeUpdateImmediateWork = "yutaka-native-immediate-update-check"
private const val updateNotificationId = 902

/**
 * Google Play builds never poll GitHub for application updates.
 *
 * Cancel the direct-build jobs in case a user migrates from the sideloaded APK
 * to the Play-distributed package with the same application ID/signing lineage.
 */
internal object NativeUpdateCheckScheduler {
    fun sync(context: Context, enabledOverride: Boolean? = null) {
        val appContext = context.applicationContext
        val manager = WorkManager.getInstance(appContext)
        manager.cancelUniqueWork(nativeUpdatePeriodicWork)
        manager.cancelUniqueWork(nativeUpdateImmediateWork)
        (appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(updateNotificationId)
    }
}

/**
 * Compatibility no-op for an already-persisted direct-build WorkManager row.
 * It prevents a class-not-found failure before NativeUpdateCheckScheduler has
 * a chance to cancel the legacy job after upgrading to the Play flavor.
 */
class UpdateCheckWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result = Result.success()
}
