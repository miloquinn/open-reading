package com.niki.xxread

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall

data class ReaderAloudNotificationData(
    val bookTitle: String,
    val chapterTitle: String,
    val state: String,
    val chapterIndex: Int,
    val chapterCount: Int,
    val progress: Double,
) {
    companion object {
        private val supportedStates = setOf("loading", "playing", "paused", "error")

        fun from(call: MethodCall): ReaderAloudNotificationData? {
            val bookTitle = call.argument<String>("bookTitle")?.trim().orEmpty()
            val chapterTitle = call.argument<String>("chapterTitle")?.trim().orEmpty()
            val state = call.argument<String>("state")?.trim().orEmpty()
            val chapterIndex = (call.argument<Number>("chapterIndex") ?: return null).toInt()
            val chapterCount = (call.argument<Number>("chapterCount") ?: return null).toInt()
            val progress = (call.argument<Number>("progress") ?: return null).toDouble()
            if (bookTitle.isEmpty() || chapterTitle.isEmpty() || state !in supportedStates) {
                return null
            }
            if (!progress.isFinite()) return null
            val safeChapterCount = chapterCount.coerceAtLeast(1)
            return ReaderAloudNotificationData(
                bookTitle = bookTitle,
                chapterTitle = chapterTitle,
                state = state,
                chapterIndex = chapterIndex.coerceIn(0, safeChapterCount - 1),
                chapterCount = safeChapterCount,
                progress = progress.coerceIn(0.0, 1.0),
            )
        }
    }
}

