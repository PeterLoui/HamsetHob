package com.hamsethob.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.calendar.Commemoration
import com.hamsethob.app.calendar.CopticDate
import com.hamsethob.app.calendar.GREGORIAN_MONTHS
import com.hamsethob.app.calendar.Kind
import com.hamsethob.app.calendar.Synaxarium
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.calendar.arabicName
import java.time.DayOfWeek
import java.time.LocalDate

private val WEEK = listOf(
    DayOfWeek.SATURDAY, DayOfWeek.SUNDAY, DayOfWeek.MONDAY, DayOfWeek.TUESDAY,
    DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY,
)

@Composable
private fun kindColor(kind: Kind) = when (kind) {
    Kind.FEAST -> Palette.Gold
    Kind.FAST -> Palette.Fast
    Kind.SAINT -> Palette.Saint
}

/** النتيجة: شهر ميلادي أو قبطي مع الأعياد وبدايات الأصوام. */
@Composable
fun CalendarScreen(today: LocalDate) {
    var coptic by remember { mutableStateOf(false) }
    // أي يوم داخل الشهر المعروض
    var anchor by remember { mutableStateOf(today) }

    val days: List<LocalDate> = remember(anchor, coptic) {
        if (coptic) {
            val c = CopticDate.fromGregorian(anchor)
            val first = CopticDate(c.year, c.month, 1).toGregorian()
            List(CopticDate.daysInMonth(c.year, c.month)) { first.plusDays(it.toLong()) }
        } else {
            val first = anchor.withDayOfMonth(1)
            List(anchor.lengthOfMonth()) { first.plusDays(it.toLong()) }
        }
    }
    val events = remember(days) { days.mapNotNull { d -> Synaxarium.feastOrFast(d)?.let { d to it } } }

    fun shift(step: Int) {
        anchor = if (coptic) {
            // الانتقال لمنتصف الشهر القبطي التالي/السابق
            days.first().plusDays(if (step > 0) days.size.toLong() + 2 else -3)
        } else {
            anchor.withDayOfMonth(1).plusMonths(step.toLong())
        }
    }

    val title = if (coptic) {
        val c = CopticDate.fromGregorian(days.first())
        "${c.monthName} ${c.year.arabicDigits()} ش"
    } else {
        "${GREGORIAN_MONTHS[anchor.monthValue - 1]} ${anchor.year.arabicDigits()}"
    }
    val subtitle = if (coptic) {
        val a = days.first(); val b = days.last()
        "${a.dayOfMonth.arabicDigits()} ${GREGORIAN_MONTHS[a.monthValue - 1]} – ${b.dayOfMonth.arabicDigits()} ${GREGORIAN_MONTHS[b.monthValue - 1]}"
    } else {
        val a = CopticDate.fromGregorian(days.first()); val b = CopticDate.fromGregorian(days.last())
        if (a.month == b.month) a.monthName else "${a.monthName} – ${b.monthName}"
    }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = LocalBottomInset.current)
        ) {
            ScreenHeader("النتيجة", "الأعياد وبدايات الأصوام") {
                ModeSwitch(coptic) { coptic = it; anchor = today }
            }

            LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(28.dp)) {
                Column(Modifier.padding(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RoundButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "الشهر السابق") { shift(-1) }
                        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(title, color = Palette.Text, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                            Text(subtitle, color = Palette.TextSoft, fontSize = 12.sp)
                        }
                        RoundButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, "الشهر التالي") { shift(1) }
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(Modifier.fillMaxWidth()) {
                        WEEK.forEach {
                            Text(
                                it.arabicName(),
                                color = Palette.TextFaint,
                                fontSize = 10.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                    MonthGrid(days, today, coptic)
                }
            }

            Spacer(Modifier.height(16.dp))
            LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(28.dp)) {
                Column(Modifier.padding(18.dp)) {
                    Text("الأعياد والأصوام", color = Palette.Text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    if (events.isEmpty()) {
                        Text("لا توجد أعياد كبرى أو بدايات أصوام في هذا الشهر", color = Palette.TextSoft, fontSize = 13.sp)
                    }
                    events.forEach { (date, event) -> EventRow(date, event) }
                }
            }
        }
    }
}

@Composable
private fun MonthGrid(days: List<LocalDate>, today: LocalDate, coptic: Boolean) {
    val leading = WEEK.indexOf(days.first().dayOfWeek)
    val cells: List<LocalDate?> = List(leading) { null } + days
    cells.chunked(7).forEach { week ->
        Row(Modifier.fillMaxWidth()) {
            for (i in 0 until 7) {
                val date = week.getOrNull(i)
                Box(Modifier.weight(1f).aspectRatio(0.82f).padding(2.dp)) {
                    if (date != null) DayCell(date, date == today, coptic)
                }
            }
        }
    }
}

@Composable
private fun DayCell(date: LocalDate, isToday: Boolean, coptic: Boolean) {
    val c = CopticDate.fromGregorian(date)
    val event = Synaxarium.feastOrFast(date)
    val main = if (coptic) c.day else date.dayOfMonth
    val secondary = if (coptic) date.dayOfMonth else c.day

    Column(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isToday) Palette.Gold.copy(alpha = 0.25f) else Palette.Chip.copy(alpha = 0.08f))
            .then(if (isToday) Modifier.border(1.dp, Palette.Gold, RoundedCornerShape(14.dp)) else Modifier),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(main.arabicDigits(), color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text(secondary.arabicDigits(), color = Palette.TextFaint, fontSize = 10.sp)
        Box(
            Modifier
                .padding(top = 2.dp)
                .size(5.dp)
                .clip(CircleShape)
                .background(event?.let { kindColor(it.kind) } ?: Color.Transparent)
        )
    }
}

@Composable
private fun EventRow(date: LocalDate, event: Commemoration) {
    val c = CopticDate.fromGregorian(date)
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(kindColor(event.kind)))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(event.title, color = Palette.Text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(
                "${date.dayOfWeek.arabicName()} ${date.dayOfMonth.arabicDigits()} ${GREGORIAN_MONTHS[date.monthValue - 1]}  •  ${c.day.arabicDigits()} ${c.monthName}",
                color = Palette.TextSoft,
                fontSize = 12.sp,
            )
        }
        Text(event.kind.label, color = kindColor(event.kind), fontSize = 11.sp)
    }
}

@Composable
private fun ModeSwitch(coptic: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(Palette.Chip).padding(3.dp)
    ) {
        listOf(false to "ميلادي", true to "قبطي").forEach { (value, label) ->
            Text(
                label,
                color = Palette.Text,
                fontSize = 13.sp,
                fontWeight = if (coptic == value) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (coptic == value) Palette.Chip else Color.Transparent)
                    .clickable { onChange(value) }
                    .padding(horizontal = 14.dp, vertical = 6.dp),
            )
        }
    }
}
