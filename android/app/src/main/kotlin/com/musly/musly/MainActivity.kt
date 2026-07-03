package com.devid.musly

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val updateInstallerChannel = "com.devid.musly/update_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine.plugins.add(AndroidAutoPlugin)
        
        flutterEngine.plugins.add(AndroidSystemPlugin)
        
        flutterEngine.plugins.add(BluetoothAvrcpPlugin)
        
        flutterEngine.plugins.add(SamsungIntegrationPlugin)
        
        // Register lyrics plugin for lock screen lyrics support
        LyricsPlugin.registerWith(flutterEngine)

        // Register pitch plugin for ExoPlayer pitch control
        PitchPlugin.registerWith(flutterEngine)

        // Register Dolby Atmos plugin for device-capability detection
        DolbyAtmosPlugin.registerWith(flutterEngine, this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            updateInstallerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(canRequestPackageInstalls())
                }
                "openUnknownSourcesSettings" -> {
                    openUnknownSourcesSettings()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is required", null)
                    } else {
                        installApk(path, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownSourcesSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists()) {
            result.error("missing_apk", "APK file does not exist", null)
            return
        }
        if (!canRequestPackageInstalls()) {
            result.error("install_permission_required", "Install permission is required", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("no_installer", "No APK installer is available", null)
            return
        }
        startActivity(intent)
        result.success(null)
    }
}
