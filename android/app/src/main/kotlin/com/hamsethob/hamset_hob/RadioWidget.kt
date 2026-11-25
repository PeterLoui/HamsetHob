package com.hamsethob.hamset_hob

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * ويدجت الإذاعة: اللي شغال دلوقتي وزرار تشغيل/إيقاف.
 * - والصوت شغال: الزرار بيبعت «إيقاف» لجلسة الصوت (زي سماعة البلوتوث) من غير ما يفتح التطبيق.
 * - والصوت واقف: الزرار بيفتح التطبيق ويكمّل آخر محطة أو البث المتواصل، لأن خدمة الصوت ممكن تكون اتقفلت.
 * Flutter بيبعت الحالة كل ما تتغير (updateRadioWidget).
 */
object RadioWidget {
    private const val PREFS = "radio_widget"
    const val ACTION_RESUME = "com.hamsethob.hamset_hob.RESUME_RADIO"

    fun save(ctx: Context, title: String, sub: String, playing: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("title", title)
            .putString("sub", sub)
            .putBoolean("playing", playing)
            .apply()
        render(ctx)
    }

    fun render(ctx: Context) {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = p.getString("title", "") ?: ""
        val playing = p.getBoolean("playing", false)
        val open = PendingIntent.getActivity(
            ctx, 20, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val button = if (playing) mediaButton(ctx) else resume(ctx)
        val views = RemoteViews(ctx.packageName, R.layout.widget_radio).apply {
            setTextViewText(R.id.radio_status, if (playing) "يُذاع الآن" else if (title.isEmpty()) "الإذاعة" else "متوقف")
            setTextViewText(R.id.radio_title, title.ifEmpty { "إذاعات وعظات البابا شنودة" })
            setTextViewText(R.id.radio_sub, (p.getString("sub", "") ?: "").ifEmpty { "اضغط للتشغيل" })
            setImageViewResource(R.id.radio_icon, if (playing) R.drawable.widget_ic_pause else R.drawable.widget_ic_play)
            setContentDescription(R.id.radio_button, if (playing) "إيقاف" else "تشغيل")
            setOnClickPendingIntent(R.id.root, open)
            setOnClickPendingIntent(R.id.radio_button, button)
        }
        AppWidgetManager.getInstance(ctx).updateAppWidget(ComponentName(ctx, RadioWidgetProvider::class.java), views)
    }

    /** زرار «تشغيل/إيقاف» لجلسة الصوت عن طريق مستقبل أزرار الوسائط بتاع audio_service. */
    private fun mediaButton(ctx: Context): PendingIntent {
        val now = SystemClock.uptimeMillis()
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
            .setComponent(ComponentName(ctx, "com.ryanheise.audioservice.MediaButtonReceiver"))
            .putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(now, now, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 0))
        return PendingIntent.getBroadcast(ctx, 21, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun resume(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java)
            .setAction(ACTION_RESUME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(ctx, 22, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class RadioWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = RadioWidget.render(context)
}
