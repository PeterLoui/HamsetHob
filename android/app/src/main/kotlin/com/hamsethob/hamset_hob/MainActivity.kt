package com.hamsethob.hamset_hob

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
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
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hamset/native").apply {
            setMethodCallHandler { call, result ->
                val ctx = applicationContext
                when (call.method) {
                    "updateWidgets" -> {
                        WidgetStore.save(ctx, call.arguments as Map<*, *>)
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
                    "keepScreenOn" -> {
                        // الشاشة ماتطفيش طول ما التسبحة مفتوحة
                        if (call.argument<Boolean>("on") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "requestBatteryExemption" -> {
                        PlaybackLocks.requestBatteryExemption(this@MainActivity)
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
        const val EXTRA_BOOK = "book"
        const val EXTRA_CHAPTER = "chapter"
        const val EXTRA_VERSE = "verse"
    }
}
