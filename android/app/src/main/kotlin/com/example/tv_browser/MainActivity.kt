package com.example.tv_browser

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import android.net.Uri
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val downloadsChannelName = "tvbrowser/downloads"
    private val remoteChannelName = "tvbrowser/remote"
    private lateinit var remoteChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannelName)
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

        remoteChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            remoteChannelName,
        )
        remoteChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "tapWebView" -> result.success(
                    dispatchWebPointer(call.argument<Double>("x"), call.argument<Double>("y"), true),
                )
                "moveWebPointer" -> result.success(
                    dispatchWebPointer(call.argument<Double>("x"), call.argument<Double>("y"), false),
                )
                "focusFlutter" -> {
                    focusedWebView()?.clearFocus()
                    result.success(findFlutterView(window.decorView)?.requestFocus() ?: false)
                }
                "openExternal" -> {
                    val url = call.argument<String>("url").orEmpty()
                    try {
                        if (url.isBlank()) {
                            result.success(false)
                        } else {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        }
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val title = call.argument<String>("title") ?: "Share page"
                    if (text.isBlank()) {
                        result.success(false)
                    } else {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(Intent.createChooser(sendIntent, title))
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * A hybrid-composition WebView can own Android input focus and consume the
     * D-pad before Flutter sees it. Forward only navigation keys, and only
     * while a WebView is focused. Flutter UI, dialogs and the software keyboard
     * continue receiving their normal key events.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (
            ::remoteChannel.isInitialized &&
            isRemoteNavigationKey(event.keyCode) &&
            focusedWebView() != null
        ) {
            remoteChannel.invokeMethod(
                "key",
                mapOf(
                    "keyCode" to event.keyCode,
                    "action" to event.action,
                    "repeatCount" to event.repeatCount,
                ),
            )
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun isRemoteNavigationKey(keyCode: Int): Boolean = when (keyCode) {
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
        KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER,
        KeyEvent.KEYCODE_BUTTON_A,
        KeyEvent.KEYCODE_BUTTON_B,
        KeyEvent.KEYCODE_BUTTON_SELECT,
        KeyEvent.KEYCODE_BACK,
        KeyEvent.KEYCODE_ESCAPE,
        KeyEvent.KEYCODE_MENU,
        KeyEvent.KEYCODE_SEARCH,
        KeyEvent.KEYCODE_TV_CONTENTS_MENU,
        KeyEvent.KEYCODE_TV_MEDIA_CONTEXT_MENU -> true
        else -> false
    }

    private fun focusedWebView(): WebView? {
        var view: View? = currentFocus
        while (view != null) {
            if (view is WebView && view.isShown && view.visibility == View.VISIBLE) return view
            view = view.parent as? View
        }
        return null
    }

    /** Sends a trusted Android hover or touch event to the visible WebView. */
    private fun dispatchWebPointer(rawX: Double?, rawY: Double?, tap: Boolean): Boolean {
        val webView = focusedWebView() ?: findVisibleWebView(window.decorView) ?: return false
        if (webView.width <= 0 || webView.height <= 0) return false

        val normalizedX = (rawX ?: 0.5).coerceIn(0.0, 1.0)
        val normalizedY = (rawY ?: 0.5).coerceIn(0.0, 1.0)
        val x = (normalizedX * webView.width).toFloat()
        val y = (normalizedY * webView.height).toFloat()
        val now = SystemClock.uptimeMillis()

        if (tap) {
            val down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, x, y, 0).apply {
                source = InputDevice.SOURCE_TOUCHSCREEN
            }
            val up = MotionEvent.obtain(now, now + 40, MotionEvent.ACTION_UP, x, y, 0).apply {
                source = InputDevice.SOURCE_TOUCHSCREEN
            }
            try {
                webView.dispatchTouchEvent(down)
                webView.dispatchTouchEvent(up)
            } finally {
                down.recycle()
                up.recycle()
            }
        } else {
            val hover = MotionEvent.obtain(now, now, MotionEvent.ACTION_HOVER_MOVE, x, y, 0).apply {
                source = InputDevice.SOURCE_MOUSE
            }
            try {
                webView.dispatchGenericMotionEvent(hover)
            } finally {
                hover.recycle()
            }
        }
        return true
    }

    private fun findVisibleWebView(view: View): WebView? {
        if (view is WebView && view.isShown && view.visibility == View.VISIBLE) return view
        if (view is ViewGroup) {
            for (index in view.childCount - 1 downTo 0) {
                val found = findVisibleWebView(view.getChildAt(index))
                if (found != null) return found
            }
        }
        return null
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                val found = findFlutterView(view.getChildAt(index))
                if (found != null) return found
            }
        }
        return null
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
