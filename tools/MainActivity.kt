package com.aihub.ai_hub

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Small bridge between the Flutter app and Termux.
 * Channel name: com.aihub/termux
 * Methods: isTermuxInstalled, hasRunCommandPermission, requestRunCommandPermission,
 *          startGateway, openAppSettings
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.aihub/termux"
    private val termuxPackage = "com.termux"
    private val runCommandPermission = "com.termux.permission.RUN_COMMAND"
    private val homePath = "/data/data/com.termux/files/home"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isTermuxInstalled" -> result.success(isTermuxInstalled())
                        "hasRunCommandPermission" -> result.success(hasRunCommandPermission())
                        "requestRunCommandPermission" -> {
                            requestPermissions(arrayOf(runCommandPermission), 7001)
                            result.success(true)
                        }
                        "startGateway" -> {
                            val script = call.argument<String>("script") ?: "startgateway.sh"
                            startGateway(script)
                            result.success(true)
                        }
                        "openAppSettings" -> {
                            openAppSettings()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("TERMUX_ERROR", e.message ?: "Unknown error", null)
                }
            }
    }

    private fun isTermuxInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(termuxPackage, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun hasRunCommandPermission(): Boolean {
        return checkSelfPermission(runCommandPermission) == PackageManager.PERMISSION_GRANTED
    }

    /** Asks Termux to run ~/startgateway.sh in the background. */
    private fun startGateway(scriptName: String) {
        val intent = Intent().apply {
            setClassName(termuxPackage, "com.termux.app.RunCommandService")
            action = "com.termux.RUN_COMMAND"
            putExtra("com.termux.RUN_COMMAND_PATH", "$homePath/$scriptName")
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf<String>())
            putExtra("com.termux.RUN_COMMAND_WORKDIR", homePath)
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
