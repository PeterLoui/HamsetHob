package com.hamsethob.app.data

import android.content.Context
import android.graphics.Typeface
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL

/**
 * خط أميري (رخصة OFL) للآيات. يُحمَّل مرة واحدة من مستودع Google Fonts
 * ويُحفظ داخل التطبيق، ويُستخدم خط النظام إلى أن يكتمل التحميل.
 */
object ScriptureFont {
    private const val BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/"

    private fun regular(context: Context) = File(context.filesDir, "fonts/Amiri-Regular.ttf")
    private fun bold(context: Context) = File(context.filesDir, "fonts/Amiri-Bold.ttf")

    fun isReady(context: Context) = regular(context).exists() && bold(context).exists()

    suspend fun ensure(context: Context): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            listOf(regular(context) to "Amiri-Regular.ttf", bold(context) to "Amiri-Bold.ttf").forEach { (file, name) ->
                if (!file.exists()) {
                    file.parentFile?.mkdirs()
                    val tmp = File(file.path + ".part")
                    URL(BASE + name).openStream().use { input -> tmp.outputStream().use { input.copyTo(it) } }
                    tmp.renameTo(file)
                }
            }
            true
        }.getOrDefault(false)
    }

    fun family(context: Context): FontFamily? =
        if (isReady(context)) FontFamily(
            Font(regular(context), FontWeight.Normal),
            Font(bold(context), FontWeight.Bold),
        ) else null

    /** للرسم على Canvas (صورة المشاركة). */
    fun typeface(context: Context, isBold: Boolean = false): Typeface =
        if (isReady(context)) Typeface.createFromFile(if (isBold) bold(context) else regular(context))
        else Typeface.create(Typeface.DEFAULT, if (isBold) Typeface.BOLD else Typeface.NORMAL)
}
