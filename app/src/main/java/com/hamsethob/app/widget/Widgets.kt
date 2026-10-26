package com.hamsethob.app.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.hamsethob.app.MainActivity
import com.hamsethob.app.R
import com.hamsethob.app.bible.BibleRepository
import com.hamsethob.app.bible.DailyVerse
import com.hamsethob.app.calendar.CopticDate
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.data.AppSettings
import java.time.LocalDate
import java.util.concurrent.TimeUnit

/** ويدجت رسالة اليوم للشاشة الرئيسية. */
class VerseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        DailyWorker.refreshNow(context)
}

/** ويدجت شاشة القفل: التاريخ القبطي ورسالة اليوم فقط. */
class LockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        DailyWorker.refreshNow(context)
}

/** يحدّث الويدجتس وإشعار شاشة القفل كل ساعة (ويتجاوز منتصف الليل تلقائياً). */
class DailyWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val verse = runCatching { BibleRepository(applicationContext).dailyVerse(LocalDate.now()) }.getOrNull()
        Widgets.render(applicationContext, verse)
        return if (verse == null) Result.retry() else Result.success()
    }

    companion object {
        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "daily_verse",
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<DailyWorker>(1, TimeUnit.HOURS).build(),
            )
            refreshNow(context)
        }

        fun refreshNow(context: Context) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                "daily_verse_now",
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<DailyWorker>().build(),
            )
        }
    }
}

object Widgets {
    private const val CHANNEL = "lock_verse"
    private const val NOTIFICATION_ID = 7

    fun render(context: Context, verse: DailyVerse?) {
        val today = LocalDate.now()
        val coptic = CopticDate.fromGregorian(today)
        val copticText = "${coptic.day.arabicDigits()} ${coptic.monthName} ${coptic.year.arabicDigits()} ش"
        val verseText = verse?.let { "«${it.text}»" } ?: "افتح التطبيق لتحميل رسالة اليوم"
        val refText = verse?.let { "${it.ref.bookName} ${it.ref.chapter.arabicDigits()} : ${it.ref.verse.arabicDigits()}" } ?: ""
        val open = openChapterIntent(context, verse)
        val manager = AppWidgetManager.getInstance(context)

        val home = RemoteViews(context.packageName, R.layout.widget_verse).apply {
            setTextViewText(R.id.coptic_date, copticText)
            setTextViewText(R.id.verse_text, verseText)
            setTextViewText(R.id.verse_ref, refText)
            setOnClickPendingIntent(R.id.root, open)
        }
        manager.updateAppWidget(ComponentName(context, VerseWidgetProvider::class.java), home)

        val lock = RemoteViews(context.packageName, R.layout.widget_lock).apply {
            setTextViewText(R.id.coptic_day, coptic.day.arabicDigits())
            setTextViewText(R.id.coptic_month, "${coptic.monthName} ${coptic.year.arabicDigits()} ش")
            setTextViewText(R.id.verse_text, verseText)
            setTextViewText(R.id.verse_ref, refText)
            setOnClickPendingIntent(R.id.root, open)
        }
        manager.updateAppWidget(ComponentName(context, LockWidgetProvider::class.java), lock)

        showLockNotification(context, copticText, verseText, refText, open)
    }

    /**
     * أغلب هواتف أندرويد (ومنها Magic OS) لا تسمح بويدجتس طرف ثالث على شاشة القفل،
     * لذلك نعرض نفس المحتوى في إشعار هادئ ظاهر على شاشة القفل.
     */
    private fun showLockNotification(context: Context, title: String, verse: String, ref: String, open: PendingIntent) {
        val nm = NotificationManagerCompat.from(context)
        if (!AppSettings.get(context).lockNotification) {
            nm.cancel(NOTIFICATION_ID)
            return
        }
        if (!nm.areNotificationsEnabled()) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "رسالة اليوم على شاشة القفل", NotificationManager.IMPORTANCE_LOW).apply {
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            }
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle(title)
            .setContentText(verse)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$verse\n$ref"))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSilent(true)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
        }
    }

    fun openChapterIntent(context: Context, verse: DailyVerse?): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            verse?.let {
                putExtra(MainActivity.EXTRA_BOOK, it.ref.book)
                putExtra(MainActivity.EXTRA_CHAPTER, it.ref.chapter)
                putExtra(MainActivity.EXTRA_VERSE, it.ref.verse)
            }
        }
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
