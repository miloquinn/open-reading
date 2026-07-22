package com.niki.xxread

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.Os
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.zip.ZipFile
import org.json.JSONArray
import org.json.JSONObject

/**
 * Materializes Android open/share intents before their temporary URI grants expire.
 * Requests remain pending until Dart explicitly completes them, so a Flutter listener
 * race cannot lose a cold- or warm-start request.
 */
class IncomingBookIntentBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/incoming_books"
        private const val EVENT_METHOD = "incomingBooks"
        private const val PROCESSED_EXTRA = "com.niki.xxread.INCOMING_BOOK_INTENT_PROCESSED"
        private const val MAX_ITEM_COUNT = 10
        private const val MAX_FILE_BYTES = 100L * 1024L * 1024L
        private const val MAX_AGGREGATE_BYTES = 500L * 1024L * 1024L
        private const val MANIFEST_NAME = "request.json"
        private const val MAX_MANIFEST_BYTES = 1024L * 1024L
        private val epubMimeMarker = "application/epub+zip".toByteArray(Charsets.US_ASCII)
        private val supportedExtensions = setOf("txt", "epub", "pdf")
        private val extensionByMime = mapOf(
            "text/plain" to "txt",
            "application/epub+zip" to "epub",
            "application/pdf" to "pdf",
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val pendingRequests = linkedMapOf<String, Map<String, Any?>>()
    private val pendingInitialResults = mutableListOf<MethodChannel.Result>()
    private var activeMaterializations = 0
    private val incomingRoot = File(activity.cacheDir, "incoming_books")

    init {
        rehydratePendingRequests()
        channel.setMethodCallHandler(this)
        pruneOrphanedDirectories()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitialIncomingBooks" -> {
                val snapshot = synchronized(pendingRequests) {
                    if (activeMaterializations > 0) {
                        pendingInitialResults += result
                        null
                    } else {
                        pendingRequests.values.toList()
                    }
                }
                if (snapshot != null) result.success(snapshot)
            }
            "completeIncomingRequest" -> {
                val requestId = call.argument<String>("requestId")
                if (requestId.isNullOrBlank()) {
                    result.error("invalid_args", "requestId is required", null)
                    return
                }
                val deleteFiles = call.argument<Boolean>("deleteFiles") ?: true
                val removedRequest = synchronized(pendingRequests) {
                    pendingRequests.remove(requestId)
                }
                if (removedRequest == null) {
                    result.success(false)
                    return
                }
                ioExecutor.execute {
                    runCatching { finishRequestDirectory(requestId, deleteFiles) }
                        .onSuccess {
                            activity.runOnUiThread { result.success(true) }
                        }
                        .onFailure { error ->
                            synchronized(pendingRequests) {
                                pendingRequests[requestId] = removedRequest
                            }
                            activity.runOnUiThread {
                                result.error("cleanup_failed", error.message, null)
                            }
                        }
                }
            }
            else -> result.notImplemented()
        }
    }

    fun handleIntent(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra(PROCESSED_EXTRA, false)) return
        val action = IncomingBookIntentParser.actionName(intent.action) ?: return
        intent.putExtra(PROCESSED_EXTRA, true)
        val requestId = UUID.randomUUID().toString()
        val uris = IncomingBookIntentParser.extractUris(intent)
        val intentMime = normalizeMime(intent.type)
        synchronized(pendingRequests) {
            activeMaterializations += 1
        }
        ioExecutor.execute {
            var request = runCatching {
                materializeRequest(
                    requestId = requestId,
                    action = action,
                    uris = uris,
                    intentMime = intentMime,
                )
            }.getOrElse {
                deleteRequestDirectory(requestId)
                failedRequest(requestId, action, "materialize_failed")
            }
            if (runCatching { persistRequest(requestId, request) }.isFailure) {
                deleteRequestDirectory(requestId)
                request = failedRequest(requestId, action, "materialize_failed")
            }
            val waitingResults: List<MethodChannel.Result>
            val snapshot: List<Map<String, Any?>>
            synchronized(pendingRequests) {
                pendingRequests[requestId] = request
                activeMaterializations -= 1
                if (activeMaterializations == 0) {
                    waitingResults = pendingInitialResults.toList()
                    pendingInitialResults.clear()
                    snapshot = pendingRequests.values.toList()
                } else {
                    waitingResults = emptyList()
                    snapshot = emptyList()
                }
            }
            activity.runOnUiThread {
                waitingResults.forEach { it.success(snapshot) }
                channel.invokeMethod(EVENT_METHOD, request)
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ioExecutor.shutdown()
    }

    private fun materializeRequest(
        requestId: String,
        action: String,
        uris: List<Uri>,
        intentMime: String?,
    ): Map<String, Any?> {
        val requestDirectory = File(incomingRoot, requestId)
        val items = mutableListOf<Map<String, Any?>>()
        val failures = mutableListOf<Map<String, Any?>>()
        if (uris.size > MAX_ITEM_COUNT) {
            return failedRequest(requestId, action, "too_many_files")
        }

        val candidates = uris.map { uri ->
            Candidate(uri = uri, metadata = queryMetadata(uri))
        }
        var declaredAggregate = 0L
        for (candidate in candidates) {
            val declaredSize = candidate.metadata.sizeBytes?.takeIf { it > 0 } ?: continue
            if (declaredSize > MAX_FILE_BYTES) {
                return failedRequest(requestId, action, "file_too_large")
            }
            if (declaredSize > MAX_AGGREGATE_BYTES - declaredAggregate) {
                return failedRequest(requestId, action, "aggregate_too_large")
            }
            declaredAggregate += declaredSize
        }
        if (uris.isNotEmpty()) requestDirectory.mkdirs()
        var copiedAggregate = 0L
        var fatalErrorCode: String? = null

        candidates.forEachIndexed { index, candidate ->
            if (fatalErrorCode != null) return@forEachIndexed
            val uri = candidate.uri
            val scheme = uri.scheme?.lowercase()
            if (scheme != "content" && scheme != "file") {
                failures += failure("unsupported_uri_scheme", null, null)
                return@forEachIndexed
            }
            val metadata = candidate.metadata
            val mimeType = normalizeMime(metadata.mimeType) ?: intentMime
            val resolvedName = resolveFileName(metadata.displayName, mimeType, index)
            val extension = resolvedName.substringAfterLast('.', "").lowercase()
            val mimeExtension = extensionByMime[mimeType]
            if (extension !in supportedExtensions) {
                failures += failure("unsupported_format", resolvedName, mimeType)
                return@forEachIndexed
            }
            if (mimeExtension != null && mimeExtension != extension) {
                failures += failure("format_mime_mismatch", resolvedName, mimeType)
                return@forEachIndexed
            }
            if (metadata.sizeBytes != null && metadata.sizeBytes > MAX_FILE_BYTES) {
                failures += failure("file_too_large", resolvedName, mimeType)
                return@forEachIndexed
            }

            val target = uniqueFile(requestDirectory, resolvedName)
            try {
                val copiedBytes = copyUri(uri, target, copiedAggregate)
                validateContent(target, extension)
                copiedAggregate += copiedBytes
                items += mapOf(
                    "id" to UUID.randomUUID().toString(),
                    "displayName" to target.name,
                    "localPath" to target.absolutePath,
                    "mimeType" to (mimeType ?: mimeForExtension(extension)),
                    "sizeBytes" to target.length(),
                    "modifiedTime" to metadata.modifiedTimeMs,
                )
            } catch (error: IncomingBookException) {
                target.delete()
                if (error.code == "aggregate_too_large") {
                    fatalErrorCode = error.code
                } else {
                    failures += failure(error.code, resolvedName, mimeType)
                }
            } catch (_: Throwable) {
                target.delete()
                failures += failure("materialize_failed", resolvedName, mimeType)
            }
        }

        if (fatalErrorCode != null) {
            requestDirectory.deleteRecursively()
            return failedRequest(requestId, action, fatalErrorCode!!)
        }

        if (items.isEmpty()) {
            requestDirectory.deleteRecursively()
        }
        val errorCode = when {
            uris.isEmpty() -> "no_book_file"
            items.isEmpty() -> failures.firstOrNull()?.get("errorCode") ?: "materialize_failed"
            else -> null
        }
        return mapOf(
            "requestId" to requestId,
            "action" to action,
            "receivedAtMs" to System.currentTimeMillis(),
            "items" to items,
            "failures" to failures,
            "errorCode" to errorCode,
        )
    }

    private fun failedRequest(
        requestId: String,
        action: String,
        errorCode: String,
    ): Map<String, Any?> = mapOf(
        "requestId" to requestId,
        "action" to action,
        "receivedAtMs" to System.currentTimeMillis(),
        "items" to emptyList<Map<String, Any?>>(),
        "failures" to listOf(failure(errorCode, null, null)),
        "errorCode" to errorCode,
    )

    private fun queryMetadata(uri: Uri): SourceMetadata {
        if (uri.scheme == "file") {
            val file = uri.path?.let(::File)
            return SourceMetadata(
                displayName = file?.name,
                mimeType = activity.contentResolver.getType(uri),
                sizeBytes = file?.takeIf { it.isFile }?.length(),
                modifiedTimeMs = file?.takeIf { it.isFile }?.lastModified(),
            )
        }
        val projection = arrayOf(
            OpenableColumns.DISPLAY_NAME,
            OpenableColumns.SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        return runCatching {
            activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                SourceMetadata(
                    displayName = cursor.stringValue(OpenableColumns.DISPLAY_NAME),
                    mimeType = activity.contentResolver.getType(uri),
                    sizeBytes = cursor.longValue(OpenableColumns.SIZE),
                    modifiedTimeMs = cursor.longValue(
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    ),
                )
            }
        }.getOrNull() ?: SourceMetadata(
            displayName = uri.lastPathSegment,
            mimeType = runCatching { activity.contentResolver.getType(uri) }.getOrNull(),
            sizeBytes = null,
            modifiedTimeMs = null,
        )
    }

    private fun resolveFileName(rawName: String?, mimeType: String?, index: Int): String {
        val sanitized = BookFileNames.sanitize(
            rawName?.takeIf { it.isNotBlank() } ?: "book-${index + 1}",
        )
        val extension = sanitized.substringAfterLast('.', "").lowercase()
        if (extension.isNotEmpty()) return sanitized
        val inferred = extensionByMime[mimeType]
        return if (inferred == null) sanitized else "$sanitized.$inferred"
    }

    private fun uniqueFile(directory: File, displayName: String): File {
        val name = BookFileNames.firstAvailable(displayName) { candidate ->
            File(directory, candidate).exists()
        }
        return File(directory, name)
    }

    private fun copyUri(uri: Uri, target: File, aggregateBefore: Long): Long {
        target.parentFile?.mkdirs()
        var total = 0L
        openInput(uri).buffered().use { input ->
            target.outputStream().buffered().use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    if (total > MAX_FILE_BYTES) {
                        throw IncomingBookException("file_too_large")
                    }
                    if (total > MAX_AGGREGATE_BYTES - aggregateBefore) {
                        throw IncomingBookException("aggregate_too_large")
                    }
                    output.write(buffer, 0, count)
                }
            }
        }
        return total
    }

    private fun openInput(uri: Uri): InputStream {
        if (uri.scheme == "file") {
            val path = requireNotNull(uri.path) { "Missing file path" }
            return FileInputStream(File(path))
        }
        return requireNotNull(activity.contentResolver.openInputStream(uri)) {
            "Unable to open incoming URI"
        }
    }

    private fun validateContent(file: File, extension: String) {
        when (extension) {
            "pdf" -> {
                val signature = ByteArray(5)
                val count = file.inputStream().use { it.read(signature) }
                if (count != signature.size || !signature.contentEquals("%PDF-".toByteArray())) {
                    throw IncomingBookException("format_content_mismatch")
                }
            }
            "epub" -> {
                val valid = runCatching {
                    ZipFile(file).use { zip ->
                        val entry = zip.getEntry("mimetype") ?: return@use false
                        if (entry.size >= 0 && entry.size != epubMimeMarker.size.toLong()) {
                            return@use false
                        }
                        zip.getInputStream(entry).use { input ->
                            readAtMost(input, epubMimeMarker.size + 1)
                                .contentEquals(epubMimeMarker)
                        }
                    }
                }.getOrDefault(false)
                if (!valid) throw IncomingBookException("format_content_mismatch")
            }
            "txt" -> {
                val signature = ByteArray(5)
                val count = file.inputStream().use { it.read(signature) }
                if (
                    count >= 4 && signature[0] == 'P'.code.toByte() &&
                    signature[1] == 'K'.code.toByte()
                ) {
                    throw IncomingBookException("format_content_mismatch")
                }
                if (count == 5 && signature.contentEquals("%PDF-".toByteArray())) {
                    throw IncomingBookException("format_content_mismatch")
                }
            }
        }
    }

    private fun readAtMost(input: InputStream, limit: Int): ByteArray {
        val buffer = ByteArray(limit)
        var total = 0
        while (total < limit) {
            val count = input.read(buffer, total, limit - total)
            if (count < 0) break
            if (count == 0) continue
            total += count
        }
        return buffer.copyOf(total)
    }

    private fun failure(
        errorCode: String,
        displayName: String?,
        mimeType: String?,
    ): Map<String, Any?> = mapOf(
        "errorCode" to errorCode,
        "displayName" to displayName,
        "mimeType" to mimeType,
    )

    private fun deleteRequestDirectory(requestId: String) {
        val directory = safeRequestDirectory(requestId) ?: return
        directory.deleteRecursively()
    }

    private fun finishRequestDirectory(requestId: String, deleteFiles: Boolean) {
        val directory = safeRequestDirectory(requestId) ?: return
        if (deleteFiles) {
            check(!directory.exists() || directory.deleteRecursively()) {
                "Unable to delete completed incoming request"
            }
        } else {
            val manifest = File(directory, MANIFEST_NAME)
            check(!manifest.exists() || manifest.delete()) {
                "Unable to delete completed incoming request manifest"
            }
        }
    }

    private fun safeRequestDirectory(requestId: String): File? {
        if (!requestId.matches(Regex("[0-9a-fA-F-]{36}"))) return null
        val directory = File(incomingRoot, requestId)
        val rootPath = incomingRoot.canonicalFile.toPath()
        val directoryPath = runCatching { directory.canonicalFile.toPath() }.getOrNull()
            ?: return null
        return directory.takeIf { directoryPath.parent == rootPath }
    }

    private fun persistRequest(requestId: String, request: Map<String, Any?>) {
        val directory = safeRequestDirectory(requestId)
            ?: error("Invalid incoming request directory")
        check(directory.exists() || directory.mkdirs()) {
            "Unable to create incoming request directory"
        }
        val manifest = File(directory, MANIFEST_NAME)
        val partial = File(directory, ".$MANIFEST_NAME.${UUID.randomUUID()}.partial")
        val bytes = JSONObject(request).toString().toByteArray(Charsets.UTF_8)
        check(bytes.size <= MAX_MANIFEST_BYTES) { "Incoming request manifest is too large" }
        try {
            FileOutputStream(partial).use { output ->
                output.write(bytes)
                output.fd.sync()
            }
            Os.rename(partial.absolutePath, manifest.absolutePath)
        } finally {
            partial.delete()
        }
    }

    private fun rehydratePendingRequests() {
        incomingRoot.listFiles()?.forEach { directory ->
            if (!directory.isDirectory) return@forEach
            val requestId = directory.name
            if (safeRequestDirectory(requestId) == null) return@forEach
            val manifest = File(directory, MANIFEST_NAME)
            if (!manifest.isFile || manifest.length() !in 1..MAX_MANIFEST_BYTES) return@forEach
            val request = runCatching {
                jsonObjectToMap(JSONObject(manifest.readText(Charsets.UTF_8)))
            }.getOrNull() ?: return@forEach
            if (request["requestId"]?.toString() != requestId) return@forEach
            synchronized(pendingRequests) {
                pendingRequests[requestId] = request
            }
        }
    }

    private fun jsonObjectToMap(value: JSONObject): Map<String, Any?> {
        val result = linkedMapOf<String, Any?>()
        val keys = value.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = jsonValue(value.get(key))
        }
        return result
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> List(value.length()) { index -> jsonValue(value.get(index)) }
        else -> value
    }

    private fun pruneOrphanedDirectories() {
        ioExecutor.execute {
            val cutoff = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
            val pendingIds = synchronized(pendingRequests) { pendingRequests.keys.toSet() }
            incomingRoot.listFiles()?.forEach { child ->
                if (
                    child.isDirectory &&
                    child.name !in pendingIds &&
                    child.lastModified() < cutoff
                ) {
                    child.deleteRecursively()
                }
            }
        }
    }

    private fun normalizeMime(value: String?): String? =
        value?.substringBefore(';')?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }

    private fun mimeForExtension(extension: String): String = when (extension) {
        "txt" -> "text/plain"
        "epub" -> "application/epub+zip"
        "pdf" -> "application/pdf"
        else -> "application/octet-stream"
    }

    private fun Cursor.stringValue(columnName: String): String? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getString(index) else null
    }

    private fun Cursor.longValue(columnName: String): Long? {
        val index = getColumnIndex(columnName)
        return if (index >= 0 && !isNull(index)) getLong(index) else null
    }

    private data class SourceMetadata(
        val displayName: String?,
        val mimeType: String?,
        val sizeBytes: Long?,
        val modifiedTimeMs: Long?,
    )

    private data class Candidate(
        val uri: Uri,
        val metadata: SourceMetadata,
    )

    private class IncomingBookException(val code: String) : Exception(code)
}

internal object IncomingBookIntentParser {
    fun actionName(action: String?): String? = when (action) {
        Intent.ACTION_VIEW -> "open"
        Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> "share"
        else -> null
    }

    fun extractUris(intent: Intent): List<Uri> {
        val ordered = linkedSetOf<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let(ordered::add)
            Intent.ACTION_SEND -> {
                intent.streamUri()?.let(ordered::add)
                addClipData(intent.clipData, ordered)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.streamUris().forEach(ordered::add)
                addClipData(intent.clipData, ordered)
            }
        }
        return ordered.toList()
    }

    private fun addClipData(clipData: ClipData?, output: MutableSet<Uri>) {
        if (clipData == null) return
        for (index in 0 until clipData.itemCount) {
            clipData.getItemAt(index).uri?.let(output::add)
        }
    }

    @Suppress("DEPRECATION")
    private fun Intent.streamUri(): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    @Suppress("DEPRECATION")
    private fun Intent.streamUris(): List<Uri> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java).orEmpty()
        } else {
            getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }
    }
}
