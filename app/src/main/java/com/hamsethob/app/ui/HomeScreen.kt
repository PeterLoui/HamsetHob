package com.hamsethob.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.hamsethob.app.bible.DailyVerse
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.calendar.Commemoration
import com.hamsethob.app.calendar.CopticDate
import com.hamsethob.app.calendar.GREGORIAN_MONTHS
import com.hamsethob.app.calendar.Kind
import com.hamsethob.app.calendar.Synaxarium
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.calendar.arabicName
import com.hamsethob.app.data.DayReadings
import com.hamsethob.app.data.Services
import com.hamsethob.app.radio.RadioPlayer
import com.hamsethob.app.share.label
import java.time.LocalDate
import java.time.LocalTime

@Composable
private fun softShadow() =
    if (LocalAppColors.current.isDark) Shadow(Color(0x66000000), Offset(0f, 2f), 8f) else Shadow(Color(0x55FFFFFF), Offset(0f, 1f), 6f)

@Composable
fun HomeScreen(
    today: LocalDate,
    services: Services,
    onOpenChapter: (VerseRef) -> Unit,
    onOpenSynaxarium: () -> Unit,
    onOpenReadings: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenRadio: () -> Unit,
    onVerseChanged: () -> Unit,
    radio: RadioPlayer,
) {
    val readings by produceState<DayReadings?>(null, today) {
        value = runCatching { services.katameros.day(today) }.getOrNull()
    }
    val commemoration = remember(today, readings) {
        val local = Synaxarium.forDate(today)
        val stories = readings?.synaxarium.orEmpty()
        if (local.generic && stories.isNotEmpty()) {
            val more = stories.size - 1
            Commemoration(
                stories.first().title,
                if (more > 0) "و${more.arabicDigits()} ${if (more == 1) "تذكار آخر" else "تذكارات أخرى"} في سنكسار اليوم" else "سنكسار اليوم",
                Kind.SAINT,
                local.wiki,
            )
        } else local
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = LocalBottomInset.current)
    ) {
        Header(today, onOpenFavorites)
        Spacer(Modifier.height(16.dp))
        DateCard(today, commemoration, services, onOpenSynaxarium)
        Spacer(Modifier.height(16.dp))
        VerseCard(today, services, onOpenChapter, onVerseChanged)
        readings?.let { GospelCard(it, onOpenReadings) }
        Spacer(Modifier.height(16.dp))
        RadioCard(radio, onOpenRadio)
    }
}

@Composable
private fun Header(today: LocalDate, onOpenFavorites: () -> Unit) {
    val greeting = if (LocalTime.now().hour < 12) "صباح الخير" else "مساء الخير"
    Row(Modifier.fillMaxWidth().padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text("$greeting  •  ${today.dayOfWeek.arabicName()}", color = Palette.TextFaint, fontSize = 14.sp)
            Text("همسة حب", color = Palette.Text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        }
        LiquidGlass(Modifier.size(46.dp).clip(CircleShape).clickable(onClick = onOpenFavorites), shape = CircleShape, elevation = 8.dp) {
            Icon(Icons.Filled.Favorite, "المفضلة", tint = Palette.Saint, modifier = Modifier.align(Alignment.Center).size(22.dp))
        }
    }
}

@Composable
private fun DateCard(today: LocalDate, commemoration: Commemoration, services: Services, onOpenSynaxarium: () -> Unit) {
    val coptic = remember(today) { CopticDate.fromGregorian(today) }
    val colors = LocalAppColors.current
    val imageUrl by produceState<String?>(null, commemoration) {
        value = services.images.imageUrl(commemoration.wiki, commemoration.title)
    }
    val shadow = softShadow()

    LiquidGlass(
        modifier = Modifier
            .fillMaxWidth()
            .height(212.dp)
            .clip(RoundedCornerShape(32.dp))
            .clickable(onClick = onOpenSynaxarium),
        backdrop = {
            if (imageUrl != null) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = commemoration.title,
                    contentScale = ContentScale.Crop,
                    alpha = if (colors.isDark) 0.42f else 0.30f,
                    modifier = Modifier.matchParentSize(),
                )
            } else {
                CrossArt()
            }
            // تظليل خفيف يحافظ على وضوح النص فوق الصورة
            Box(Modifier.matchParentSize().background(Brush.verticalGradient(colors.imageShade)))
        },
    ) {
        Box(Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)) {
            // يمين: اليوم والشهر والسنة القبطية
            Column(Modifier.align(Alignment.TopStart)) {
                Text(
                    coptic.day.arabicDigits(),
                    style = TextStyle(color = Palette.Text, fontSize = 40.sp, fontWeight = FontWeight.Bold, shadow = shadow),
                )
                Text(
                    "${coptic.monthName} ${coptic.year.arabicDigits()} ش",
                    style = TextStyle(color = Palette.TextSoft, fontSize = 15.sp, shadow = shadow),
                )
            }
            // يسار: اليوم والشهر والسنة الميلادية
            Column(Modifier.align(Alignment.TopEnd), horizontalAlignment = Alignment.End) {
                Text(
                    today.dayOfMonth.arabicDigits(),
                    style = TextStyle(color = Palette.Text, fontSize = 40.sp, fontWeight = FontWeight.Bold, shadow = shadow),
                )
                Text(
                    "${GREGORIAN_MONTHS[today.monthValue - 1]} ${today.year.arabicDigits()} م",
                    style = TextStyle(color = Palette.TextSoft, fontSize = 15.sp, shadow = shadow),
                )
            }
            // في المنتصف أسفل قليلاً: التذكار أو العيد
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                KindChip(commemoration.kind)
                Spacer(Modifier.height(6.dp))
                Text(
                    commemoration.title,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = TextStyle(color = Palette.Text, fontSize = 20.sp, fontWeight = FontWeight.Bold, shadow = shadow),
                )
                Text(
                    commemoration.detail,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = TextStyle(color = Palette.TextSoft, fontSize = 13.sp, shadow = shadow),
                )
            }
            // أسفل اليسار: فتح السنكسار الكامل
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                "السنكسار",
                tint = Palette.TextSoft,
                modifier = Modifier.align(Alignment.BottomEnd).size(22.dp),
            )
        }
    }
}

