package com.hamsethob.hamset_hob

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** النشاط الرئيسي: يدعم التشغيل في الخلفية (AudioServiceActivity) وقناة الويدجتس. */
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var launchRef: Map<String, Int>? = null
    /** الصلاة اللي إشعار التذكير فتح التطبيق عشانها (رقمها في الأجبية). */
    private var launchPrayer: String? = null
    /** إشعار «نسخة جديدة» اتضغط: التطبيق يعرض شاشة التحديث. */
    private var launchUpdate = false
    private var levels: AudioLevels? = null
    private var micResult: MethodChannel.Result? = null
    /** اتفتح من زرار التشغيل في ويدجت الإذاعة: Flutter بيسأل عنه أول ما يبدأ. */
    private var pendingResume = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        DailyReceiver.schedule(this)
        AppUpdates.schedule(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchRef = refFrom(intent)
        launchPrayer = intent?.getStringExtra(Reminders.EXTRA_PRAYER)
        launchUpdate = intent?.getBooleanExtra(AppUpdates.EXTRA_UPDATE, false) == true
        pendingResume = intent?.action == RadioWidget.ACTION_RESUME
        val lv = AudioLevels(applicationContext).also { levels = it }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "hamset/levels").setStreamHandler(lv)
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
                    "startLevels" -> result.success(lv.start(call.argument<Int>("session") ?: 0))
                    "stopLevels" -> {
                        lv.stop()
                        result.success(null)
                    }
                    "requestMic" -> {
                        // إذن الميكروفون للـ Visualizer بس (الضوء المتزامن مع الإيقاع)، التطبيق مابيسجّلش حاجة
                        if (lv.hasPermission()) {
                            result.success(true)
                        } else {
                            micResult?.success(false)
                            micResult = result
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
                        }
                    }
                    "openBackgroundSettings" ->
                        result.success(PlaybackLocks.openBackgroundSettings(this@MainActivity, call.argument<String>("kind") ?: "battery"))
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
                    "updateRadioWidget" -> {
                        RadioWidget.save(
                            ctx,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("sub") ?: "",
                            call.argument<Boolean>("playing") == true,
                        )
                        result.success(null)
                    }
                    "takeResume" -> {
                        result.success(pendingResume)
                        pendingResume = false
                    }
                    "updateCalendarWidget" -> {
                        CalendarWidget.save(ctx, call.arguments as Map<*, *>)
                        result.success(null)
                    }
                    "autoStations" -> {
                        @Suppress("UNCHECKED_CAST")
                        AutoService.saveStations(ctx, (call.argument<List<Map<*, *>>>("list") ?: emptyList()))
                        result.success(null)
                    }
                    "appBuild" -> result.success(AppUpdates.installedBuild(ctx))
                    "setUpdateOptions" -> {
                        AppUpdates.setOptions(ctx, call.argument<Boolean>("enabled") != false, call.argument<Boolean>("beta") != false)
                        result.success(null)
                    }
                    "installApk" -> result.success(AppUpdates.install(this@MainActivity, call.argument<String>("path") ?: ""))
                    "takeLaunchUpdate" -> {
                        result.success(launchUpdate)
                        launchUpdate = false
                    }
                    "mediaUpdate" -> {
                        MediaNotificationService.update(
                            ctx,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("subtitle") ?: "",
                            call.argument<Boolean>("playing") == true,
                            call.argument<Boolean>("live") == true,
                            (call.argument<Number>("pos") ?: 0).toLong(),
                            (call.argument<Number>("dur") ?: 0).toLong(),
                        )
                        result.success(null)
                    }
                    "keepAwake" -> {
                        val on = call.argument<Boolean>("on") == true
                        runOnUiThread {
                            if (on) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "mediaHide" -> {
                        MediaNotificationService.hide(ctx)
                        result.success(null)
                    }
                    "hasMediaNotification" -> result.success(
                        if (Build.VERSION.SDK_INT >= 23) MediaNotificationService.hasOtherMediaNotification(ctx) else true,
                    )
                    "mediaStatus" -> {
                        // فحص أسباب اختفاء أزرار التشغيل من شاشة القفل وشريط الإشعارات
                        val nm = ctx.getSystemService(android.app.NotificationManager::class.java)
                        val pm = ctx.getSystemService(android.os.PowerManager::class.java)
                        val channel = if (Build.VERSION.SDK_INT >= 26) nm.getNotificationChannel("com.hamsethob.radio") else null
                        result.success(
                            mapOf(
                                "notifications" to nm.areNotificationsEnabled(),
                                // -1: القناة لسه ماتعملتش (ماشتغلش صوت قبل كده)، ٠: مقفولة
                                "channel" to (channel?.importance ?: -1),
                                "battery" to pm.isIgnoringBatteryOptimizations(ctx.packageName),
                                // الإشعارات الظاهرة دلوقتي من التطبيق: هل فيه إشعار تشغيل صوت (MediaStyle) فعلاً؟
                                "mediaNotification" to (if (Build.VERSION.SDK_INT >= 23) nm.activeNotifications.any {
                                    it.notification.extras.getString(android.app.Notification.EXTRA_TEMPLATE)?.contains("MediaStyle") == true
                                } else false),
                                "sdk" to Build.VERSION.SDK_INT,
                                "maker" to Build.MANUFACTURER,
                            )
                        )
                    }
                    "notificationsEnabled" ->
                        result.success(ctx.getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled())
                    "openNotificationSettings" -> {
                        try {
                            startActivity(
                                Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, ctx.packageName),
                            )
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    "scheduleReminders" -> {
                        Reminders.save(ctx, call.argument<List<*>>("list") ?: emptyList<Any>())
                        result.success(null)
                    }
                    "takeLaunchPrayer" -> {
                        result.success(launchPrayer)
                        launchPrayer = null
                    }
                    "takeLaunchRef" -> {
                        result.success(launchRef)
                        launchRef = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // أزرار إشعار التحكم الاحتياطي بتوصل لـ Flutter عن طريق نفس القناة
        MediaNotificationService.channel = channel
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_REQUEST) {
            micResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            micResult = null
        }
    }

    override fun onDestroy() {
        levels?.stop()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        refFrom(intent)?.let { channel?.invokeMethod("openRef", it) }
        intent.getStringExtra(Reminders.EXTRA_PRAYER)?.let { channel?.invokeMethod("openPrayer", it) }
        if (intent.getBooleanExtra(AppUpdates.EXTRA_UPDATE, false)) channel?.invokeMethod("openUpdate", null)
        if (intent.action == RadioWidget.ACTION_RESUME) channel?.invokeMethod("resumeRadio", null)
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
        private const val MIC_REQUEST = 7
    }
}
