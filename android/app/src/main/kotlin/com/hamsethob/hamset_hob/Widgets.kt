package com.hamsethob.hamset_hob

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import kotlin.concurrent.thread
import kotlin.random.Random

// ─── التقويم القبطي (نسخة مختصرة لتبقى الويدجتس صحيحة حتى لو لم يُفتح التطبيق) ───

private val COPTIC_MONTHS = listOf(
    "توت", "بابه", "هاتور", "كيهك", "طوبه", "أمشير", "برمهات",
    "برموده", "بشنس", "بؤونه", "أبيب", "مسرى", "النسيء",
)

fun arabicDigits(n: Int): String = n.toString().map { if (it.isDigit()) '٠' + (it - '0') else it }.joinToString("")

data class CopticDay(val year: Int, val month: Int, val day: Int) {
    val monthName get() = COPTIC_MONTHS[month - 1]
    val label get() = "${arabicDigits(day)} $monthName ${arabicDigits(year)} ش"

    companion object {
        private const val EPOCH = 1825030L
        private fun jdn(y: Int, m: Int, d: Int) = EPOCH - 1 + 365L * (y - 1) + y / 4 + 30L * (m - 1) + d
        fun of(date: LocalDate): CopticDay {
            val j = date.toEpochDay() + 2440588L
            val y = ((4 * (j - EPOCH) + 1463) / 1461).toInt()
            val m = ((j - jdn(y, 1, 1)) / 30).toInt() + 1
            return CopticDay(y, m, (j + 1 - jdn(y, m, 1)).toInt())
        }
    }
}

// ─── التخزين المشترك مع Flutter ───

object WidgetStore {
    private const val PREFS = "hamset_widgets"

    fun save(ctx: Context, a: Map<*, *>) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            putString("text", a["text"] as? String)
            putString("ref", a["ref"] as? String)
            putInt("book", (a["book"] as? Number)?.toInt() ?: 0)
            putInt("chapter", (a["chapter"] as? Number)?.toInt() ?: 1)
            putInt("verse", (a["verse"] as? Number)?.toInt() ?: 1)
            putBoolean("lock", a["lockNotification"] as? Boolean ?: true)
            putString("date", LocalDate.now().toString())
        }.apply()
    }

    fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun glassFile(ctx: Context, kind: String) = File(ctx.filesDir, "widget_glass_$kind.png")

    fun saveGlass(ctx: Context, kind: String, png: ByteArray) = glassFile(ctx, kind).writeBytes(png)

    /** رسالة اليوم بصيغة Flutter (shared_preferences: المفتاح flutter.daily_verse). */
    fun writeFlutterVerse(ctx: Context, book: Int, chapter: Int, verse: Int, text: String) {
        val json = JSONObject()
            .put("date", LocalDate.now().toString())
            .put("book", book).put("chapter", chapter).put("verse", verse).put("text", text)
        ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putString("flutter.daily_verse", json.toString()).apply()
    }
}

// ─── رسم الويدجتس وإشعار شاشة القفل ───

object Widgets {
    private const val LOCK_CHANNEL = "lock_verse"
    private const val LOCK_ID = 7

    fun render(ctx: Context) {
        val p = WidgetStore.prefs(ctx)
        val coptic = CopticDay.of(LocalDate.now())
        val text = p.getString("text", null)?.let { "«$it»" } ?: "افتح التطبيق لتحميل رسالة اليوم"
        val ref = p.getString("ref", "") ?: ""
        val open = openIntent(ctx, p.getInt("book", 0), p.getInt("chapter", 1), p.getInt("verse", 1))
        val manager = AppWidgetManager.getInstance(ctx)

        val home = RemoteViews(ctx.packageName, R.layout.widget_verse).apply {
            setGlass(ctx, this, "verse")
            setTextViewText(R.id.coptic_date, coptic.label)
            setTextViewText(R.id.verse_text, text)
            setTextViewText(R.id.verse_ref, ref)
            setOnClickPendingIntent(R.id.root, open)
        }
        manager.updateAppWidget(ComponentName(ctx, VerseWidgetProvider::class.java), home)

        val lock = RemoteViews(ctx.packageName, R.layout.widget_lock).apply {
            setGlass(ctx, this, "lock")
            setTextViewText(R.id.coptic_day, arabicDigits(coptic.day))
            setTextViewText(R.id.coptic_month, "${coptic.monthName} ${arabicDigits(coptic.year)} ش")
            setTextViewText(R.id.verse_text, text)
            setTextViewText(R.id.verse_ref, ref)
            setOnClickPendingIntent(R.id.root, open)
        }
        manager.updateAppWidget(ComponentName(ctx, LockWidgetProvider::class.java), lock)

        lockNotification(ctx, p.getBoolean("lock", true), coptic.label, text, ref, open)
    }

