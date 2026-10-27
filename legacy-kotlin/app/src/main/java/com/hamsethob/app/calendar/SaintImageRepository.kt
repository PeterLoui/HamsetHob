package com.hamsethob.app.calendar

import android.content.Context
import com.hamsethob.app.bible.normalizeArabic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * صورة التذكار: أولاً صفحة ويكيبيديا الإنجليزية المحددة في الجدول، ثم البحث في
 * ويكيبيديا العربية باسم القديس. لا تُقبل نتيجة إلا إذا احتوى عنوانها على الاسم،
 * وإن لم توجد صورة تعرض الواجهة رسمة الصليب. النتائج (حتى الفارغة) تُحفظ محلياً.
 */
class SaintImageRepository(context: Context) {

    private val prefs = context.getSharedPreferences("saint_images", Context.MODE_PRIVATE)

    suspend fun imageUrl(wikiTitle: String?, name: String): String? = withContext(Dispatchers.IO) {
        val key = wikiTitle ?: "search:$name"
        if (prefs.contains(key)) return@withContext prefs.getString(key, null)?.takeIf { it.isNotEmpty() }

        val url = wikiTitle?.let { runCatching { summaryImage(it) }.getOrNull() }
            ?: runCatching { searchArabic(name) }.getOrNull()
        // نحفظ النتيجة الفارغة أيضاً حتى لا نكرر البحث كل مرة
        prefs.edit().putString(key, url.orEmpty()).apply()
        url
    }

    private fun summaryImage(title: String): String? {
        val encoded = URLEncoder.encode(title, "UTF-8").replace("+", "_")
        val json = JSONObject(get("https://en.wikipedia.org/api/rest_v1/page/summary/$encoded"))
        return (json.optJSONObject("originalimage") ?: json.optJSONObject("thumbnail"))
            ?.optString("source")?.takeIf { it.isNotBlank() }
    }

    private fun searchArabic(name: String): String? {
        val keys = nameKeys(name)
        if (keys.isEmpty()) return null
        val q = URLEncoder.encode(keys.joinToString(" "), "UTF-8")
        val json = JSONObject(
            get("https://ar.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=$q&gsrlimit=6&prop=pageimages&piprop=original&format=json")
        )
        val pages = json.optJSONObject("query")?.optJSONObject("pages") ?: return null
        return pages.keys().asSequence().map { pages.getJSONObject(it) }
            .sortedBy { it.optInt("index") }
            .firstOrNull { p ->
                val title = normalizeArabic(p.optString("title"))
                p.has("original") && keys.any { title.contains(it) }
            }
            ?.getJSONObject("original")?.optString("source")
    }

    /** الكلمات المميزة لاسم القديس بعد حذف الألقاب ("نياحة البابا أغاثون" ← "اغاثون"). */
    private fun nameKeys(name: String): List<String> =
        normalizeArabic(name).split(' ', '،', '(', ')')
            .map { it.removePrefix("و") }
            .filter { it.length >= 3 && it !in TITLES }

    private fun get(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.setRequestProperty("User-Agent", "HamsetHob/1.0 (Android)")
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000
        return try {
            conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        private val TITLES = setOf(
            "نياحه", "استشهاد", "تذكار", "عيد", "القديس", "القديسه", "القديسين", "البابا", "الانبا", "انبا",
            "مار", "الشهيد", "الشهيده", "رئيس", "الملائكه", "الملاك", "السيده", "ابي", "ابو", "البطريرك",
            "الكبير", "الرسول", "الرسولين", "الانجيلي", "بطاركه", "الكرازه", "المرقسيه", "اسقف", "الاسقف",
            "التذكار", "الشهري", "سنكسار", "اليوم", "دخول", "بدايه", "صوم", "المجيد",
        )
    }
}
