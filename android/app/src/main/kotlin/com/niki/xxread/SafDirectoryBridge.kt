package com.niki.xxread

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SafDirectoryBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/storage"
        private const val PICK_DIRECTORY_REQUEST = 41271
    }

    private var pendingPickResult: MethodChannel.Result? = null

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
                runCatching { listDocuments(Uri.parse(treeUri)) }
                    .onSuccess(result::success)
                    .onFailure { result.error("list_failed", it.message, null) }
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
                runCatching {
                    materializeDocument(Uri.parse(documentUri), File(destinationPath))
                }.onSuccess(result::success)
                    .onFailure { result.error("materialize_failed", it.message, null) }
            }
            else -> result.notImplemented()
        }
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

        activity.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
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

    private fun Cursor.stringValue(columnName: String): String? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getString(index) else null
    }

    private fun Cursor.longValue(columnName: String): Long? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getLong(index) else null
    }

    private data class DocumentRow(val displayName: String?)
}
