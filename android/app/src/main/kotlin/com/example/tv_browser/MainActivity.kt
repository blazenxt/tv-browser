package com.example.tv_browser

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channelName = "tvbrowser/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "download.bin"
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        if (path == null) {
                            result.error("BAD_ARGS", "path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = saveToDownloads(File(path), name, mime)
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Copies [src] into the public Downloads collection and deletes the temp file. */
    private fun saveToDownloads(src: File, name: String, mime: String): Boolean {
        if (!src.exists()) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(src, name, mime)
        } else {
            saveLegacy(src, name)
        }
    }

    private fun saveViaMediaStore(src: File, name: String, mime: String): Boolean {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values) ?: return false
        val ok = resolver.openOutputStream(uri)?.use { out ->
            src.inputStream().use { it.copyTo(out) }
            true
        } ?: false
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        if (ok) src.delete()
        return ok
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(src: File, name: String): Boolean {
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists()) dir.mkdirs()
        val dest = File(dir, name)
        src.inputStream().use { input -> dest.outputStream().use { input.copyTo(it) } }
        src.delete()
        return true
    }
}
