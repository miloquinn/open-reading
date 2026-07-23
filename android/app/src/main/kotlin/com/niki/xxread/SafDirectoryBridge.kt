package com.niki.xxread

import android.app.Activity
import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.system.Os
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class SafDirectoryBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/storage"
        private const val PICK_DIRECTORY_REQUEST = 41271
        private const val LEGACY_EXPORT_PERMISSION_REQUEST = 41272
        private const val EXPORT_RELATIVE_DIRECTORY = "Download/开元阅读"
    }

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingLegacyExport: PendingExport? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> pickDirectory(result)
            "listDocuments" -> {
                val treeUri = call.argument<String>("treeUri")
                if (treeUri.isNullOrBlank()) {
                    result.error("invalid_args", "treeUri is required", null)
                    return
                }
                ioExecutor.execute {
                    runCatching { listDocuments(Uri.parse(treeUri)) }
                        .onSuccess { documents ->
                            activity.runOnUiThread { result.success(documents) }
                        }
                        .onFailure { error ->
                            activity.runOnUiThread {
                                result.error("list_failed", error.message, null)
                            }
                        }
                }
            }
            "listPersistedDirectories" -> {
                runCatching { listPersistedDirectories() }
                    .onSuccess(result::success)
                    .onFailure { result.error("list_permissions_failed", it.message, null) }
            }
            "releaseDirectory" -> {
                val treeUri = call.argument<String>("treeUri")
                if (treeUri.isNullOrBlank()) {
                    result.error("invalid_args", "treeUri is required", null)
                    return
                }
                runCatching { releaseDirectory(Uri.parse(treeUri)) }
                    .onSuccess(result::success)
                    .onFailure { result.error("release_permission_failed", it.message, null) }
            }
            "materializeDocument" -> {
                val documentUri = call.argument<String>("documentUri")
                val destinationPath = call.argument<String>("destinationPath")
                if (documentUri.isNullOrBlank() || destinationPath.isNullOrBlank()) {
                    result.error(
                        "invalid_args",
                        "documentUri and destinationPath are required",
                        null,
                    )
                    return
                }
                ioExecutor.execute {
                    runCatching {
                        materializeDocument(Uri.parse(documentUri), File(destinationPath))
                    }.onSuccess { localPath ->
                        activity.runOnUiThread { result.success(localPath) }
                    }.onFailure { error ->
                        activity.runOnUiThread {
                            result.error("materialize_failed", error.message, null)
                        }
                    }
                }
            }
            "exportBookToDownloads" -> exportBookToDownloads(call, result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != LEGACY_EXPORT_PERMISSION_REQUEST) return false
        val pending = pendingLegacyExport ?: return true
        pendingLegacyExport = null
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            pending.result.error(
                "storage_permission_denied",
                "Storage permission is required on Android 9 and earlier",
                null,
            )
            return true
        }
        performExport(pending)
        return true
    }

    fun dispose() {
        ioExecutor.shutdown()
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_DIRECTORY_REQUEST) return false
        val pending = pendingPickResult ?: return true
        pendingPickResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return true
        }

        val treeUri = data.data!!
        val hasReadPermission =
            data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0
        val hasWritePermission =
            data.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0
        if (!hasReadPermission) {
            pending.error("read_permission_missing", "Directory read access was not granted", null)
            return true
        }
        try {
            if (hasWritePermission) {
                activity.contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } else {
                activity.contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            pending.success(directoryInfo(treeUri))
        } catch (error: SecurityException) {
            pending.error("persist_permission_failed", error.message, null)
        }
        return true
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("picker_busy", "A directory picker is already active", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, PICK_DIRECTORY_REQUEST)
    }

    private fun listPersistedDirectories(): List<Map<String, Any?>> {
        return activity.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission }
            .map { directoryInfo(it.uri) }
    }

    private fun releaseDirectory(treeUri: Uri): Boolean {
        val permission = activity.contentResolver.persistedUriPermissions
            .firstOrNull { it.uri == treeUri }
            ?: return false
        var flags = 0
        if (permission.isReadPermission) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (permission.isWritePermission) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if (flags != 0) {
            activity.contentResolver.releasePersistableUriPermission(treeUri, flags)
        }
        return true
    }

    private fun directoryInfo(treeUri: Uri): Map<String, Any?> {
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId)
        val displayName = queryDocument(rootUri)?.displayName ?: treeUri.lastPathSegment
        return mapOf(
            "treeUri" to treeUri.toString(),
            "displayName" to displayName,
        )
    }

    private fun listDocuments(treeUri: Uri): List<Map<String, Any?>> {
        val hasReadPermission = activity.contentResolver.persistedUriPermissions.any {
            it.isReadPermission && it.uri == treeUri
        }
        check(hasReadPermission) {
            "Directory access is no longer available. Select the folder again."
        }
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val results = mutableListOf<Map<String, Any?>>()
        walkDirectory(treeUri, rootId, mutableSetOf(), results)
        return results
    }

    private fun walkDirectory(
        treeUri: Uri,
        documentId: String,
        visited: MutableSet<String>,
        results: MutableList<Map<String, Any?>>,
    ) {
        if (!visited.add(documentId)) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            documentId,
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )

        val cursor = requireNotNull(
            activity.contentResolver.query(childrenUri, projection, null, null, null),
        ) {
            "The document provider returned no directory listing for $documentId"
        }
        cursor.use {
            while (cursor.moveToNext()) {
                val childId = cursor.stringValue(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                    ?: continue
                val displayName = cursor.stringValue(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                ) ?: childId
                val mimeType = cursor.stringValue(DocumentsContract.Document.COLUMN_MIME_TYPE)
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walkDirectory(treeUri, childId, visited, results)
                    continue
                }
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                results.add(
                    mapOf(
                        "locator" to documentUri.toString(),
                        "documentUri" to documentUri.toString(),
                        "displayName" to displayName,
                        "extension" to displayName.substringAfterLast('.', "").lowercase(),
                        "mimeType" to mimeType,
                        "sizeBytes" to cursor.longValue(DocumentsContract.Document.COLUMN_SIZE),
                        "modifiedTime" to cursor.longValue(
                            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                        ),
                    ),
                )
            }
        }
    }

    private fun queryDocument(uri: Uri): DocumentRow? {
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        return activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            DocumentRow(
                displayName = cursor.stringValue(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                ),
            )
        }
    }

    private fun materializeDocument(documentUri: Uri, destination: File): String {
        try {
            destination.parentFile?.mkdirs()
            activity.contentResolver.openInputStream(documentUri).use { input ->
                requireNotNull(input) { "Unable to open $documentUri" }
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            return destination.absolutePath
        } catch (error: Throwable) {
            destination.delete()
            throw error
        }
    }

    private fun exportBookToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val displayName = call.argument<String>("displayName")
        val mimeType = call.argument<String>("mimeType")
        if (sourcePath.isNullOrBlank() || displayName.isNullOrBlank() || mimeType.isNullOrBlank()) {
            result.error(
                "invalid_args",
                "sourcePath, displayName, and mimeType are required",
                null,
            )
            return
        }
        val source = File(sourcePath)
        if (!source.isFile || !source.canRead()) {
            result.error("source_missing", "The source book is not readable", null)
            return
        }

        val pending = PendingExport(
            source = source,
            displayName = BookFileNames.sanitize(displayName),
            mimeType = mimeType,
            result = result,
        )
        if (
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingLegacyExport != null) {
                result.error("export_busy", "Another export is waiting for permission", null)
                return
            }
            pendingLegacyExport = pending
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                LEGACY_EXPORT_PERMISSION_REQUEST,
            )
            return
        }
        performExport(pending)
    }

    private fun performExport(pending: PendingExport) {
        ioExecutor.execute {
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    exportWithMediaStore(pending)
                } else {
                    exportToLegacyDownloads(pending)
                }
            }.onSuccess { payload ->
                activity.runOnUiThread { pending.result.success(payload) }
            }.onFailure { error ->
                activity.runOnUiThread {
                    pending.result.error("export_failed", error.message, null)
                }
            }
        }
    }

    private fun exportWithMediaStore(pending: PendingExport): Map<String, Any?> {
        val resolver = activity.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val relativePath = "$EXPORT_RELATIVE_DIRECTORY/"
        val uniqueName = BookFileNames.firstAvailable(pending.displayName) { candidate ->
            resolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND " +
                    "${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
                arrayOf(relativePath, candidate),
                null,
            )?.use { it.moveToFirst() } == true
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
            put(MediaStore.MediaColumns.MIME_TYPE, pending.mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = requireNotNull(resolver.insert(collection, values)) {
            "Unable to create a Downloads entry"
        }
        try {
            resolver.openOutputStream(uri, "w").use { output ->
                requireNotNull(output) { "Unable to open the Downloads entry" }
                pending.source.inputStream().buffered().use { input ->
                    input.copyTo(output)
                }
            }
            val published = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            check(resolver.update(uri, published, null, null) == 1) {
                "Unable to publish the Downloads entry"
            }
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
        return exportPayload(uniqueName, uri.toString(), null)
    }

    @Suppress("DEPRECATION")
    private fun exportToLegacyDownloads(pending: PendingExport): Map<String, Any?> {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "开元阅读",
        )
        check(directory.exists() || directory.mkdirs()) {
            "Unable to create the Downloads directory"
        }
        val partial = File.createTempFile(".open-reading-", ".partial", directory)
        try {
            pending.source.inputStream().buffered().use { input ->
                partial.outputStream().buffered().use { output -> input.copyTo(output) }
            }
        } catch (error: Throwable) {
            partial.delete()
            throw error
        }

        val target = try {
            reserveLegacyTarget(directory, pending.displayName)
        } catch (error: Throwable) {
            partial.delete()
            throw error
        }
        try {
            // Both paths are in the same directory. The empty destination was
            // atomically created by this export, so rename cannot truncate a
            // pre-existing file owned by another app.
            Os.rename(partial.absolutePath, target.absolutePath)
        } catch (error: Throwable) {
            // Only these two files were created by this export attempt.
            partial.delete()
            target.delete()
            throw error
        }
        return exportPayload(target.name, null, target.absolutePath)
    }

    private fun reserveLegacyTarget(directory: File, displayName: String): File {
        for (counter in 0..9999) {
            val candidate = BookFileNames.candidate(displayName, counter)
            val target = File(directory, candidate)
            if (target.createNewFile()) return target
        }
        error("Unable to reserve a unique export file name")
    }

    private fun exportPayload(
        displayName: String,
        contentUri: String?,
        destinationPath: String?,
    ): Map<String, Any?> {
        val displayLocation = "$EXPORT_RELATIVE_DIRECTORY/$displayName"
        return mapOf(
            "status" to "success",
            "displayName" to displayName,
            "destinationPath" to destinationPath,
            "displayLocation" to displayLocation,
            "location" to displayLocation,
            "uri" to contentUri,
        )
    }

    private fun Cursor.stringValue(columnName: String): String? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getString(index) else null
    }

    private fun Cursor.longValue(columnName: String): Long? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getLong(index) else null
    }

    private data class DocumentRow(val displayName: String?)

    private data class PendingExport(
        val source: File,
        val displayName: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )
}

