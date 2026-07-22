package com.niki.xxread

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BackgroundDownloadBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/background_downloads"
        private const val NOTIFICATION_PERMISSION_REQUEST = 41272
        const val ACTION_NOTIFICATION_TAP = "com.niki.xxread.BACKGROUND_DOWNLOAD_TAP"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingTap: Map<String, String>? = null

    init {
        channel.setMethodCallHandler(this)
        captureInitialIntent(activity.intent)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "begin" -> updateTask(call, result, DownloadNotificationAction.BEGIN)
            "progress" -> updateTask(call, result, DownloadNotificationAction.PROGRESS)
            "complete" -> updateTask(call, result, DownloadNotificationAction.COMPLETE)
            "fail" -> updateTask(call, result, DownloadNotificationAction.FAIL)
            "cancel" -> updateTask(call, result, DownloadNotificationAction.CANCEL)
            "consumeNotificationTap" -> {
                result.success(pendingTap)
                pendingTap = null
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        result.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        return true
    }

    fun onNewIntent(intent: Intent?) {
        val tap = parseTap(intent) ?: return
        channel.invokeMethod("notificationTap", tap)
    }

    private fun captureInitialIntent(intent: Intent?) {
        pendingTap = parseTap(intent)
    }

    private fun parseTap(intent: Intent?): Map<String, String>? {
        if (intent?.action != ACTION_NOTIFICATION_TAP) return null
        val tap = mutableMapOf<String, String>()
        for (key in listOf("kind", "bookId", "apkPath", "expectedBuildNumber")) {
            intent.getStringExtra(key)?.takeIf { it.isNotBlank() }?.let {
                tap[key] = it
            }
        }
        return tap.takeIf { it.isNotEmpty() }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun updateTask(
        call: MethodCall,
        result: MethodChannel.Result,
        action: DownloadNotificationAction,
    ) {
        val task = DownloadNotificationTask.from(call)
        if (task == null) {
            result.error("invalid_args", "A download task id and title are required", null)
            return
        }
        runCatching {
            DownloadForegroundService.updateTask(activity, action, task)
        }.onSuccess { result.success(null) }
            .onFailure { result.error("notification_failed", it.message, null) }
    }
}
