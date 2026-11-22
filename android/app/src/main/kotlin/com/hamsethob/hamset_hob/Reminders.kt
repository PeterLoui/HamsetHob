package com.hamsethob.hamset_hob

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * تذكيرات الصلاة (يومية) وتنبيهات مساء اليوم السابق للأعياد والأصوام (مرة واحدة).
 *
 * التطبيق بيبعت القايمة كلها، وهنا بنحفظها ونجدولها بـ setAndAllowWhileIdle: بتشتغل والتليفون في وضع السكون،
 * لكن النظام ممكن يأخّرها دقايق لتوفير البطارية (المنبّه الدقيق محتاج إذن خاص من المستخدم).
 * التذكير اليومي بيجدّد نفسه بعد ما يظهر، وكل التذكيرات بتتجدول من جديد بعد إعادة تشغيل التليفون.
 */
object Reminders {
    private const val PREFS = "hamset_reminders"
    private const val CHANNEL = "reminders"
    const val EXTRA_PRAYER = "prayer"

    /** القايمة من Flutter: بتتحفظ وبتتجدول، والتذكيرات اللي اتشالت بتتلغي. */
    fun save(ctx: Context, list: List<*>) {
        val arr = JSONArray()
        for (item in list) {
            val m = item as? Map<*, *> ?: continue
            arr.put(JSONObject().apply {
                put("id", (m["id"] as Number).toInt())
                put("title", m["title"] as? String ?: "")
                put("body", m["body"] as? String ?: "")
                (m["minutes"] as? Number)?.let { put("minutes", it.toInt()) }
                (m["at"] as? Number)?.let { put("at", it.toLong()) }
                (m["prayer"] as? String)?.let { put("prayer", it) }
            })
        }
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        cancelAll(ctx, prefs.getString("ids", "") ?: "")
        prefs.edit().putString("list", arr.toString()).apply()
        scheduleAll(ctx)
    }

    private fun cancelAll(ctx: Context, ids: String) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        for (id in ids.split(',').mapNotNull { it.toIntOrNull() }) {
            pending(ctx, id, null, PendingIntent.FLAG_NO_CREATE)?.let { am.cancel(it); it.cancel() }
        }
    }

    /** يجدول كل المحفوظ (بعد الحفظ، وبعد إعادة تشغيل التليفون). */
    fun scheduleAll(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try { JSONArray(prefs.getString("list", "[]")) } catch (_: Exception) { JSONArray() }
        val ids = ArrayList<Int>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val id = o.getInt("id")
            val at = nextTime(o, LocalDateTime.now()) ?: continue
            schedule(ctx, id, o, at)
            ids.add(id)
        }
        prefs.edit().putString("ids", ids.joinToString(",")).apply()
    }

    /** وقت التذكير الجاي بالميلي ثانية، أو null لو مرة واحدة وفات. [now] بيتزوّد في الإعادة بعد الظهور عشان ماينزلش مرتين. */
    private fun nextTime(o: JSONObject, now: LocalDateTime): Long? {
        val zone = ZoneId.systemDefault()
        if (o.has("minutes")) {
            val m = o.getInt("minutes")
            var next = now.toLocalDate().atTime(LocalTime.of(m / 60, m % 60))
            if (!next.isAfter(now)) next = next.plusDays(1)
            return next.atZone(zone).toInstant().toEpochMilli()
        }
        val at = o.optLong("at", 0)
        return if (at > System.currentTimeMillis()) at else null
    }

    private fun pending(ctx: Context, id: Int, o: JSONObject?, flag: Int): PendingIntent? {
        val intent = Intent(ctx, ReminderReceiver::class.java).setData(Uri.parse("hamset://reminder/$id"))
        if (o != null) {
            intent.putExtra("id", id)
            intent.putExtra("title", o.optString("title"))
            intent.putExtra("body", o.optString("body"))
            if (o.has("prayer")) intent.putExtra(EXTRA_PRAYER, o.getString("prayer"))
        }
        return PendingIntent.getBroadcast(ctx, id, intent, flag or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun schedule(ctx: Context, id: Int, o: JSONObject, at: Long) {
        val pi = pending(ctx, id, o, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        ctx.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    }

    /** بعد ما تذكير يومي يظهر: الجاي بكرة. */
    fun reschedule(ctx: Context, id: Int) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try { JSONArray(prefs.getString("list", "[]")) } catch (_: Exception) { return }
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.getInt("id") != id || !o.has("minutes")) continue
            // دقيقة زيادة: لو المنبّه رنّ قبل الميعاد بثواني ماننزلش التذكير مرتين
            nextTime(o, LocalDateTime.now().plusMinutes(1))?.let { schedule(ctx, id, o, it) }
            return
        }
    }

    fun show(ctx: Context, id: Int, title: String, body: String, prayer: String?) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "تذكير الصلاة والأعياد", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(
            ctx, id,
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                if (prayer != null) putExtra(EXTRA_PRAYER, prayer)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(id, n)
        } catch (_: SecurityException) {
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        if (id < 0) return
        Reminders.show(
            context, id,
            intent.getStringExtra("title") ?: "",
            intent.getStringExtra("body") ?: "",
            intent.getStringExtra(Reminders.EXTRA_PRAYER),
        )
        Reminders.reschedule(context, id)
    }
}
