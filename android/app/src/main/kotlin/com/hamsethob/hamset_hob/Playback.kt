package com.hamsethob.hamset_hob

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.PowerManager
import android.provider.Settings

/**
 * إبقاء الصوت شغال والتليفون مقفول: نفس اللي بيعمله ExoPlayer بـ WAKE_MODE_NETWORK.
 * من غيرهم، لما الشاشة تتقفل التليفون بيوقف الشبكة، فالبث بيخلص اللي متخزن ويقف بعد دقيقة أو اتنين.
 * بيتمسكوا بس طول ما فيه صوت شغال، وبيتسابوا أول ما يقف.
 */
object PlaybackLocks {
    private var wake: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null

    @SuppressLint("WakelockTimeout")
    @Suppress("DEPRECATION")
    fun set(ctx: Context, playing: Boolean) {
        val app = ctx.applicationContext
        if (playing) {
            if (wake?.isHeld != true) {
                wake = app.getSystemService(PowerManager::class.java)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "hamset:playback")
                    .apply { setReferenceCounted(false); acquire(6 * 60 * 60 * 1000L) }
            }
            if (wifi?.isHeld != true) {
                wifi = app.getSystemService(WifiManager::class.java)
                    .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "hamset:stream")
                    .apply { setReferenceCounted(false); acquire() }
            }
        } else {
            wake?.let { if (it.isHeld) it.release() }
            wifi?.let { if (it.isHeld) it.release() }
            wake = null
            wifi = null
        }
    }

    /** يطلب مرة واحدة استثناء التطبيق من توفير البطارية عشان النظام مايوقفش الصوت في الخلفية. */
    @SuppressLint("BatteryLife")
    fun requestBatteryExemption(ctx: Context) {
        val pm = ctx.getSystemService(PowerManager::class.java)
        if (pm.isIgnoringBatteryOptimizations(ctx.packageName)) return
        try {
            ctx.startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${ctx.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {
        }
    }
}
