package com.hamsethob.hamset_hob

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** النشاط الرئيسي: يدعم التشغيل في الخلفية (AudioServiceActivity) وقناة الويدجتس. */
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var launchRef: Map<String, Int>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        DailyReceiver.schedule(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchRef = refFrom(intent)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "hamset/levels").setStreamHandler(SoundLevels)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hamset/native").apply {
            setMethodCallHandler { call, result ->
                val ctx = applicationContext
                when (call.method) {
                    "updateWidgets" -> {
                        WidgetStore.save(ctx, call.arguments as Map<*, *>)
                        Widgets.render(ctx)
                        result.success(null)
                    }
                    "setWidgetGlass" -> {
                        val kind = call.argument<String>("kind") ?: "verse"
                        val png = call.argument<ByteArray>("png")
                        if (png != null) WidgetStore.saveGlass(ctx, kind, png)
                        Widgets.render(ctx)
                        result.success(null)
                    }
                    "scheduleMorning" -> {
                        MorningReceiver.schedule(ctx, call.argument<Boolean>("enabled") == true, call.argument<Int>("minutes") ?: 420)
                        result.success(null)
                    }
                    "setPlaybackLock" -> {
                        PlaybackLocks.set(ctx, call.argument<Boolean>("playing") == true)
                        result.success(null)
                    }
                    "requestBatteryExemption" -> {
                        PlaybackLocks.requestBatteryExemption(this@MainActivity)
                        result.success(null)
                    }
                    "startLevels" -> {
                        val id = call.argument<Int>("session") ?: -1
                        if (id < 0) {
                            result.success(false)
                        } else if (SoundLevels.allowed(ctx)) {
                            result.success(SoundLevels.start(ctx, id))
                        } else {
                            if (call.argument<Boolean>("ask") == true) {
                                SoundLevels.pending = id
                                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_LEVELS)
                            }
                            result.success(false)
                        }
                    }
                    "stopLevels" -> {
                        SoundLevels.pending = -1
                        SoundLevels.stop()
                        result.success(null)
                    }
                    "takeLaunchRef" -> {
                        result.success(launchRef)
                        launchRef = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_LEVELS) return
        val id = SoundLevels.pending
        SoundLevels.pending = -1
        if (id >= 0 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) SoundLevels.start(applicationContext, id)
    }

    override fun onDestroy() {
        SoundLevels.stop()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        refFrom(intent)?.let { channel?.invokeMethod("openRef", it) }
    }

    private fun refFrom(intent: Intent?): Map<String, Int>? {
        val book = intent?.getIntExtra(EXTRA_BOOK, 0) ?: 0
        if (book == 0) return null
        return mapOf(
            "book" to book,
            "chapter" to intent!!.getIntExtra(EXTRA_CHAPTER, 1),
            "verse" to intent.getIntExtra(EXTRA_VERSE, 1),
        )
    }

    companion object {
        private const val REQUEST_LEVELS = 2
        const val EXTRA_BOOK = "book"
        const val EXTRA_CHAPTER = "chapter"
        const val EXTRA_VERSE = "verse"
    }
}
