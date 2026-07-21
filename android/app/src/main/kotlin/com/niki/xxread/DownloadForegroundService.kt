package com.niki.xxread

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import kotlin.math.abs

enum class DownloadNotificationAction { BEGIN, PROGRESS, COMPLETE, FAIL }

data class DownloadNotificationTask(
    val id: String,
    val kind: String,
    val title: String,
    val bookId: String?,
    val completed: Int = 0,
    val total: Int = 0,
    val apkPath: String? = null,
    val expectedBuildNumber: String? = null,
) {
    companion object {
        fun from(call: MethodCall): DownloadNotificationTask? {
            val id = call.argument<String>("id")?.trim().orEmpty()
            val title = call.argument<String>("title")?.trim().orEmpty()
            if (id.isEmpty() || title.isEmpty()) return null
            return DownloadNotificationTask(
                id = id,
                kind = call.argument<String>("kind") ?: "book",
                title = title,
                bookId = call.argument<Any>("bookId")?.toString(),
                completed = (call.argument<Number>("completed") ?: 0).toInt(),
                total = (call.argument<Number>("total") ?: 0).toInt(),
                apkPath = call.argument<String>("apkPath"),
                expectedBuildNumber = call.argument<String>("expectedBuildNumber"),
            )
        }
    }
}

class DownloadForegroundService : Service() {
    companion object {
        private const val ACTION_UPDATE = "com.niki.xxread.DOWNLOAD_NOTIFICATION_UPDATE"
        private const val EXTRA_ACTION = "action"
        private const val PROGRESS_CHANNEL = "background_download_progress"
        private const val COMPLETE_CHANNEL = "background_download_complete"
        private val activeTasks = linkedMapOf<String, DownloadNotificationTask>()

        fun updateTask(
            context: Context,
            action: DownloadNotificationAction,
            task: DownloadNotificationTask,
        ) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                this.action = ACTION_UPDATE
                putExtra(EXTRA_ACTION, action.name)
                putExtra("id", task.id)
                putExtra("kind", task.kind)
                putExtra("title", task.title)
                putExtra("bookId", task.bookId)
                putExtra("completed", task.completed)
                putExtra("total", task.total)
                putExtra("apkPath", task.apkPath)
                putExtra("expectedBuildNumber", task.expectedBuildNumber)
            }
            ContextCompat.startForegroundService(context, intent)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_UPDATE) return START_NOT_STICKY
        val task = DownloadNotificationTask(
            id = intent.getStringExtra("id").orEmpty(),
            kind = intent.getStringExtra("kind") ?: "book",
            title = intent.getStringExtra("title").orEmpty(),
            bookId = intent.getStringExtra("bookId"),
            completed = intent.getIntExtra("completed", 0),
            total = intent.getIntExtra("total", 0),
            apkPath = intent.getStringExtra("apkPath"),
            expectedBuildNumber = intent.getStringExtra("expectedBuildNumber"),
        )
        if (task.id.isEmpty() || task.title.isEmpty()) return START_NOT_STICKY
        val action = intent.getStringExtra(EXTRA_ACTION)
            ?.let { runCatching { DownloadNotificationAction.valueOf(it) }.getOrNull() }
            ?: return START_NOT_STICKY
        createChannels()
        when (action) {
            DownloadNotificationAction.BEGIN,
            DownloadNotificationAction.PROGRESS -> {
                activeTasks[task.id] = task
                startOrUpdateForeground()
                notificationManager().notify(notificationId(task.id), progressNotification(task))
            }
            DownloadNotificationAction.COMPLETE -> {
                activeTasks.remove(task.id)
                notificationManager().notify(notificationId(task.id), completionNotification(task))
                startOrStopForeground()
            }
            DownloadNotificationAction.FAIL -> {
                activeTasks.remove(task.id)
                notificationManager().notify(notificationId(task.id), failureNotification(task))
                startOrStopForeground()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startOrUpdateForeground() {
        val foregroundTask = activeTasks.values.firstOrNull() ?: return
        val notification = progressNotification(foregroundTask)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId(foregroundTask.id),
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(notificationId(foregroundTask.id), notification)
        }
    }

    private fun startOrStopForeground() {
        if (activeTasks.isNotEmpty()) {
            startOrUpdateForeground()
            return
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun progressNotification(task: DownloadNotificationTask): Notification {
        val total = task.total.coerceAtLeast(0)
        val completed = task.completed.coerceIn(0, total.coerceAtLeast(task.completed))
        val detail = when {
            total <= 0 -> "正在准备下载"
            task.kind == "update" -> "已下载 $completed / $total 字节"
            else -> "已下载 $completed / $total 章"
        }
        return notificationBuilder(PROGRESS_CHANNEL)
            .setContentTitle(task.title)
            .setContentText(detail)
            .setContentIntent(tapIntent(task))
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setProgress(total, completed, total <= 0)
            .build()
    }

    private fun completionNotification(task: DownloadNotificationTask): Notification {
        val detail = if (task.kind == "update") "更新包已准备好，点击安装" else "下载完成，点击阅读"
        return notificationBuilder(COMPLETE_CHANNEL)
            .setContentTitle(task.title)
            .setContentText(detail)
            .setContentIntent(tapIntent(task))
            .setAutoCancel(true)
            .setProgress(0, 0, false)
            .build()
    }

    private fun failureNotification(task: DownloadNotificationTask): Notification =
        notificationBuilder(COMPLETE_CHANNEL)
            .setContentTitle(task.title)
            .setContentText("下载失败，点击返回应用")
            .setContentIntent(tapIntent(task))
            .setAutoCancel(true)
            .build()

    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }.setSmallIcon(R.mipmap.launcher_icon)
            .setCategory(Notification.CATEGORY_PROGRESS)

    private fun tapIntent(task: DownloadNotificationTask): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = BackgroundDownloadBridge.ACTION_NOTIFICATION_TAP
            putExtra("kind", task.kind)
            putExtra("bookId", task.bookId)
            putExtra("apkPath", task.apkPath)
            putExtra("expectedBuildNumber", task.expectedBuildNumber)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            this,
            abs(task.id.hashCode()),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(NotificationManager::class.java)

    private fun notificationId(taskId: String): Int = 8000 + abs(taskId.hashCode() % 100000)

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager().createNotificationChannel(
            NotificationChannel(
                PROGRESS_CHANNEL,
                "后台下载进度",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        notificationManager().createNotificationChannel(
            NotificationChannel(
                COMPLETE_CHANNEL,
                "下载完成",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }
}