class ReaderAloudForegroundService : Service() {
    companion object {
        private const val ACTION_SHOW = "com.niki.xxread.READER_ALOUD_SHOW"
        private const val ACTION_CONTROL = "com.niki.xxread.READER_ALOUD_CONTROL"
        private const val EXTRA_CONTROL = "control"
        private const val CHANNEL_ID = "reader_aloud"
        private const val NOTIFICATION_ID = 9201
        private const val ANDROID_16_API_LEVEL = 36
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

        fun show(context: Context, data: ReaderAloudNotificationData) {
            val intent = Intent(context, ReaderAloudForegroundService::class.java).apply {
                action = ACTION_SHOW
                putExtra("bookTitle", data.bookTitle)
                putExtra("chapterTitle", data.chapterTitle)
                putExtra("state", data.state)
                putExtra("chapterIndex", data.chapterIndex)
                putExtra("chapterCount", data.chapterCount)
                putExtra("progress", data.progress)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ReaderAloudForegroundService::class.java))
        }
    }

    private lateinit var mediaSession: MediaSession

    override fun onCreate() {
        super.onCreate()
        createChannel()
        mediaSession = MediaSession(this, "ReaderAloud").apply {
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS,
            )
            setCallback(
                object : MediaSession.Callback() {
                    override fun onSkipToPrevious() = handleControl("previous")
                    override fun onPlay() = handleControl("playPause")
                    override fun onPause() = handleControl("playPause")
                    override fun onSkipToNext() = handleControl("next")
                    override fun onStop() = handleControl("stop")
                },
            )
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> readData(intent)?.let(::showNotification)
            ACTION_CONTROL -> intent.getStringExtra(EXTRA_CONTROL)?.let(::handleControl)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        mediaSession.isActive = false
        mediaSession.release()
        super.onDestroy()
    }

    private fun readData(intent: Intent): ReaderAloudNotificationData? {
        val bookTitle = intent.getStringExtra("bookTitle")?.trim().orEmpty()
        val chapterTitle = intent.getStringExtra("chapterTitle")?.trim().orEmpty()
        val state = intent.getStringExtra("state")?.trim().orEmpty()
        if (bookTitle.isEmpty() || chapterTitle.isEmpty() || state.isEmpty()) return null
        return ReaderAloudNotificationData(
            bookTitle = bookTitle,
            chapterTitle = chapterTitle,
            state = state,
            chapterIndex = intent.getIntExtra("chapterIndex", 0),
            chapterCount = intent.getIntExtra("chapterCount", 0),
            progress = intent.getDoubleExtra("progress", 0.0).coerceIn(0.0, 1.0),
        )
    }

    private fun showNotification(data: ReaderAloudNotificationData) {
        updateMediaSession(data)
        val notification = buildNotification(data)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun handleControl(action: String) {
        if (action !in setOf("previous", "playPause", "next", "stop")) return
        ReaderAloudBridge.dispatchControl(action)
        if (action == "stop") {
            stopForegroundCompat()
            stopSelf()
        }
    }

    private fun updateMediaSession(data: ReaderAloudNotificationData) {
        val playbackState = when (data.state) {
            "playing" -> PlaybackState.STATE_PLAYING
            "paused" -> PlaybackState.STATE_PAUSED
            "loading" -> PlaybackState.STATE_BUFFERING
            "error" -> PlaybackState.STATE_ERROR
            else -> PlaybackState.STATE_NONE
        }
        val actions = PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_STOP
        mediaSession.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(
                    playbackState,
                    (data.progress * 1000).toLong(),
                    if (data.state == "playing") 1f else 0f,
                )
                .build(),
        )
        mediaSession.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, data.chapterTitle)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, data.bookTitle)
                .putLong(MediaMetadata.METADATA_KEY_TRACK_NUMBER, data.chapterIndex.toLong() + 1)
                .putLong(MediaMetadata.METADATA_KEY_NUM_TRACKS, data.chapterCount.toLong())
                .putLong(MediaMetadata.METADATA_KEY_DURATION, 1000L)
                .build(),
        )
    }

    private fun buildNotification(data: ReaderAloudNotificationData): Notification {
        val progress = (data.progress * 1000).toInt().coerceIn(0, 1000)
        val chapterNumber = (data.chapterIndex + 1).coerceAtMost(data.chapterCount.coerceAtLeast(1))
        val builder = notificationBuilder()
            .setContentTitle(data.bookTitle)
            .setContentText(data.chapterTitle)
            .setSubText("第 $chapterNumber / ${data.chapterCount} 章")
            .setContentIntent(contentIntent())
            .setDeleteIntent(controlIntent("stop", 4))
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous,
                    "上一句",
                    controlIntent("previous", 1),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    if (data.state == "playing") android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (data.state == "playing") "暂停" else "播放",
                    controlIntent("playPause", 2),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next,
                    "下一句",
                    controlIntent("next", 3),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "停止",
                    controlIntent("stop", 4),
                ).build(),
            )

        if (Build.VERSION.SDK_INT >= ANDROID_16_API_LEVEL) {
            applyAndroid16Progress(builder, progress, data.state == "loading")
        } else {
            builder
                .setProgress(1000, progress, data.state == "loading")
                .setStyle(
                    Notification.MediaStyle()
                        .setMediaSession(mediaSession.sessionToken)
                        .setShowActionsInCompactView(0, 1, 2),
                )
        }
        requestPromotedOngoingIfAllowed(builder)
        return builder.build()
    }

    private fun notificationBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }.setSmallIcon(R.mipmap.launcher_icon)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

    @TargetApi(ANDROID_16_API_LEVEL)
    private fun applyAndroid16Progress(
        builder: Notification.Builder,
        progress: Int,
        indeterminate: Boolean,
    ) {
        val style = Notification.ProgressStyle()
            .setStyledByProgress(true)
            .setProgressIndeterminate(indeterminate)
        if (!indeterminate) {
            style
                .setProgressSegments(listOf(Notification.ProgressStyle.Segment(1000)))
                .setProgress(progress)
        }
        builder
            .setStyle(style)
            .setShortCriticalText(if (indeterminate) "加载中" else "${progress / 10}%")
    }

    private fun requestPromotedOngoingIfAllowed(builder: Notification.Builder) {
        if (Build.VERSION.SDK_INT < ANDROID_16_API_LEVEL) return
        val manager = notificationManager()
        val allowed = runCatching {
            manager.javaClass
                .getMethod("canPostPromotedNotifications")
                .invoke(manager) as? Boolean
        }.getOrNull() == true
        if (allowed) {
            builder
                .setColor(Color.rgb(38, 102, 163))
                .setColorized(true)
                .addExtras(
                    Bundle().apply {
                        putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                    },
                )
        }
    }

    private fun contentIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun controlIntent(action: String, requestCode: Int): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, ReaderAloudForegroundService::class.java).apply {
                this.action = ACTION_CONTROL
                putExtra(EXTRA_CONTROL, action)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager().createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "听书播放",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(NotificationManager::class.java)

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
