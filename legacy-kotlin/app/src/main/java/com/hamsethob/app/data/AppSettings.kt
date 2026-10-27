package com.hamsethob.app.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

enum class ThemeMode(val label: String) { SYSTEM("تلقائي"), LIGHT("فاتح"), DARK("داكن") }

/** إعدادات التطبيق؛ كل خاصية حالة Compose تُحفظ فور تغييرها. */
class AppSettings private constructor(context: Context) {

    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    var themeMode by persisted(ThemeMode.valueOf(prefs.getString("theme", "SYSTEM")!!)) {
        prefs.edit().putString("theme", it.name).apply()
    }
    var seasonalColors by persisted(prefs.getBoolean("seasonal", true)) {
        prefs.edit().putBoolean("seasonal", it).apply()
    }
    var scriptureFont by persisted(prefs.getBoolean("amiri", true)) {
        prefs.edit().putBoolean("amiri", it).apply()
    }
    var lockNotification by persisted(prefs.getBoolean("lock_notif", true)) {
        prefs.edit().putBoolean("lock_notif", it).apply()
    }
    var morningEnabled by persisted(prefs.getBoolean("morning", false)) {
        prefs.edit().putBoolean("morning", it).apply()
    }
    var morningMinutes by persisted(prefs.getInt("morning_at", 7 * 60)) {
        prefs.edit().putInt("morning_at", it).apply()
    }

    private fun <T> persisted(initial: T, save: (T) -> Unit) = object {
        private var state by mutableStateOf(initial)
        operator fun getValue(thisRef: Any?, property: Any?): T = state
        operator fun setValue(thisRef: Any?, property: Any?, value: T) {
            state = value
            save(value)
        }
    }

    companion object {
        @Volatile private var instance: AppSettings? = null
        fun get(context: Context): AppSettings =
            instance ?: synchronized(this) {
                instance ?: AppSettings(context.applicationContext).also { instance = it }
            }
    }
}