@Composable
private fun VerseCard(
    today: LocalDate,
    services: Services,
    onOpenChapter: (VerseRef) -> Unit,
    onVerseChanged: () -> Unit,
) {
    var verse by remember { mutableStateOf<DailyVerse?>(null) }
    var failed by remember { mutableStateOf(false) }
    var reload by remember { mutableIntStateOf(0) }

    LaunchedEffect(today, reload) {
        failed = false
        val loaded = runCatching { services.bible.dailyVerse(today, forceNew = reload > 0) }
            .onFailure { failed = true }
            .getOrNull()
        if (loaded != null && loaded != verse) {
            verse = loaded
            onVerseChanged() // تحديث الويدجتس بنفس الآية
        }
    }

    LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(28.dp)) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("✦", color = Palette.Gold, fontSize = 16.sp)
                Spacer(Modifier.width(8.dp))
                SectionTitle("رسالة اليوم", Modifier.weight(1f))
                verse?.let { VerseActions(it.ref, it.text) }
                Spacer(Modifier.width(8.dp))
                RoundButton(Icons.Filled.Refresh, "رسالة أخرى") { reload++ }
            }
            Spacer(Modifier.height(12.dp))

            val current = verse
            when {
                current != null -> {
                    Text(
                        "«${current.text}»",
                        color = Palette.Text,
                        fontSize = 19.sp,
                        lineHeight = 34.sp,
                        fontFamily = LocalScriptureFont.current,
                    )
                    Spacer(Modifier.height(14.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            current.ref.label(),
                            color = Palette.Gold,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f),
                        )
                        // أسفل اليسار: زر عرض الإصحاح كاملاً
                        GlassPill("النص كاملاً  ‹", small = true) { onOpenChapter(current.ref) }
                    }
                }
                failed -> Text(
                    "تعذّر تحميل الآية، تأكد من الاتصال بالإنترنت ثم اضغط زر التحديث",
                    color = Palette.TextSoft,
                    fontSize = 14.sp,
                )
                else -> Box(Modifier.fillMaxWidth().height(60.dp), Alignment.Center) {
                    CircularProgressIndicator(color = Palette.Text, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
                }
            }
        }
    }
}

/** اختصار لإنجيل القداس اليوم من القطمارس. */
@Composable
private fun GospelCard(readings: DayReadings, onOpenReadings: () -> Unit) {
    val gospel = readings.sections.firstOrNull { it.title.contains("قداس") }
        ?.groups?.lastOrNull { it.title.contains("الإنجيل") }
        ?.readings?.flatMap { it.passages }?.lastOrNull() ?: return

    Spacer(Modifier.height(16.dp))
    LiquidGlass(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).clickable(onClick = onOpenReadings),
        shape = RoundedCornerShape(24.dp),
        elevation = 12.dp,
    ) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("إنجيل القداس اليوم", color = Palette.TextFaint, fontSize = 12.sp)
                Text("${gospel.book} ${gospel.ref.arabicRef()}", color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
            Text("القراءات  ‹", color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

fun String.arabicRef(): String = map { if (it.isDigit()) '٠' + (it - '0') else it }.joinToString("")

@Composable
private fun KindChip(kind: Kind) {
    val color = when (kind) {
        Kind.FEAST -> Palette.Gold
        Kind.FAST -> Palette.Fast
        Kind.SAINT -> Palette.Saint
    }
    Text(
        kind.label,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Palette.Chip)
            .padding(horizontal = 12.dp, vertical = 4.dp),
    )
}

/** رسمة بديلة (صليب قبطي بهالة) عندما لا تتوفر صورة للتذكار. */
@Composable
private fun BoxScope.CrossArt() {
    val line = Palette.Text.copy(alpha = 0.33f)
    Canvas(Modifier.matchParentSize()) {
        val c = Offset(size.width / 2, size.height * 0.42f)
        val arm = size.height * 0.22f
        val w = arm * 0.34f
        drawCircle(Brush.radialGradient(listOf(Color(0x55F3C77A), Color.Transparent), c, arm * 2.2f), arm * 2.2f, c)
        val stroke = Stroke(width = 3.dp.toPx())
        drawRect(line, Offset(c.x - w / 2, c.y - arm), Size(w, arm * 2), style = stroke)
        drawRect(line, Offset(c.x - arm, c.y - w / 2), Size(arm * 2, w), style = stroke)
        drawCircle(line, arm * 0.62f, c, style = stroke)
    }
}
