package com.hamsethob.app.data

import android.content.Context
import androidx.core.text.HtmlCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.format.DateTimeFormatter

data class Passage(val book: String, val bookId: Int, val chapter: Int, val ref: String, val text: String)

data class Reading(
    val title: String?,
    val introduction: String?,
    val conclusion: String?,
    val passages: List<Passage>,
    val story: String?,
)

data class ReadingGroup(val title: String, val introduction: String?, val readings: List<Reading>)

data class ReadingSection(val title: String, val groups: List<ReadingGroup>)

data class SaintStory(val title: String, val text: String)

data class DayReadings(val sections: List<ReadingSection>) {
    /** سير السنكسار الكاملة لهذا اليوم. */
    val synaxarium: List<SaintStory>
        get() = sections.flatMap { it.groups }
            .filter { it.title.contains("السنكسار") }
            .flatMap { it.readings }
            .mapNotNull { r -> r.story?.let { SaintStory(r.title ?: "سنكسار اليوم", it) } }
}

/**
 * القطمارس اليومي والسنكسار الكامل من api.katameros.app (ترجمة فاندايك).
 * كل يوم يُحفظ بعد أول تحميل.
 */
class KatamerosRepository(context: Context) {

    private val dir = File(context.cacheDir, "katameros").apply { mkdirs() }
    private val fmt = DateTimeFormatter.ofPattern("dd-MM-yyyy")

    suspend fun day(date: LocalDate): DayReadings = withContext(Dispatchers.IO) {
        val file = File(dir, "${date}.json")
        val json = if (file.exists()) file.readText() else {
            val conn = URL("https://api.katameros.app/readings/gregorian/${date.format(fmt)}?languageId=3")
                .openConnection() as HttpURLConnection
            conn.connectTimeout = 10_000
            conn.readTimeout = 20_000
            val body = try {
                conn.inputStream.bufferedReader().use { it.readText() }
            } finally {
                conn.disconnect()
            }
            file.writeText(body)
            body
        }
        parse(JSONObject(json))
    }

    private fun parse(root: JSONObject) = DayReadings(
        root.optJSONArray("sections").objects().map { s ->
            ReadingSection(
                s.optString("title"),
                s.optJSONArray("subSections").objects().map { ss ->
                    ReadingGroup(
                        ss.optString("title"),
                        ss.optStringOrNull("introduction"),
                        ss.optJSONArray("readings").objects().map { r ->
                            Reading(
                                title = r.optStringOrNull("title"),
                                introduction = r.optStringOrNull("introduction"),
                                conclusion = r.optStringOrNull("conclusion"),
                                passages = r.optJSONArray("passages").objects().map { p ->
                                    Passage(
                                        book = p.optString("bookTranslation"),
                                        bookId = p.optInt("bookId"),
                                        chapter = p.optInt("chapter"),
                                        ref = p.optString("ref"),
                                        text = p.optJSONArray("verses").objects()
                                            .joinToString(" ") { v -> "(${v.optInt("number")}) ${v.optString("text").trim()}" },
                                    )
                                },
                                story = r.optStringOrNull("html")?.let {
                                    HtmlCompat.fromHtml(it, HtmlCompat.FROM_HTML_MODE_LEGACY).toString().trim()
                                },
                            )
                        },
                    )
                },
            )
        }
    )

    private fun JSONArray?.objects(): List<JSONObject> =
        if (this == null) emptyList() else List(length()) { getJSONObject(it) }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }
}
