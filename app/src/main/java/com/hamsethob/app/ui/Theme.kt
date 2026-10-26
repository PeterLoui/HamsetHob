package com.hamsethob.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.hamsethob.app.calendar.Season

/** ألوان الواجهة حسب الوضع (فاتح/داكن) والموسم الكنسي. */
data class AppColors(
    val isDark: Boolean,
    val wallpaper: List<Color>,
    val blobs: List<Color>,
    val text: Color,
    val textSoft: Color,
    val textFaint: Color,
    val accent: Color,
    val fastColor: Color,
    val saintColor: Color,
    val glassTint: Color,
    val glassFilm: List<Color>,
    val glassRim: List<Color>,
    val imageShade: List<Color>,
)

fun appColors(dark: Boolean, season: Season): AppColors {
    val (wall, blobs) = when (season to dark) {
        Season.ORDINARY to true -> listOf(Color(0xFF140B26), Color(0xFF2A1446), Color(0xFF4A1B4F)) to
            listOf(Color(0xAAE0457B), Color(0x995B5BE8), Color(0x88F3A15C), Color(0x777A3FD1))
        Season.FAST to true -> listOf(Color(0xFF0C0A24), Color(0xFF1C1748), Color(0xFF2E1B57)) to
            listOf(Color(0xAA6B4BD8), Color(0x994A6FE0), Color(0x779A62C9), Color(0x775B3FA8))
        Season.FEAST to true -> listOf(Color(0xFF1C1208), Color(0xFF3A230F), Color(0xFF4F2A1A)) to
            listOf(Color(0xAAF3B04A), Color(0x99E0705B), Color(0x88FFD98A), Color(0x77C0603F))
        Season.ORDINARY to false -> listOf(Color(0xFFFFF1F5), Color(0xFFF6E6FF), Color(0xFFFFE9DD)) to
            listOf(Color(0x99FF8DB3), Color(0x889DA2FF), Color(0x88FFC48A), Color(0x77C59BFF))
        Season.FAST to false -> listOf(Color(0xFFF1EEFF), Color(0xFFE6E8FF), Color(0xFFEFE4FF)) to
            listOf(Color(0x99A88BFF), Color(0x8890A8FF), Color(0x77C7A2F0), Color(0x77A890E8))
        else -> listOf(Color(0xFFFFF8EA), Color(0xFFFFEFD6), Color(0xFFFFE6DA)) to
            listOf(Color(0x99FFC85C), Color(0x88FF9E85), Color(0x88FFE39E), Color(0x77E89A70))
    }
    return if (dark) AppColors(
        isDark = true,
        wallpaper = wall, blobs = blobs,
        text = Color.White, textSoft = Color(0xCCFFFFFF), textFaint = Color(0x99FFFFFF),
        accent = Color(0xFFF3C77A), fastColor = Color(0xFFB9A7FF), saintColor = Color(0xFFFFC2DA),
        glassTint = Color(0x1FFFFFFF),
        glassFilm = listOf(Color(0x47FFFFFF), Color(0x14FFFFFF), Color(0x0AFFFFFF), Color(0x26FFFFFF)),
        glassRim = listOf(Color(0xCCFFFFFF), Color(0x22FFFFFF), Color(0x11FFFFFF), Color(0x88FFFFFF)),
        imageShade = listOf(Color(0x33140B26), Color(0x11140B26), Color(0x77140B26)),
    ) else AppColors(
        isDark = false,
        wallpaper = wall, blobs = blobs,
        text = Color(0xFF2A1638), textSoft = Color(0xCC2A1638), textFaint = Color(0x992A1638),
        accent = Color(0xFFA8681A), fastColor = Color(0xFF5B45C9), saintColor = Color(0xFFB0306A),
        glassTint = Color(0x59FFFFFF),
        glassFilm = listOf(Color(0x99FFFFFF), Color(0x40FFFFFF), Color(0x26FFFFFF), Color(0x66FFFFFF)),
        glassRim = listOf(Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x33FFFFFF), Color(0xCCFFFFFF)),
        imageShade = listOf(Color(0x66FFFFFF), Color(0x33FFFFFF), Color(0x99FFFFFF)),
    )
}

val LocalAppColors = staticCompositionLocalOf { appColors(true, Season.ORDINARY) }

/** خط الآيات (أميري) إن كان محمّلاً، وإلا خط النظام. */
val LocalScriptureFont = staticCompositionLocalOf<FontFamily> { FontFamily.Default }

/** المسافة السفلية للتبويبات حتى لا يغطي الشريط السفلي (ومشغّل الإذاعة) المحتوى. */
val LocalBottomInset = staticCompositionLocalOf { 110.dp }

/** وصول مختصر لألوان الثيم الحالي. */
object Palette {
    val Text: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.text
    val TextSoft: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.textSoft
    val TextFaint: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.textFaint
    val Gold: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.accent
    val Fast: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.fastColor
    val Saint: Color @Composable @ReadOnlyComposable get() = LocalAppColors.current.saintColor
    /** خلفية خفيفة للأزرار والشرائح فوق الزجاج. */
    val Chip: Color @Composable @ReadOnlyComposable
        get() = if (LocalAppColors.current.isDark) Color(0x26FFFFFF) else Color(0x1A2A1638)
}
