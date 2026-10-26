package com.hamsethob.app.calendar

import java.time.DayOfWeek
import java.time.LocalDate

/** تاريخ قبطي (سنة الشهداء). الشهر 13 هو النسيء. */
data class CopticDate(val year: Int, val month: Int, val day: Int) {
    val monthName: String get() = COPTIC_MONTHS[month - 1]

    fun toGregorian(): LocalDate = LocalDate.ofEpochDay(toJdn(year, month, day) - UNIX_EPOCH_JDN)

    companion object {
        fun daysInMonth(year: Int, month: Int): Int =
            if (month < 13) 30 else if (year % 4 == 3) 6 else 5

        // رقم اليوم اليولياني لـ 1 توت سنة 1 للشهداء (29 أغسطس 284م يولياني)
        private const val EPOCH_JDN = 1825030L
        private const val UNIX_EPOCH_JDN = 2440588L

        private fun toJdn(year: Int, month: Int, day: Int): Long =
            EPOCH_JDN - 1 + 365L * (year - 1) + year / 4 + 30L * (month - 1) + day

        fun fromGregorian(date: LocalDate): CopticDate {
            val jdn = date.toEpochDay() + UNIX_EPOCH_JDN
            val year = ((4 * (jdn - EPOCH_JDN) + 1463) / 1461).toInt()
            val month = ((jdn - toJdn(year, 1, 1)) / 30).toInt() + 1
            val day = (jdn + 1 - toJdn(year, month, 1)).toInt()
            return CopticDate(year, month, day)
        }
    }
}

val COPTIC_MONTHS = listOf(
    "توت", "بابه", "هاتور", "كيهك", "طوبه", "أمشير", "برمهات",
    "برموده", "بشنس", "بؤونه", "أبيب", "مسرى", "النسيء"
)

val GREGORIAN_MONTHS = listOf(
    "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
)

fun DayOfWeek.arabicName(): String = when (this) {
    DayOfWeek.SATURDAY -> "السبت"
    DayOfWeek.SUNDAY -> "الأحد"
    DayOfWeek.MONDAY -> "الإثنين"
    DayOfWeek.TUESDAY -> "الثلاثاء"
    DayOfWeek.WEDNESDAY -> "الأربعاء"
    DayOfWeek.THURSDAY -> "الخميس"
    DayOfWeek.FRIDAY -> "الجمعة"
}

/** تحويل الأرقام إلى أرقام عربية مشرقية (٠١٢٣...). */
fun Int.arabicDigits(): String =
    toString().map { if (it.isDigit()) '٠' + (it - '0') else it }.joinToString("")

/** عيد القيامة حسب الحساب الأبقطي (التقويم اليولياني) محوّلاً للميلادي. */
fun copticEaster(year: Int): LocalDate {
    val a = year % 4
    val b = year % 7
    val c = year % 19
    val d = (19 * c + 15) % 30
    val e = (2 * a + 4 * b - d + 34) % 7
    val month = (d + e + 114) / 31
    val day = (d + e + 114) % 31 + 1
    val julianToGregorianOffset = year / 100 - year / 400 - 2
    return LocalDate.of(year, month, day).plusDays(julianToGregorianOffset.toLong())
}
