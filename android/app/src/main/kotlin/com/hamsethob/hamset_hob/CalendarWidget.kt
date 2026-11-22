package com.hamsethob.hamset_hob

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate

/**
 * ويدجت التقويم القبطي: التاريخ وتذكار اليوم وصورته.
 *
 * التاريخ بيتحسب هنا (زي باقي الويدجتس) فبيتغيّر عند منتصف الليل من غير ما التطبيق يتفتح.
 * التذكارات بتتحسب في التطبيق (جدول السنكسار فيه)، وبيبعت منها ١٤ يوم قدّام، فالويدجت يفضل صح كم يوم
 * من غير فتح التطبيق. وأول ما التطبيق يتفتح بيبعت تذكار النهارده الكامل (اسم قديس السنكسار) وصورته.
 */
object CalendarWidget {
    private const val PREFS = "calendar_widget"

    private val WEEKDAYS = listOf("الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد")
    private val MONTHS = listOf(
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    )

    /** days: [{date: "2026-11-17", title, detail, kind}]، وimagePath/imageDate لصورة تذكار يوم معيّن. */
    fun save(ctx: Context, a: Map<*, *>) {
        val arr = JSONArray()
        for (item in (a["days"] as? List<*>) ?: emptyList<Any>()) {
            val m = item as? Map<*, *> ?: continue
            arr.put(JSONObject().apply {
                put("date", m["date"] as? String ?: "")
                put("title", m["title"] as? String ?: "")
                put("detail", m["detail"] as? String ?: "")
                put("kind", m["kind"] as? String ?: "")
            })
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("days", arr.toString())
            .putString("image_path", a["imagePath"] as? String)
            .putString("image_date", a["imageDate"] as? String)
            .apply()
        render(ctx)
    }

    fun render(ctx: Context) {
        val manager = AppWidgetManager.getInstance(ctx)
        val component = ComponentName(ctx, CalendarWidgetProvider::class.java)
        if (manager.getAppWidgetIds(component).isEmpty()) return

        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = LocalDate.now()
        val iso = today.toString()
        val coptic = CopticDay.of(today)

        var title = ""
        var detail = ""
        var kind = ""
        val arr = try { JSONArray(p.getString("days", "[]")) } catch (_: Exception) { JSONArray() }
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("date") == iso) {
                title = o.optString("title")
                detail = o.optString("detail")
                kind = o.optString("kind")
                break
            }
        }
        if (title.isEmpty()) {
            // التطبيق ماتفتحش من فترة والأيام المحفوظة خلصت
            title = "سنكسار ${arabicDigits(coptic.day)} ${coptic.monthName}"
            detail = "افتح التطبيق لتذكار اليوم"
        }

        val image = if (p.getString("image_date", null) == iso) decode(p.getString("image_path", null)) else null

        val views = RemoteViews(ctx.packageName, R.layout.widget_calendar).apply {
            setImageViewResource(R.id.glass, R.drawable.widget_glass_clear)
            setTextViewText(R.id.cal_day, arabicDigits(coptic.day))
            setTextViewText(R.id.cal_month, "${coptic.monthName} ${arabicDigits(coptic.year)}")
            setTextViewText(R.id.cal_greg, "${WEEKDAYS[today.dayOfWeek.value - 1]} ${arabicDigits(today.dayOfMonth)} ${MONTHS[today.monthValue - 1]}")
            setTextViewText(R.id.cal_kind, kind)
            setViewVisibility(R.id.cal_kind, if (kind.isEmpty()) View.GONE else View.VISIBLE)
            setTextViewText(R.id.cal_title, title)
            setTextViewText(R.id.cal_detail, detail)
            setViewVisibility(R.id.cal_detail, if (detail.isEmpty()) View.GONE else View.VISIBLE)
            if (image != null) {
                setImageViewBitmap(R.id.cal_image, image)
                setViewVisibility(R.id.cal_image, View.VISIBLE)
            } else {
                setViewVisibility(R.id.cal_image, View.GONE)
            }
            setContentDescription(R.id.root, "${coptic.label}، $title")
            setOnClickPendingIntent(R.id.root, Widgets.openIntent(ctx, 0, 1, 1))
        }
        manager.updateAppWidget(component, views)
    }

    /** الصورة مصغّرة (حوالي ٢٥٦ بكسل): RemoteViews بيرفض الصور الكبيرة. */
    private fun decode(path: String?): Bitmap? {
        if (path == null || !File(path).exists()) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= 256 && bounds.outHeight / (sample * 2) >= 256) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        } catch (_: Throwable) {
            null
        }
    }
}

class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        CalendarWidget.render(context)
        DailyReceiver.schedule(context)
    }
}
