package com.hamsethob.app.bible

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.JsonReader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.FilterInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/** إزالة التشكيل وتوحيد الألف والياء ليعمل البحث بدون حركات. */
fun normalizeArabic(text: String): String = buildString(text.length) {
    for (ch in text) {
        when {
            ch in 'ً'..'ٟ' || ch == 'ٰ' || ch == 'ـ' || ch in 'ۖ'..'ۭ' -> Unit
            ch == 'أ' || ch == 'إ' || ch == 'آ' || ch == 'ٱ' -> append('ا')
            ch == 'ى' -> append('ي')
            ch == 'ة' -> append('ه')
            else -> append(ch)
        }
    }
}

class BibleDatabase(context: Context) : SQLiteOpenHelper(context, "bible.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE verses (book INTEGER, chapter INTEGER, verse INTEGER, text TEXT, plain TEXT, " +
                "PRIMARY KEY (book, chapter, verse))"
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun verseCount(): Int =
        readableDatabase.rawQuery("SELECT COUNT(*) FROM verses", null).use { if (it.moveToFirst()) it.getInt(0) else 0 }

    fun chapter(book: Int, chapter: Int): List<Verse> =
        readableDatabase.rawQuery(
            "SELECT verse, text FROM verses WHERE book = ? AND chapter = ? ORDER BY verse",
            arrayOf(book.toString(), chapter.toString()),
        ).use { c -> buildList { while (c.moveToNext()) add(Verse(c.getInt(0), c.getString(1))) } }

    fun search(query: String, limit: Int = 300): List<SearchHit> {
        val words = normalizeArabic(query).split(' ').filter { it.isNotBlank() }
        if (words.isEmpty()) return emptyList()
        val where = words.joinToString(" AND ") { "plain LIKE ?" }
        return readableDatabase.rawQuery(
            "SELECT book, chapter, verse, text FROM verses WHERE $where ORDER BY book, chapter, verse LIMIT $limit",
            words.map { "%$it%" }.toTypedArray(),
        ).use { c ->
            buildList { while (c.moveToNext()) add(SearchHit(VerseRef(c.getInt(0), c.getInt(1), c.getInt(2)), c.getString(3))) }
        }
    }

    fun clear() = writableDatabase.execSQL("DELETE FROM verses")
}

data class SearchHit(val ref: VerseRef, val text: String)

sealed interface DownloadState {
    data object Idle : DownloadState
    data class Running(val progress: Float) : DownloadState
    data object Done : DownloadState
    data class Failed(val message: String) : DownloadState
}

/** تحميل ترجمة فاندايك كاملة (حوالي ٢٫٤ ميجا) وتخزينها في قاعدة بيانات محلية. */
object OfflineBible {
    private const val URL_ZIP = "https://bolls.life/static/translations/SVD.zip"
    private const val FULL_COUNT = 31_000
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _state = MutableStateFlow<DownloadState>(DownloadState.Idle)
    val state: StateFlow<DownloadState> = _state

    @Volatile private var db: BibleDatabase? = null

    fun database(context: Context): BibleDatabase =
        db ?: synchronized(this) { db ?: BibleDatabase(context.applicationContext).also { db = it } }

    fun isInstalled(context: Context) = database(context).verseCount() >= FULL_COUNT

    fun refresh(context: Context) {
        if (_state.value !is DownloadState.Running) {
            _state.value = if (isInstalled(context)) DownloadState.Done else DownloadState.Idle
        }
    }

    fun start(context: Context) {
        if (_state.value is DownloadState.Running) return
        _state.value = DownloadState.Running(0f)
        scope.launch {
            val database = database(context)
            runCatching {
                val conn = URL(URL_ZIP).openConnection() as HttpURLConnection
                conn.connectTimeout = 15_000
                conn.readTimeout = 30_000
                val total = conn.contentLengthLong.takeIf { it > 0 } ?: 2_400_000L
                try {
                    val counting = CountingStream(conn.inputStream) { read ->
                        _state.value = DownloadState.Running((read.toFloat() / total).coerceIn(0f, 0.99f))
                    }
                    ZipInputStream(counting.buffered()).use { zip ->
                        var entry = zip.nextEntry
                        while (entry != null && entry.isDirectory) entry = zip.nextEntry
                        requireNotNull(entry) { "ملف الكتاب غير موجود داخل الأرشيف" }
                        importJson(database.writableDatabase, zip)
                    }
                } finally {
                    conn.disconnect()
                }
                check(isInstalled(context)) { "لم يكتمل التحميل" }
            }.onSuccess {
                _state.value = DownloadState.Done
            }.onFailure {
                _state.value = DownloadState.Failed(it.message ?: "تعذّر التحميل")
            }
        }
    }

    fun delete(context: Context) {
        database(context).clear()
        _state.value = DownloadState.Idle
    }

    /** الملف عبارة عن مصفوفة آيات: {book, chapter, verse, text, ...}. */
    private fun importJson(db: SQLiteDatabase, input: InputStream) {
        val reader = JsonReader(input.reader(Charsets.UTF_8))
        db.beginTransaction()
        try {
            db.delete("verses", null, null)
            reader.beginArray()
            val values = ContentValues()
            while (reader.hasNext()) {
                var book = 0; var chapter = 0; var verse = 0; var text = ""
                reader.beginObject()
                while (reader.hasNext()) {
                    when (reader.nextName()) {
                        "book" -> book = reader.nextInt()
                        "chapter" -> chapter = reader.nextInt()
                        "verse" -> verse = reader.nextInt()
                        "text" -> text = reader.nextString()
                        else -> reader.skipValue()
                    }
                }
                reader.endObject()
                if (book in 1..66) {
                    val clean = cleanVerseText(text)
                    values.clear()
                    values.put("book", book)
                    values.put("chapter", chapter)
                    values.put("verse", verse)
                    values.put("text", clean)
                    values.put("plain", normalizeArabic(clean))
                    db.insertWithOnConflict("verses", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                }
            }
            reader.endArray()
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private class CountingStream(input: InputStream, val onRead: (Long) -> Unit) : FilterInputStream(input) {
        private var count = 0L
        private var lastReport = 0L
        override fun read(): Int = super.read().also { if (it >= 0) bump(1) }
        override fun read(b: ByteArray, off: Int, len: Int): Int = super.read(b, off, len).also { if (it > 0) bump(it.toLong()) }
        private fun bump(n: Long) {
            count += n
            if (count - lastReport > 32_768) { lastReport = count; onRead(count) }
        }
    }
}

fun cleanVerseText(raw: String): String =
    raw.replace(Regex("<[^>]+>"), "").replace(Regex("\\s+"), " ").trim()