    /** خلفية الويدجت: صورة الزجاج المرسومة بحزمة liquid_glass_widgets، وإلا خلفية احتياطية. */
    private fun setGlass(ctx: Context, views: RemoteViews, kind: String) {
        val file = WidgetStore.glassFile(ctx, kind)
        val bitmap = if (file.exists()) BitmapFactory.decodeFile(file.path) else null
        if (bitmap != null) views.setImageViewBitmap(R.id.glass, bitmap)
        else views.setImageViewResource(R.id.glass, R.drawable.glass_widget_bg)
    }

    private fun lockNotification(ctx: Context, enabled: Boolean, title: String, text: String, ref: String, open: PendingIntent) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (!enabled) {
            nm.cancel(LOCK_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return
        nm.createNotificationChannel(
            NotificationChannel(LOCK_CHANNEL, "رسالة اليوم على شاشة القفل", NotificationManager.IMPORTANCE_LOW).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            }
        )
        val n = Notification.Builder(ctx, LOCK_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText("$text\n$ref"))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
        try {
            nm.notify(LOCK_ID, n)
        } catch (_: SecurityException) {
        }
    }

    fun openIntent(ctx: Context, book: Int, chapter: Int, verse: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (book > 0) {
                putExtra(MainActivity.EXTRA_BOOK, book)
                putExtra(MainActivity.EXTRA_CHAPTER, chapter)
                putExtra(MainActivity.EXTRA_VERSE, verse)
            }
        }
        return PendingIntent.getActivity(ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class VerseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Widgets.render(context)
        DailyReceiver.refreshIfStale(context)
    }
}

class LockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Widgets.render(context)
        DailyReceiver.refreshIfStale(context)
    }
}

// ─── تحديث رسالة اليوم يومياً حتى دون فتح التطبيق ───

class DailyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        refreshIfStale(context) { pending.finish() }
    }

    companion object {
        private val CHAPTERS = intArrayOf(
            50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8, 66, 52, 5, 48,
            12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28, 16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3,
            1, 13, 5, 5, 3, 5, 1, 1, 1, 22,
        )
        private val BOOK_NAMES = listOf(
            "التكوين", "الخروج", "اللاويين", "العدد", "التثنية", "يشوع", "القضاة", "راعوث", "صموئيل الأول",
            "صموئيل الثاني", "الملوك الأول", "الملوك الثاني", "أخبار الأيام الأول", "أخبار الأيام الثاني", "عزرا",
            "نحميا", "أستير", "أيوب", "المزامير", "الأمثال", "الجامعة", "نشيد الأنشاد", "إشعياء", "إرميا",
            "مراثي إرميا", "حزقيال", "دانيال", "هوشع", "يوئيل", "عاموس", "عوبديا", "يونان", "ميخا", "ناحوم",
            "حبقوق", "صفنيا", "حجي", "زكريا", "ملاخي", "متى", "مرقس", "لوقا", "يوحنا", "أعمال الرسل", "رومية",
            "كورنثوس الأولى", "كورنثوس الثانية", "غلاطية", "أفسس", "فيلبي", "كولوسي", "تسالونيكي الأولى",
            "تسالونيكي الثانية", "تيموثاوس الأولى", "تيموثاوس الثانية", "تيطس", "فليمون", "العبرانيين", "يعقوب",
            "بطرس الأولى", "بطرس الثانية", "يوحنا الأولى", "يوحنا الثانية", "يوحنا الثالثة", "يهوذا", "رؤيا يوحنا",
        )

        fun schedule(ctx: Context) {
            val am = ctx.getSystemService(AlarmManager::class.java)
            val pi = PendingIntent.getBroadcast(
                ctx, 10, Intent(ctx, DailyReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.setInexactRepeating(AlarmManager.RTC, System.currentTimeMillis() + AlarmManager.INTERVAL_HOUR,
                3 * AlarmManager.INTERVAL_HOUR, pi)
        }

        /** إن كانت الرسالة المحفوظة ليوم سابق نختار آية جديدة ونحدّث الويدجتس. */
        fun refreshIfStale(ctx: Context, done: () -> Unit = {}) {
            val app = ctx.applicationContext
            if (WidgetStore.prefs(app).getString("date", null) == LocalDate.now().toString()) {
                Widgets.render(app)
                done()
                return
            }
            thread {
                try {
                    var n = Random.nextInt(CHAPTERS.sum())
                    var book = 1
                    for ((i, c) in CHAPTERS.withIndex()) {
                        if (n < c) { book = i + 1; break }
                        n -= c
                    }
                    val chapter = n + 1
                    val conn = URL("https://bolls.life/get-text/SVD/$book/$chapter/").openConnection() as HttpURLConnection
                    conn.connectTimeout = 10_000
                    conn.readTimeout = 15_000
                    val body = try { conn.inputStream.bufferedReader().use { it.readText() } } finally { conn.disconnect() }
                    val arr = JSONArray(body)
                    val o = arr.getJSONObject(Random.nextInt(arr.length()))
                    val verse = o.getInt("verse")
                    val text = o.getString("text").replace(Regex("<[^>]+>"), "").replace(Regex("\\s+"), " ").trim()
                    val ref = "${BOOK_NAMES[book - 1]} ${arabicDigits(chapter)} : ${arabicDigits(verse)}"
                    val p = WidgetStore.prefs(app)
                    WidgetStore.save(app, mapOf(
                        "text" to text, "ref" to ref, "book" to book, "chapter" to chapter, "verse" to verse,
                        "lockNotification" to p.getBoolean("lock", true),
                    ))
                    WidgetStore.writeFlutterVerse(app, book, chapter, verse, text)
                } catch (_: Exception) {
                    // بدون إنترنت تبقى الرسالة السابقة
                }
                Widgets.render(app)
                done()
            }
        }
    }
}

// ─── رسالة الصباح ───

class MorningReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        DailyReceiver.refreshIfStale(context) {
            show(context.applicationContext)
            pending.finish()
        }
    }

    private fun show(ctx: Context) {
        val p = WidgetStore.prefs(ctx)
        val text = p.getString("text", null) ?: return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "رسالة الصباح", NotificationManager.IMPORTANCE_DEFAULT))
        val n = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle("صباح الخير ♡ رسالة اليوم")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText("«$text»\n${p.getString("ref", "")}"))
            .setContentIntent(Widgets.openIntent(ctx, p.getInt("book", 0), p.getInt("chapter", 1), p.getInt("verse", 1)))
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(8, n)
        } catch (_: SecurityException) {
        }
    }

    companion object {
        private const val CHANNEL = "morning_verse"
        private const val PREFS = "hamset_morning"

        fun schedule(ctx: Context, enabled: Boolean, minutes: Int) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("enabled", enabled).putInt("minutes", minutes).apply()
            val am = ctx.getSystemService(AlarmManager::class.java)
            val pi = PendingIntent.getBroadcast(
                ctx, 11, Intent(ctx, MorningReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.cancel(pi)
            if (!enabled) return
            val now = LocalDateTime.now()
            var next = now.toLocalDate().atTime(LocalTime.of(minutes / 60, minutes % 60))
            if (!next.isAfter(now)) next = next.plusDays(1)
            val at = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            am.setInexactRepeating(AlarmManager.RTC_WAKEUP, at, AlarmManager.INTERVAL_DAY, pi)
        }

        fun reschedule(ctx: Context) {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            schedule(ctx, p.getBoolean("enabled", false), p.getInt("minutes", 420))
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        DailyReceiver.schedule(context)
        MorningReceiver.reschedule(context)
        Widgets.render(context)
    }
}
