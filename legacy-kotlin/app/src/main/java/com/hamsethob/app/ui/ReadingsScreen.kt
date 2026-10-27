package com.hamsethob.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.calendar.CopticDate
import com.hamsethob.app.calendar.GREGORIAN_MONTHS
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.data.DayReadings
import com.hamsethob.app.data.KatamerosRepository
import com.hamsethob.app.data.ReadingGroup
import java.time.LocalDate

/** قراءات القطمارس اليومية: العشية، باكر، القداس. */
@Composable
fun ReadingsScreen(today: LocalDate, katameros: KatamerosRepository, onOpenSynaxarium: (LocalDate) -> Unit) {
    var date by remember(today) { mutableStateOf(today) }
    var readings by remember { mutableStateOf<DayReadings?>(null) }
    var failed by remember { mutableStateOf(false) }
    var attempt by remember { mutableIntStateOf(0) }

    LaunchedEffect(date, attempt) {
        readings = null
        failed = false
        readings = runCatching { katameros.day(date) }.onFailure { failed = true }.getOrNull()
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .navigationBarsPadding()
            .padding(horizontal = 16.dp)
            .padding(bottom = LocalBottomInset.current)
    ) {
        ScreenHeader("القراءات", "القطمارس اليومي")
        DateSwitcher(date) { date = it }
        Spacer(Modifier.height(16.dp))

        val current = readings
        when {
            current != null -> {
                current.sections.forEach { section ->
                    Text(
                        section.title,
                        color = Palette.Gold,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 8.dp, bottom = 8.dp),
                    )
                    section.groups.forEach { group ->
                        if (group.title.contains("السنكسار")) {
                            SynaxariumLink(group) { onOpenSynaxarium(date) }
                        } else {
                            ReadingCard(group)
                        }
                        Spacer(Modifier.height(10.dp))
                    }
                }
            }
            failed -> Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("تعذّر تحميل القراءات، تأكد من الاتصال بالإنترنت", color = Palette.TextSoft, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                GlassPill("إعادة المحاولة") { attempt++ }
            }
            else -> Box(Modifier.fillMaxWidth().padding(40.dp), Alignment.Center) {
                CircularProgressIndicator(color = Palette.Text)
            }
        }
    }
}

@Composable
fun DateSwitcher(date: LocalDate, onChange: (LocalDate) -> Unit) {
    val c = CopticDate.fromGregorian(date)
    LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), elevation = 8.dp) {
        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            RoundButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "اليوم السابق") { onChange(date.minusDays(1)) }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${c.day.arabicDigits()} ${c.monthName} ${c.year.arabicDigits()} ش", color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("${date.dayOfMonth.arabicDigits()} ${GREGORIAN_MONTHS[date.monthValue - 1]} ${date.year.arabicDigits()} م", color = Palette.TextSoft, fontSize = 12.sp)
            }
            RoundButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, "اليوم التالي") { onChange(date.plusDays(1)) }
        }
    }
}

@Composable
private fun ReadingCard(group: ReadingGroup) {
    var expanded by remember(group) { mutableStateOf(false) }
    val refs = group.readings.flatMap { it.passages }.joinToString(" ، ") { "${it.book} ${it.ref.arabicRef()}" }

    LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(24.dp), elevation = 10.dp) {
        Column {
            Row(
                Modifier.fillMaxWidth().clickable { expanded = !expanded }.padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(group.title, color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    if (refs.isNotBlank()) Text(refs, color = Palette.TextSoft, fontSize = 12.sp)
                }
                Icon(if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown, null, tint = Palette.TextSoft)
            }
            if (expanded) {
                Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    group.introduction?.let { Text(it, color = Palette.TextFaint, fontSize = 13.sp, lineHeight = 22.sp) }
                    group.readings.forEach { reading ->
                        reading.introduction?.let { Text(it, color = Palette.TextFaint, fontSize = 13.sp, lineHeight = 22.sp) }
                        reading.passages.forEach { p ->
                            Text("${p.book} ${p.ref.arabicRef()}", color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                            Text(p.text, color = Palette.Text, fontSize = 18.sp, lineHeight = 33.sp, fontFamily = LocalScriptureFont.current)
                        }
                        reading.conclusion?.let { Text(it, color = Palette.TextFaint, fontSize = 13.sp) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SynaxariumLink(group: ReadingGroup, onClick: () -> Unit) {
    LiquidGlass(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).clickable(onClick = onClick),
        shape = RoundedCornerShape(24.dp),
        elevation = 10.dp,
    ) {
        Row(Modifier.padding(horizontal = 18.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("السنكسار", color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text(
                    group.readings.mapNotNull { it.title }.joinToString(" • "),
                    color = Palette.TextSoft,
                    fontSize = 12.sp,
                    maxLines = 2,
                )
            }
            Spacer(Modifier.width(8.dp))
            Box(Modifier.clip(RoundedCornerShape(50)).background(Palette.Chip).padding(horizontal = 12.dp, vertical = 6.dp)) {
                Text("اقرأ السير  ‹", color = Palette.Gold, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
