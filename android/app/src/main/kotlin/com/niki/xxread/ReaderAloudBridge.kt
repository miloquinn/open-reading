package com.niki.xxread

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ReaderAloudBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/reader_aloud"
        private const val NOTIFICATION_PERMISSION_REQUEST = 41273
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        private var activeChannel: MethodChannel? = null

        fun dispatchControl(action: String) {
            mainHandler.post {
                activeChannel?.invokeMethod("control", action)
            }
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        activeChannel = channel
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "show" -> show(call, result)
            "stop" -> {
                ReaderAloudForegroundService.stop(activity)
                result.success(null)
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
        result.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (activeChannel === channel) activeChannel = null
        pendingPermissionResult?.success(false)
        pendingPermissionResult = null
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

    private fun show(call: MethodCall, result: MethodChannel.Result) {
        val data = ReaderAloudNotificationData.from(call)
        if (data == null) {
            result.error(
                "invalid_args",
                "bookTitle, chapterTitle, state, and chapter progress are required",
                null,
            )
            return
        }
        runCatching {
            ReaderAloudForegroundService.show(activity, data)
        }.onSuccess { result.success(null) }
            .onFailure { result.error("notification_failed", it.message, null) }
    }
}
