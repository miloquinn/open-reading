package com.niki.xxread

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.graphics.Color
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.KeyEvent
import androidx.core.view.WindowCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.niki.xxread/fullscreen"
    private val READER_KEYS_CHANNEL = "com.niki.xxread/reader_keys"
    private var readerKeysChannel: MethodChannel? = null
    private var safDirectoryBridge: SafDirectoryBridge? = null
    @Volatile private var volumePagingEnabled: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 启用 edge-to-edge 模式
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // 设置透明的系统栏颜色
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        // Android 9+ (API 28+): 设置导航栏分割线透明
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hideSystemUI" -> {
                    hideSystemUI()
                    result.success(null)
                }
                "showSystemUI" -> {
                    showSystemUI()
                    result.success(null)
                }
                "enableHighRefreshRate" -> {
                    enableHighRefreshRate()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        readerKeysChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            READER_KEYS_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolumePagingEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        volumePagingEnabled = enabled
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        safDirectoryBridge = SafDirectoryBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )

    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (safDirectoryBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumePagingEnabled &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_UP)
        ) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                val direction = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                    "next"
                } else {
                    "previous"
                }
                try {
                    readerKeysChannel?.invokeMethod(
                        "onVolumeKey",
                        mapOf("direction" to direction),
                    )
                } catch (e: Exception) {
                    Log.w("xxread", "dispatch volume key failed: ${e.message}")
                }
            }
            // 消费事件，避免系统弹出音量面板，保持阅读沉浸。
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun hideSystemUI() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Android 11+ (API 30+): 使用 WindowInsetsController
            window.insetsController?.let { controller ->
                // 隐藏状态栏和导航栏（包括手势提示线）
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                // 使用 IMMERSIVE 模式，确保系统UI完全隐藏且不会自动弹出
                // BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE: 从边缘滑动时系统栏会短暂显示然后自动隐藏
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }

            // 额外设置：确保导航栏手势提示线也被隐藏
            // 在某些设备上需要额外的配置来完全隐藏手势提示线
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
        } else {
            // Android 10 及以下: 使用废弃的标志（但仍然有效）
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    private fun showSystemUI() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Android 11+ (API 30+): 使用 WindowInsetsController
            window.insetsController?.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
        } else {
            // Android 10 及以下: 清除全屏标志
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
    }

    private fun enableHighRefreshRate() {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M) {
            return
        }
        try {
            val display = windowManager.defaultDisplay
            val modes = display.supportedModes
            if (modes.isEmpty()) {
                return
            }

            val currentMode = display.mode
            val bestMode = modes
                .filter { it.physicalWidth == currentMode.physicalWidth && it.physicalHeight == currentMode.physicalHeight }
                .maxByOrNull { it.refreshRate }
                ?: modes.maxByOrNull { it.refreshRate }
                ?: return

            val attrs = window.attributes
            if (attrs.preferredDisplayModeId != bestMode.modeId) {
                attrs.preferredDisplayModeId = bestMode.modeId
                window.attributes = attrs
            }
        } catch (e: Exception) {
            Log.w("xxread", "enableHighRefreshRate failed: ${e.message}")
        }
    }
}
