package com.yutaka.siam

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.DocumentsContract
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity: FlutterFragmentActivity() {
    private val updaterChannel = "com.yutaka.siam/updater"
    private val updateBackgroundChannel = "com.yutaka.siam/update_background"
    private val backupStorageChannel = "com.yutaka.siam/backup_storage"
    private val backgroundPermissionsChannel = "com.yutaka.siam/background_permissions"
    private val backupDirectoryRequestCode = 4208
    private var pendingBackupDirectoryResult: MethodChannel.Result? = null
    private val playUpdateManager by lazy { AppUpdateManagerFactory.create(this) }
    private val playUpdateLauncher = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) {
        // Google Play owns the update UI. Yutaka rechecks availability when the
        // activity resumes, so cancellation/failure never leaves stale state.
    }
    private val flexibleUpdateListener = InstallStateUpdatedListener { state ->
        if (state.installStatus() == InstallStatus.DOWNLOADED) {
            playUpdateManager.completeUpdate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeUpdateCheckScheduler.sync(this, BuildConfig.DISTRIBUTION == "direct")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateBackgroundChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    NativeUpdateCheckScheduler.sync(this, enabled && BuildConfig.DISTRIBUTION == "direct")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "distribution" -> result.success(BuildConfig.DISTRIBUTION)
                "checkGooglePlayUpdate" -> checkGooglePlayUpdate(result)
                "startGooglePlayUpdate" -> startGooglePlayUpdate(result)
                "installationStatus" -> result.success(DirectApkInstaller.installationStatus(this, call.argument<Boolean>("resumed") == true))
                "canInstallPackages" -> result.success(BuildConfig.DISTRIBUTION == "direct" && DirectApkInstaller.canInstallPackages(this))
                "openInstallPermissionSettings" -> {
                    if (BuildConfig.DISTRIBUTION == "direct") DirectApkInstaller.openInstallPermissionSettings(this)
                    result.success(null)
                }
                "installApk" -> {
                    if (BuildConfig.DISTRIBUTION != "direct") {
                        result.success(false)
                    } else {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing_path", "APK path is missing.", null)
                        } else {
                            // Stage the APK off Flutter's UI thread.
                            Thread {
                                try {
                                    val started = DirectApkInstaller.installApk(this, path)
                                    runOnUiThread { result.success(started) }
                                } catch (error: Exception) {
                                    runOnUiThread { result.error("install_failed", error.message, null) }
                                }
                            }.start()
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundPermissionsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "deviceTimeZoneId" -> result.success(TimeZone.getDefault().id)
                "openBatteryOptimizationSettings" -> result.success(openBatteryOptimizationSettings())
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupStorageChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> pickBackupDirectory(result)
                "canWrite" -> {
                    val uri = call.argument<String>("uri")
                    result.success(!uri.isNullOrBlank() && canWriteBackupDirectory(Uri.parse(uri)))
                }
                "writeFile" -> {
                    val uri = call.argument<String>("uri")
                    val name = call.argument<String>("name")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (uri.isNullOrBlank() || name.isNullOrBlank() || bytes == null) {
                        result.error("invalid_arguments", "Backup folder, file name, or bytes are missing.", null)
                    } else {
                        try {
                            writeBackupFile(Uri.parse(uri), name, bytes)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("backup_write_failed", error.message ?: "Could not write backup file.", null)
                        }
                    }
                }
                "listFiles" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.error("missing_uri", "Backup folder is missing.", null)
                    } else {
                        try {
                            result.success(listBackupFiles(Uri.parse(uri)))
                        } catch (error: Exception) {
                            result.error("backup_list_failed", error.message ?: "Could not list backup files.", null)
                        }
                    }
                }
                "deleteFile" -> {
                    val uri = call.argument<String>("uri")
                    val name = call.argument<String>("name")
                    if (uri.isNullOrBlank() || name.isNullOrBlank()) {
                        result.error("invalid_arguments", "Backup folder or file name is missing.", null)
                    } else {
                        try {
                            deleteBackupFile(Uri.parse(uri), name)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("backup_delete_failed", error.message ?: "Could not delete backup file.", null)
                        }
                    }
                }
                "syncAutomaticBackup" -> {
                    try {
                        AutomaticBackupScheduler.sync(this)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("automatic_backup_schedule_failed", error.message ?: "Could not schedule automatic backup.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        DirectApkInstaller.onAppResumed(this)
        if (BuildConfig.DISTRIBUTION != "play") return
        playUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            when {
                info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                    info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) -> {
                    playUpdateManager.startUpdateFlowForResult(
                        info,
                        playUpdateLauncher,
                        AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                    )
                }
                info.installStatus() == InstallStatus.DOWNLOADED -> playUpdateManager.completeUpdate()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        DirectApkInstaller.onAppResumed(this)
    }

    override fun onDestroy() {
        if (BuildConfig.DISTRIBUTION == "play") {
            try {
                playUpdateManager.unregisterListener(flexibleUpdateListener)
            } catch (_: Exception) {
            }
        }
        super.onDestroy()
    }

    private fun checkGooglePlayUpdate(result: MethodChannel.Result) {
        if (BuildConfig.DISTRIBUTION != "play") {
            result.success(
                mapOf(
                    "available" to false,
                    "immediateAllowed" to false,
                    "flexibleAllowed" to false,
                    "inProgress" to false,
                    "availableVersionCode" to 0,
                ),
            )
            return
        }
        playUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val availability = info.updateAvailability()
                result.success(
                    mapOf(
                        "available" to (availability == UpdateAvailability.UPDATE_AVAILABLE ||
                            availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS),
                        "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                        "inProgress" to (availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS),
                        "availableVersionCode" to info.availableVersionCode(),
                    ),
                )
            }
            .addOnFailureListener { error ->
                result.error("play_update_check_failed", error.message ?: "Google Play update check failed.", null)
            }
    }

    private fun startGooglePlayUpdate(result: MethodChannel.Result) {
        if (BuildConfig.DISTRIBUTION != "play") {
            result.success(false)
            return
        }
        playUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val availability = info.updateAvailability()
                val updateAvailable = availability == UpdateAvailability.UPDATE_AVAILABLE ||
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                if (!updateAvailable) {
                    result.success(false)
                    return@addOnSuccessListener
                }

                val type = when {
                    info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) -> AppUpdateType.IMMEDIATE
                    info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) -> AppUpdateType.FLEXIBLE
                    else -> {
                        result.success(false)
                        return@addOnSuccessListener
                    }
                }
                if (type == AppUpdateType.FLEXIBLE) {
                    playUpdateManager.registerListener(flexibleUpdateListener)
                }
                try {
                    val started = playUpdateManager.startUpdateFlowForResult(
                        info,
                        playUpdateLauncher,
                        AppUpdateOptions.newBuilder(type).build(),
                    )
                    if (!started && type == AppUpdateType.FLEXIBLE) {
                        playUpdateManager.unregisterListener(flexibleUpdateListener)
                    }
                    result.success(started)
                } catch (error: Exception) {
                    if (type == AppUpdateType.FLEXIBLE) {
                        playUpdateManager.unregisterListener(flexibleUpdateListener)
                    }
                    result.error("play_update_start_failed", error.message ?: "Could not start the Google Play update.", null)
                }
            }
            .addOnFailureListener { error ->
                result.error("play_update_start_failed", error.message ?: "Could not start the Google Play update.", null)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != backupDirectoryRequestCode) return
        val pending = pendingBackupDirectoryResult
        pendingBackupDirectoryResult = null
        if (pending == null) return
        val treeUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (treeUri == null) {
            pending.success(null)
            return
        }
        try {
            val takeFlags = (data?.flags ?: 0) and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (takeFlags == 0) {
                pending.error("folder_permission_failed", "Android did not grant access to the selected folder.", null)
                return
            }
            contentResolver.takePersistableUriPermission(treeUri, takeFlags)
            if (!canWriteBackupDirectory(treeUri)) {
                pending.error("folder_not_writable", "The selected folder is not writable.", null)
                return
            }
            // The picker grants access to a parent location. Yutaka owns a
            // predictable Yutaka/Backup child below it so users never need to
            // create or manage the destination folder manually.
            ensureYutakaBackupDirectory(treeUri)
            pending.success(
                mapOf(
                    "uri" to treeUri.toString(),
                    "label" to resolvedBackupDirectoryLabel(treeUri),
                ),
            )
        } catch (error: Exception) {
            pending.error("folder_permission_failed", error.message ?: "Could not keep access to the selected folder.", null)
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isIgnoringBatteryOptimizations()) return true
        return BatteryOptimizationFlavorPolicy.openSettings(this)
    }

    private fun pickBackupDirectory(result: MethodChannel.Result) {
        if (pendingBackupDirectoryResult != null) {
            result.error("request_in_progress", "A backup folder picker is already open.", null)
            return
        }
        pendingBackupDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, backupDirectoryRequestCode)
    }

    private fun hasPersistedWritePermission(uri: Uri): Boolean {
        return contentResolver.persistedUriPermissions.any { permission ->
            permission.uri == uri && permission.isWritePermission
        }
    }

    private fun canWriteBackupDirectory(uri: Uri): Boolean {
        if (!hasPersistedWritePermission(uri)) return false
        return try {
            val documentId = DocumentsContract.getTreeDocumentId(uri)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(uri, documentId)
            contentResolver.query(
                documentUri,
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null,
                null,
                null,
            )?.use { cursor -> cursor.moveToFirst() } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun backupDirectoryLabel(uri: Uri): String {
        return try {
            val treeId = DocumentsContract.getTreeDocumentId(uri)
            val parts = treeId.split(":", limit = 2)
            val volume = when (parts.firstOrNull()?.lowercase()) {
                "primary" -> "Internal storage"
                "home" -> "Documents"
                else -> parts.firstOrNull().orEmpty().ifBlank { "Android storage" }
            }
            val relative = parts.getOrNull(1).orEmpty().trim('/')
            if (relative.isBlank()) volume else "$volume/$relative"
        } catch (_: Exception) {
            "Selected Android folder"
        }
    }

    private fun childDocumentsUri(treeUri: Uri, parentDocumentUri: Uri): Uri {
        val documentId = DocumentsContract.getDocumentId(parentDocumentUri)
        return DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
    }

    private fun parentDocumentUri(treeUri: Uri): Uri {
        val documentId = DocumentsContract.getTreeDocumentId(treeUri)
        return DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
    }

    private fun findChildDocument(
        treeUri: Uri,
        parentDocumentUri: Uri,
        displayName: String,
        directoryOnly: Boolean = false,
    ): Uri? {
        val childrenUri = childDocumentsUri(treeUri, parentDocumentUri)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                if (nameIndex < 0 || idIndex < 0) continue
                if (cursor.getString(nameIndex) != displayName) continue
                if (directoryOnly && (mimeIndex < 0 || cursor.getString(mimeIndex) != DocumentsContract.Document.MIME_TYPE_DIR)) {
                    continue
                }
                return DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(idIndex))
            }
        }
        return null
    }

    private fun ensureChildDirectory(treeUri: Uri, parentDocumentUri: Uri, name: String): Uri {
        return findChildDocument(treeUri, parentDocumentUri, name, directoryOnly = true)
            ?: DocumentsContract.createDocument(
                contentResolver,
                parentDocumentUri,
                DocumentsContract.Document.MIME_TYPE_DIR,
                name,
            )
            ?: throw IllegalStateException("Android could not create the $name backup folder.")
    }

    private fun selectedTreeSegments(treeUri: Uri): List<String> {
        return try {
            val treeId = DocumentsContract.getTreeDocumentId(treeUri)
            val relative = treeId.split(":", limit = 2).getOrNull(1).orEmpty().trim('/')
            if (relative.isBlank()) emptyList() else relative.split('/').filter { it.isNotBlank() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun selectedTreeIsYutakaBackup(treeUri: Uri): Boolean {
        val segments = selectedTreeSegments(treeUri)
        return segments.size >= 2 &&
            segments[segments.lastIndex - 1].equals("Yutaka", ignoreCase = true) &&
            segments.last().equals("Backup", ignoreCase = true)
    }

    private fun selectedTreeIsYutakaFolder(treeUri: Uri): Boolean {
        val segments = selectedTreeSegments(treeUri)
        return segments.isNotEmpty() && segments.last().equals("Yutaka", ignoreCase = true)
    }

    private fun ensureYutakaBackupDirectory(treeUri: Uri): Uri {
        val selected = parentDocumentUri(treeUri)
        if (selectedTreeIsYutakaBackup(treeUri)) return selected
        if (selectedTreeIsYutakaFolder(treeUri)) {
            return ensureChildDirectory(treeUri, selected, "Backup")
        }
        val yutaka = ensureChildDirectory(treeUri, selected, "Yutaka")
        return ensureChildDirectory(treeUri, yutaka, "Backup")
    }

    private fun resolvedBackupDirectoryLabel(treeUri: Uri): String {
        val selectedLabel = backupDirectoryLabel(treeUri)
        return when {
            selectedTreeIsYutakaBackup(treeUri) -> selectedLabel
            selectedTreeIsYutakaFolder(treeUri) -> "$selectedLabel/Backup"
            else -> "$selectedLabel/Yutaka/Backup"
        }
    }

    private fun findBackupDocument(treeUri: Uri, backupDirectoryUri: Uri, fileName: String): Uri? {
        return findChildDocument(treeUri, backupDirectoryUri, fileName)
    }

    private fun writeBackupFile(treeUri: Uri, fileName: String, bytes: ByteArray) {
        if (!canWriteBackupDirectory(treeUri)) {
            throw SecurityException("Yutaka no longer has write access to this folder. Choose it again in backup settings.")
        }
        val backupDirectoryUri = ensureYutakaBackupDirectory(treeUri)
        val documentUri = findBackupDocument(treeUri, backupDirectoryUri, fileName)
            ?: DocumentsContract.createDocument(
                contentResolver,
                backupDirectoryUri,
                "application/octet-stream",
                fileName,
            )
            ?: throw IllegalStateException("Android could not create the backup file in this folder.")
        contentResolver.openOutputStream(documentUri, "wt")?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: throw IllegalStateException("Android could not open the backup file for writing.")
    }

    private fun listBackupFiles(treeUri: Uri): List<Map<String, Any>> {
        if (!canWriteBackupDirectory(treeUri)) {
            throw SecurityException("Yutaka no longer has access to this backup folder.")
        }
        val result = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val backupDirectoryUri = ensureYutakaBackupDirectory(treeUri)
        contentResolver.query(childDocumentsUri(treeUri, backupDirectoryUri), projection, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val modifiedIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            while (cursor.moveToNext()) {
                if (nameIndex < 0) continue
                val name = cursor.getString(nameIndex) ?: continue
                val modified = if (modifiedIndex >= 0 && !cursor.isNull(modifiedIndex)) cursor.getLong(modifiedIndex) else 0L
                result.add(mapOf("name" to name, "lastModified" to modified))
            }
        }
        return result
    }

    private fun deleteBackupFile(treeUri: Uri, fileName: String) {
        if (!canWriteBackupDirectory(treeUri)) return
        val backupDirectoryUri = ensureYutakaBackupDirectory(treeUri)
        val documentUri = findBackupDocument(treeUri, backupDirectoryUri, fileName) ?: return
        DocumentsContract.deleteDocument(contentResolver, documentUri)
    }


}