internal object BookFileNames {
    private const val FALLBACK_NAME = "book.bin"
    // Most shared-storage filesystems cap one path component at 255 bytes.
    // Keep extra space for duplicate suffixes and temporary-name decorations.
    private const val MAX_SAFE_UTF8_BYTES = 220
    private const val MAX_EXTENSION_UTF8_BYTES = 32

    fun sanitize(raw: String): String {
        val basename = raw.substringAfterLast('/').substringAfterLast('\\')
        val cleaned = buildString {
            basename.forEach { character ->
                if (!character.isISOControl() && character !in "<>:\"/\\|?*") {
                    append(character)
                }
            }
        }.trim().trimEnd('.', ' ')
        val usable = cleaned.ifBlank { FALLBACK_NAME }
        return fitToUtf8Budget(usable, MAX_SAFE_UTF8_BYTES)
    }

    fun firstAvailable(baseName: String, exists: (String) -> Boolean): String {
        for (counter in 0..9999) {
            val candidate = candidate(baseName, counter)
            if (!exists(candidate)) return candidate
        }
        error("Unable to choose a unique export file name")
    }

    fun candidate(baseName: String, counter: Int): String {
        require(counter >= 0)
        if (counter == 0) return baseName
        val dot = baseName.lastIndexOf('.').takeIf { it > 0 }
        val stem = if (dot == null) baseName else baseName.substring(0, dot)
        val extension = if (dot == null) "" else baseName.substring(dot)
        val suffix = " ($counter)"
        val reservedBytes = utf8Length(suffix) + utf8Length(extension)
        val stemBudget = (MAX_SAFE_UTF8_BYTES - reservedBytes).coerceAtLeast(1)
        return truncateUtf8(stem, stemBudget).trimEnd('.', ' ') + suffix + extension
    }

