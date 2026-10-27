package com.hamsethob.app.share

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.data.ScriptureFont
import com.hamsethob.app.ui.AppColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import androidx.compose.ui.graphics.toArgb

fun VerseRef.label() = "$bookName ${chapter.arabicDigits()} : ${verse.arabicDigits()}"

object VerseShare {

    fun copy(context: Context, ref: VerseRef, text: String) {
        val cm = context.getSystemService(ClipboardManager::class.java)
        cm.setPrimaryClip(ClipData.newPlainText("آية", "«$text»\n${ref.label()}"))
    }

    /** يرسم الآية بتصميم الزجاج السائل في صورة 1080×1350 ثم يفتح قائمة المشاركة. */
    suspend fun shareImage(context: Context, ref: VerseRef, text: String, colors: AppColors) {
        val file = withContext(Dispatchers.Default) {
            val bitmap = render(context, ref, text, colors)
            val dir = File(context.cacheDir, "share").apply { mkdirs() }
            File(dir, "verse.png").also { f -> f.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) } }
        }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "«$text»\n${ref.label()}\n— همسة حب")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(send, "مشاركة الآية").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun render(context: Context, ref: VerseRef, text: String, colors: AppColors): Bitmap {
        val w = 1080; val h = 1350
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // الخلفية والفقاعات اللونية
        paint.shader = LinearGradient(0f, 0f, 0f, h.toFloat(), colors.wallpaper.map { it.toArgb() }.toIntArray(), null, Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
        listOf(Triple(0.85f, 0.12f, 0.6f), Triple(0.1f, 0.35f, 0.65f), Triple(0.7f, 0.7f, 0.55f), Triple(0.2f, 0.95f, 0.7f))
            .forEachIndexed { i, (x, y, r) ->
                paint.shader = RadialGradient(w * x, h * y, w * r, colors.blobs[i].toArgb(), 0, Shader.TileMode.CLAMP)
                c.drawCircle(w * x, h * y, w * r, paint)
            }

        // لوح الزجاج
        val card = RectF(80f, 240f, w - 80f, h - 240f)
        val radius = 72f
        paint.shader = LinearGradient(0f, card.top, 0f, card.bottom, colors.glassFilm.map { it.toArgb() }.toIntArray(), null, Shader.TileMode.CLAMP)
        c.drawRoundRect(card, radius, radius, paint)
        paint.shader = RadialGradient(card.left + card.width() * 0.15f, card.top, card.width() * 0.8f, 0x55FFFFFF, 0, Shader.TileMode.CLAMP)
        c.drawRoundRect(card, radius, radius, paint)
        paint.shader = LinearGradient(card.left, card.top, card.right, card.bottom, colors.glassRim.map { it.toArgb() }.toIntArray(), null, Shader.TileMode.CLAMP)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3f
        c.drawRoundRect(card, radius, radius, paint)
        paint.style = Paint.Style.FILL
        paint.shader = null

        // النص
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colors.text.toArgb()
            typeface = ScriptureFont.typeface(context)
        }
        val maxWidth = (card.width() - 120).toInt()
        var size = 64f
        lateinit var layout: StaticLayout
        do {
            textPaint.textSize = size
            layout = StaticLayout.Builder.obtain("«$text»", 0, text.length + 2, textPaint, maxWidth)
                .setAlignment(Layout.Alignment.ALIGN_CENTER)
                .setLineSpacing(0f, 1.35f)
                .build()
            size -= 4f
        } while (layout.height > card.height() - 260 && size > 30f)

        c.save()
        c.translate(card.left + 60, card.top + (card.height() - layout.height) / 2f - 40)
        layout.draw(c)
        c.restore()

        val refPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colors.accent.toArgb()
            textSize = 44f
            typeface = ScriptureFont.typeface(context, isBold = true)
            textAlign = Paint.Align.CENTER
        }
        c.drawText(ref.label(), w / 2f, card.bottom - 90, refPaint)

        val brand = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colors.textSoft.toArgb()
            textSize = 40f
            textAlign = Paint.Align.CENTER
        }
        c.drawText("♡  همسة حب", w / 2f, h - 120f, brand)
        return bmp
    }
}
