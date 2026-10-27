package com.hamsethob.app.radio

import android.content.Context
import androidx.core.text.HtmlCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.random.Random

data class Sermon(
    val id: Int,
    val title: String,
    val summary: String,
    val link: String,
    val categoryId: Int,
)

data class SermonCategory(val id: Int, val name: String)

data class SermonPage(val items: List<Sermon>, val totalPages: Int)

/** أقسام مكتبة العظات الصوتية في موقع قداسة البابا شنوده الثالث. */
val SERMON_CATEGORIES = listOf(
    SermonCategory(0, "الكل"),
    SermonCategory(62, "اللاهوت الروحي"),
    SermonCategory(112, "الكتاب المقدس"),
    SermonCategory(148, "أعياد ومناسبات"),
    SermonCategory(186, "سير القديسين"),
    SermonCategory(166, "اللاهوت الرعوي"),
    SermonCategory(140, "اللاهوت المقارن"),
    SermonCategory(63, "اللاهوت الأدبي"),
    SermonCategory(123, "اللاهوت العقيدي"),
    SermonCategory(82, "تاريخ الكنيسة"),
    SermonCategory(192, "قصائد وأشعار وترانيم"),
    SermonCategory(160, "قانون الكنيسة"),
    SermonCategory(153, "اللاهوت الطقسي"),
    SermonCategory(185, "الإسخاتولوجي"),
    SermonCategory(194, "الباترولوجي"),
    SermonCategory(173, "اللاهوت النظري"),
    SermonCategory(177, "اللاهوت النسكي"),
    SermonCategory(24310, "اللقاءات والندوات"),
    SermonCategory(193, "متفرقات"),
)

fun categoryName(id: Int) = SERMON_CATEGORIES.firstOrNull { it.id == id }?.name ?: "عظات"

/**
 * مكتبة العظات من popeshenouda.org.eg عبر واجهة WordPress:
 * المقالات الموسومة «قسم الصوتيات» (وسم 212)، ورابط الملف الصوتي يُستخرج من صفحة العظة.
 */
class SermonRepository(context: Context) {

    private val audioCache = context.getSharedPreferences("sermon_audio", Context.MODE_PRIVATE)

    suspend fun page(category: Int, query: String, page: Int): SermonPage = withContext(Dispatchers.IO) {
        val url = buildString {
            append("$API/posts?tags=$AUDIO_TAG&per_page=20&page=$page&_fields=id,title,excerpt,link,categories")
            if (category != 0) append("&categories=$category")
            if (query.isNotBlank()) append("&search=").append(URLEncoder.encode(query.trim(), "UTF-8"))
        }
        val conn = open(url)
        try {
            // الصفحة بعد الأخيرة تُرجع خطأ 400 من WordPress
            if (conn.responseCode == 400) return@withContext SermonPage(emptyList(), page - 1)
            val total = conn.getHeaderField("X-WP-TotalPages")?.toIntOrNull() ?: 1
            val array = JSONArray(conn.inputStream.bufferedReader().use { it.readText() })
            SermonPage(List(array.length()) { i -> parse(array.getJSONObject(i)) }, total)
        } finally {
            conn.disconnect()
        }
    }

    /** عظة عشوائية من كل المكتبة (للبث المتواصل). */
    suspend fun random(category: Int = 0): Sermon = withContext(Dispatchers.IO) {
        val total = totalCount(category)
        val index = Random.nextInt(1, total + 1)
        val url = "$API/posts?tags=$AUDIO_TAG&per_page=1&page=$index&_fields=id,title,excerpt,link,categories" +
            if (category != 0) "&categories=$category" else ""
        val conn = open(url)
        try {
            parse(JSONArray(conn.inputStream.bufferedReader().use { it.readText() }).getJSONObject(0))
        } finally {
            conn.disconnect()
        }
    }

    /** رابط ملف MP3 من صفحة العظة (يُحفظ بعد أول مرة). */
    suspend fun audioUrl(sermon: Sermon): String = withContext(Dispatchers.IO) {
        audioCache.getString(sermon.id.toString(), null)?.let { return@withContext it }
        val conn = open(sermon.link)
        val html = try {
            conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
        val urls = Regex("""https?://[^"'\s<>]+?\.mp3""", RegexOption.IGNORE_CASE).findAll(html).map { it.value }.toList()
        val url = urls.firstOrNull { it.contains("cdn.popeshenouda.org.eg/Audios") && !it.contains("wasabisys") }
            ?: urls.firstOrNull()
            ?: error("لم يتم العثور على ملف صوتي لهذه العظة")
        audioCache.edit().putString(sermon.id.toString(), url).apply()
        url
    }

    private val counts = mutableMapOf<Int, Int>()

    private fun totalCount(category: Int): Int = counts.getOrPut(category) {
        val url = "$API/posts?tags=$AUDIO_TAG&per_page=1&_fields=id" + if (category != 0) "&categories=$category" else ""
        val conn = open(url)
        try {
            conn.getHeaderField("X-WP-Total")?.toIntOrNull() ?: 1
        } finally {
            conn.disconnect()
        }
    }

    private fun parse(o: org.json.JSONObject) = Sermon(
        id = o.getInt("id"),
        title = decode(o.getJSONObject("title").getString("rendered")),
        summary = decode(o.optJSONObject("excerpt")?.optString("rendered").orEmpty())
            .removePrefix("الفكرة الرئيسية").trim(),
        link = o.getString("link"),
        categoryId = o.optJSONArray("categories")?.optInt(0) ?: 0,
    )

    private fun decode(html: String) = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY).toString().trim()

    private fun open(url: String) = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 20_000
        setRequestProperty("User-Agent", "HamsetHob/1.0 (Android)")
    }

    companion object {
        private const val API = "https://popeshenouda.org.eg/wp-json/wp/v2"
        private const val AUDIO_TAG = 212
        const val ARTWORK = "https://popeshenouda.org.eg/wp-content/uploads/2025/10/popeshenoda-podcast-1170x935.webp"
    }
}
