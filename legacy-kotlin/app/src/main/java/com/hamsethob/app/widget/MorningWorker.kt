package com.hamsethob.app.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.hamsethob.app.R
import com.hamsethob.app.bible.BibleRepository
import com.hamsethob.app.data.AppSettings
import com.hamsethob.app.share.label
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit

/** إشعار صباحي برسالة اليوم في الوقت الذي يختاره المستخدم؛ يعيد جدولة نفسه كل يوم. */
class MorningWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val settings = AppSettings.get(applicationContext)
        if (!settings.morningEnabled) return Result.success()

        val verse = runCatching { BibleRepository(applicationContext).dailyVerse(LocalDate.now()) }.getOrNull()
        if (verse != null) {
            val nm = NotificationManagerCompat.from(applicationContext)
            if (nm.areNotificationsEnabled()) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "إشعار رسالة الصباح", NotificationManager.IMPORTANCE_DEFAULT)
                )
                val notification = NotificationCompat.Builder(applicationContext, CHANNEL)
                    .setSmallIcon(R.drawable.ic_stat_cross)
                    .setContentTitle("صباح الخير ♡ رسالة اليوم")
                    .setContentText(verse.text)
                    .setStyle(NotificationCompat.BigTextStyle().bigText("«${verse.text}»\n${verse.ref.label()}"))
                    .setContentIntent(Widgets.openChapterIntent(applicationContext, verse))
                    .setAutoCancel(true)
                    .build()
                try {
                    nm.notify(NOTIFICATION_ID, notification)
                } catch (_: SecurityException) {
                }
            }
        }
        schedule(applicationContext)
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "morning_verse"
        private const val NOTIFICATION_ID = 8
        private const val WORK = "morning_verse"

        fun schedule(context: Context) {
            val settings = AppSettings.get(context)
            val wm = WorkManager.getInstance(context)
            if (!settings.morningEnabled) {
                wm.cancelUniqueWork(WORK)
                return
            }
            val now = LocalDateTime.now()
            val at = LocalTime.of(settings.morningMinutes / 60, settings.morningMinutes % 60)
            var next = now.toLocalDate().atTime(at)
            if (!next.isAfter(now)) next = next.plusDays(1)
            wm.enqueueUniqueWork(
                WORK,
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<MorningWorker>()
                    .setInitialDelay(Duration.between(now, next).toMillis(), TimeUnit.MILLISECONDS)
                    .build(),
            )
        }
    }
}
