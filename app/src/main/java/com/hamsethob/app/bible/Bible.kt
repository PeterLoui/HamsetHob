package com.hamsethob.app.bible

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate
import kotlin.random.Random

data class Book(val number: Int, val name: String, val chapters: Int)

data class Verse(val number: Int, val text: String)

data class VerseRef(val book: Int, val chapter: Int, val verse: Int) {
    val bookName: String get() = BOOKS[book - 1].name
}

data class DailyVerse(val ref: VerseRef, val text: String)

/** أسفار الكتاب المقدس الـ66 بترتيب ترجمة فاندايك وعدد إصحاحات كل سفر. */
val BOOKS: List<Book> = listOf(
    "التكوين" to 50, "الخروج" to 40, "اللاويين" to 27, "العدد" to 36, "التثنية" to 34,
    "يشوع" to 24, "القضاة" to 21, "راعوث" to 4, "صموئيل الأول" to 31, "صموئيل الثاني" to 24,
    "الملوك الأول" to 22, "الملوك الثاني" to 25, "أخبار الأيام الأول" to 29, "أخبار الأيام الثاني" to 36,
    "عزرا" to 10, "نحميا" to 13, "أستير" to 10, "أيوب" to 42, "المزامير" to 150, "الأمثال" to 31,
    "الجامعة" to 12, "نشيد الأنشاد" to 8, "إشعياء" to 66, "إرميا" to 52, "مراثي إرميا" to 5,
    "حزقيال" to 48, "دانيال" to 12, "هوشع" to 14, "يوئيل" to 3, "عاموس" to 9, "عوبديا" to 1,
    "يونان" to 4, "ميخا" to 7, "ناحوم" to 3, "حبقوق" to 3, "صفنيا" to 3, "حجي" to 2,
    "زكريا" to 14, "ملاخي" to 4,
    "متى" to 28, "مرقس" to 16, "لوقا" to 24, "يوحنا" to 21, "أعمال الرسل" to 28,
    "رومية" to 16, "كورنثوس الأولى" to 16, "كورنثوس الثانية" to 13, "غلاطية" to 6,
    "أفسس" to 6, "فيلبي" to 4, "كولوسي" to 4, "تسالونيكي الأولى" to 5, "تسالونيكي الثانية" to 3,
    "تيموثاوس الأولى" to 6, "تيموثاوس الثانية" to 4, "تيطس" to 3, "فليمون" to 1, "العبرانيين" to 13,
    "يعقوب" to 5, "بطرس الأولى" to 5, "بطرس الثانية" to 3, "يوحنا الأولى" to 5, "يوحنا الثانية" to 1,
    "يوحنا الثالثة" to 1, "يهوذا" to 1, "رؤيا يوحنا" to 22,
).mapIndexed { i, (name, chapters) -> Book(i + 1, name, chapters) }

/**
 * الكتاب المقدس كاملاً (ترجمة فاندايك SVD) عبر bolls.life.
 * الإصحاحات المحمّلة تُحفظ محلياً فتعمل بعد ذلك بدون إنترنت.
 */
class BibleRepository(private val context: Context) {

    private val cache = context.getSharedPreferences("bible_cache", Context.MODE_PRIVATE)
    private val prefs = context.getSharedPreferences("daily_verse", Context.MODE_PRIVATE)

    /** يُقرأ الإصحاح من النسخة المحمّلة أولاً، ثم من الذاكرة المؤقتة، ثم من الإنترنت. */
    suspend fun chapter(book: Int, chapter: Int): List<Verse> = withContext(Dispatchers.IO) {
        OfflineBible.database(context).chapter(book, chapter).takeIf { it.isNotEmpty() }?.let { return@withContext it }

        val cacheKey = "$book:$chapter"
        val json = cache.getString(cacheKey, null)
            ?: httpGet("https://bolls.life/get-text/$TRANSLATION/$book/$chapter/")
                .also { cache.edit().putString(cacheKey, it).apply() }
        val array = JSONArray(json)
        List(array.length()) { i ->
            val o = array.getJSONObject(i)
            Verse(o.getInt("verse"), cleanVerseText(o.getString("text")))
        }
    }

    /** بحث في نص الكتاب: محلياً إن كان محمّلاً، وإلا عبر الإنترنت. */
    suspend fun search(query: String): List<SearchHit> = withContext(Dispatchers.IO) {
        if (query.isBlank()) return@withContext emptyList()
        if (OfflineBible.isInstalled(context)) return@withContext OfflineBible.database(context).search(query)

        val q = URLEncoder.encode(query.trim(), "UTF-8")
        val json = JSONObject(httpGet("https://bolls.life/v2/find/$TRANSLATION?search=$q&match_case=false&match_whole=false&limit=200&page=1"))
        val results = json.optJSONArray("results") ?: JSONArray()
        List(results.length()) { i ->
            val o = results.getJSONObject(i)
            SearchHit(VerseRef(o.getInt("book"), o.getInt("chapter"), o.getInt("verse")), cleanVerseText(o.getString("text")))
        }.filter { it.ref.book in 1..66 }
    }

    /** آية عشوائية من العهدين، ثابتة طوال اليوم ما لم يطلب المستخدم غيرها. */
    suspend fun dailyVerse(today: LocalDate, forceNew: Boolean = false): DailyVerse {
        val saved = prefs.getString(KEY_VERSE, null)?.let(::JSONObject)
        if (!forceNew && saved != null && saved.getString("date") == today.toString()) {
            val ref = VerseRef(saved.getInt("book"), saved.getInt("chapter"), saved.getInt("verse"))
            return DailyVerse(ref, saved.getString("text"))
        }

        val (book, chapter) = randomChapter()
        val verses = chapter(book, chapter)
        val verse = verses.random()
        val result = DailyVerse(VerseRef(book, chapter, verse.number), verse.text)

        prefs.edit().putString(
            KEY_VERSE,
            JSONObject()
                .put("date", today.toString())
                .put("book", book).put("chapter", chapter).put("verse", verse.number)
                .put("text", verse.text)
                .toString()
        ).apply()
        return result
    }

    /** اختيار إصحاح عشوائي من الـ1189 إصحاحاً بالتساوي. */
    private fun randomChapter(): Pair<Int, Int> {
        var n = Random.nextInt(BOOKS.sumOf { it.chapters })
        for (book in BOOKS) {
            if (n < book.chapters) return book.number to n + 1
            n -= book.chapters
        }
        return 43 to 3
    }

    private fun httpGet(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 10_000
        conn.readTimeout = 15_000
        return try {
            conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        private const val TRANSLATION = "SVD"
        private const val KEY_VERSE = "verse"
    }
}