    private fun fitToUtf8Budget(value: String, maxBytes: Int): String {
        if (utf8Length(value) <= maxBytes) return value
        val extensionIndex = value.lastIndexOf('.').takeIf { it in 1 until value.lastIndex }
        val rawExtension = extensionIndex?.let(value::substring).orEmpty()
        val extension = rawExtension.takeIf {
            utf8Length(it) <= MAX_EXTENSION_UTF8_BYTES && utf8Length(it) < maxBytes
        }.orEmpty()
        val stem = if (extension.isEmpty()) {
            value
        } else {
            value.substring(0, requireNotNull(extensionIndex))
        }
        val stemBudget = (maxBytes - utf8Length(extension)).coerceAtLeast(1)
        val truncatedStem = truncateUtf8(stem, stemBudget).trimEnd('.', ' ')
        return (truncatedStem + extension).ifBlank { FALLBACK_NAME }
    }

    private fun truncateUtf8(value: String, maxBytes: Int): String {
        if (maxBytes <= 0 || value.isEmpty()) return ""
        if (utf8Length(value) <= maxBytes) return value
        val output = StringBuilder()
        var index = 0
        var usedBytes = 0
        while (index < value.length) {
            val codePoint = value.codePointAt(index)
            val codePointText = String(Character.toChars(codePoint))
            val codePointBytes = utf8Length(codePointText)
            if (usedBytes + codePointBytes > maxBytes) break
            output.append(codePointText)
            usedBytes += codePointBytes
            index += Character.charCount(codePoint)
        }
        return output.toString()
    }

    private fun utf8Length(value: String): Int = value.toByteArray(Charsets.UTF_8).size
}
