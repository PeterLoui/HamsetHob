package com.hamsethob.app.bible

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import org.json.JSONArray
import org.json.JSONObject

data class Favorite(val ref: VerseRef, val text: String)

/** الآيات المحفوظة، الأحدث أولاً. */
class Favorites private constructor(context: Context) {

    private val prefs = context.getSharedPreferences("favorites", Context.MODE_PRIVATE)
    val items = mutableStateListOf<Favorite>().apply { addAll(load()) }

    fun contains(ref: VerseRef) = items.any { it.ref == ref }

    fun toggle(ref: VerseRef, text: String) {
        if (contains(ref)) items.removeAll { it.ref == ref } else items.add(0, Favorite(ref, text))
        save()
    }

    private fun load(): List<Favorite> {
        val array = JSONArray(prefs.getString("items", "[]"))
        return List(array.length()) { i ->
            val o = array.getJSONObject(i)
            Favorite(VerseRef(o.getInt("b"), o.getInt("c"), o.getInt("v")), o.getString("t"))
        }
    }

    private fun save() {
        val array = JSONArray()
        items.forEach {
            array.put(JSONObject().put("b", it.ref.book).put("c", it.ref.chapter).put("v", it.ref.verse).put("t", it.text))
        }
        prefs.edit().putString("items", array.toString()).apply()
    }

    companion object {
        @Volatile private var instance: Favorites? = null
        fun get(context: Context): Favorites =
            instance ?: synchronized(this) {
                instance ?: Favorites(context.applicationContext).also { instance = it }
            }
    }
}
