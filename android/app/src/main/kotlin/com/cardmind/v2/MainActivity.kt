package com.cardmind.v2

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.cardmind.v2/update-installer"
        private const val AUTHORITY = "com.cardmind.v2.fileprovider"
        private const val APK_MIME = "application/vnd.android.package-archive"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGUMENT", "APK path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            var file = File(path)
                            if (!file.isFile) {
                                result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                                return@setMethodCallHandler
                            }
                            // Dart 传入的路径形式可能与 FileProvider root 的 canonical 形式不一致
                            // （/data/data vs /data/user/0）。把文件复制/移动到本 context.cacheDir
                            // 下的固定更新目录，再从该目录取 URI，保证路径形式与 cache-path root 一致。
                            val updateDir = File(cacheDir, "cardmind-update")
                            updateDir.mkdirs()
                            val staged = File(updateDir, file.name)
                            if (staged.exists()) staged.delete()
                            file.copyTo(staged)
                            file.delete()
                            val uri = FileProvider.getUriForFile(this, AUTHORITY, staged)
                            result.success(uri.toString())
                        } catch (error: Exception) {
                            result.error("URI_FAILED", error.message, null)
                        }
                    }
                    "installApk" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString == null) {
                            result.error("INVALID_ARGUMENT", "APK URI is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = Uri.parse(uriString)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, APK_MIME)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("INSTALL_FAILED", error.message, null)
                        }
                    }
                    "canInstallUnknownApps" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls(),
                        )
                    }
                    "openUnknownAppsSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
