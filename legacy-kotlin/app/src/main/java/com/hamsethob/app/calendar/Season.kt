package com.hamsethob.app.calendar

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** الموسم الكنسي الذي تُلوَّن به الواجهة. */
enum class Season { ORDINARY, FAST, FEAST }

fun seasonOf(date: LocalDate): Season {
    val offset = ChronoUnit.DAYS.between(copticEaster(date.year), date)
    val c = CopticDate.fromGregorian(date)
    val md = c.month * 100 + c.day

    if (Synaxarium.feastOrFast(date)?.kind == Kind.FEAST) return Season.FEAST
    // الخماسين المقدسة: من القيامة حتى العنصرة
    if (offset in 0..49) return Season.FEAST

    val fasting =
        offset in -69L..-67L ||                 // صوم يونان
        offset in -55L..-1L ||                  // الصوم الكبير وأسبوع الآلام
        (offset >= 50 && md in 901..1104) || // صوم الرسل حتى ٤ أبيب
        md in 316..330 || md in 401..428 ||     // صوم الميلاد ١٦ هاتور – ٢٨ كيهك
        md in 1201..1215                        // صوم العذراء ١–١٥ مسرى
    return if (fasting) Season.FAST else Season.ORDINARY
}
