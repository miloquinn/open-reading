package com.niki.xxread

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class AppUpdateBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.niki.xxread/app_update"
    }

    private var pendingInstall: PendingInstall? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    fun onResume() {
        val pending = pendingInstall ?: return
        pendingInstall = null
        if (!canRequestPackageInstalls()) {
            pending.result.error(
                "install_permission_denied",
                "Permission to install unknown applications was not granted",
                null,
            )
            return
        }
        runCatching {
            val apk = validateCacheFile(pending.apk.path)
            validateApk(apk, pending.expectedBuildNumber)
            openSystemInstaller(apk)
        }.onSuccess { pending.result.success("installer_opened") }
            .onFailure {
                pending.result.error(
                    "install_rejected",
                    it.message ?: "APK validation failed",
                    null,
                )
            }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val rawPath = call.argument<String>("path")
        val expectedBuildNumber = call.argument<String>("expectedBuildNumber")
        if (rawPath.isNullOrBlank()) {
            result.error("invalid_args", "APK path is required", null)
            return
        }
        if (pendingInstall != null) {
            result.error("install_busy", "Another update installation is pending", null)
            return
        }

        val validated = runCatching {
            val apk = validateCacheFile(rawPath)
            validateApk(apk, expectedBuildNumber)
            apk
        }.getOrElse {
            result.error("install_rejected", it.message ?: "APK validation failed", null)
            return
        }
        if (canRequestPackageInstalls()) {
            runCatching { openSystemInstaller(validated) }
                .onSuccess { result.success("installer_opened") }
                .onFailure { result.error("install_failed", it.message, null) }
            return
        }

        val buildNumber = expectedBuildNumber
            ?: run {
                result.error("invalid_args", "Expected build number is required", null)
                return
            }
        pendingInstall = PendingInstall(validated, buildNumber, result)
        runCatching { openInstallPermissionSettings() }
            .onFailure {
                pendingInstall = null
                result.error("permission_settings_failed", it.message, null)
            }
    }

    private fun validateCacheFile(rawPath: String): File {
        val updatesRoot = File(activity.cacheDir, "updates").canonicalFile
        val apk = File(rawPath).canonicalFile
        require(apk.isFile && apk.extension.equals("apk", ignoreCase = true)) {
            "The update APK does not exist"
        }
        require(apk.parentFile == updatesRoot) { "The update APK is outside the update cache" }
        return apk
    }

    private fun validateApk(apk: File, expectedBuildNumber: String?) {
        val archive = archivePackageInfo(apk)
            ?: error("Android could not read the update package")
        require(archive.packageName == activity.packageName) {
            "The update package belongs to another application"
        }

        val installed = installedPackageInfo()
        val archiveVersion = archive.longVersionCodeCompat()
        val installedVersion = installed.longVersionCodeCompat()
        require(archiveVersion > installedVersion) {
            "The update version is not newer than the installed application"
        }
        val expected = expectedBuildNumber?.toLongOrNull()
            ?: error("The expected update build number is invalid")
        require(expected > 0 && archiveVersion == expected) {
            "The update build number does not match its metadata"
        }

        val installedCertificates = installed.signingCertificateDigests()
        val archiveCertificates = archive.signingCertificateDigests()
        require(installedCertificates.isNotEmpty() && archiveCertificates.isNotEmpty()) {
            "The update signing certificate is unavailable"
        }
        require(installedCertificates == archiveCertificates) {
            "The update is not signed by the installed application's identity"
        }
    }

    @Suppress("DEPRECATION")
    private fun archivePackageInfo(apk: File): PackageInfo? {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        return activity.packageManager.getPackageArchiveInfo(apk.path, flags)
    }

    @Suppress("DEPRECATION")
    private fun installedPackageInfo(): PackageInfo {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        return activity.packageManager.getPackageInfo(activity.packageName, flags)
    }

    @Suppress("DEPRECATION")
    private fun PackageInfo.longVersionCodeCompat(): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun PackageInfo.signingCertificateDigests(): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = signingInfo ?: return emptySet()
            info.apkContentsSigners
        } else {
            signatures ?: emptyArray()
        }
        return signatures.mapTo(mutableSetOf()) { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { byte ->
                    (byte.toInt() and 0xff).toString(16).padStart(2, '0')
                }
        }
    }

    private fun canRequestPackageInstalls(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        activity.startActivity(intent)
    }

    private fun openSystemInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.update_provider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }

    private data class PendingInstall(
        val apk: File,
        val expectedBuildNumber: String,
        val result: MethodChannel.Result,
    )
}
