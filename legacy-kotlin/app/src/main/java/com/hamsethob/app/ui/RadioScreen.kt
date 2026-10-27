package com.hamsethob.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.radio.RadioPlayer
import com.hamsethob.app.radio.SERMON_CATEGORIES
import com.hamsethob.app.radio.Sermon
import com.hamsethob.app.radio.categoryName
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** تحديث شريط التقدم كل ثانية أثناء التشغيل. */
@Composable
private fun ProgressTicker(player: RadioPlayer) {
    LaunchedEffect(player.isPlaying) {
        while (player.isPlaying) {
            player.tick()
            delay(1_000)
        }
    }
}

fun formatTime(ms: Long): String {
    val total = ms / 1000
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    val text = if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
    return text.map { if (it.isDigit()) '٠' + (it - '0') else it }.joinToString("")
}

/** كارت الإذاعة في الصفحة الرئيسية (أسفل آخر مستطيل). */
@Composable
fun RadioCard(player: RadioPlayer, onOpen: () -> Unit) {
    val scope = rememberCoroutineScope()
    val now = player.nowPlaying
    LiquidGlass(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)).clickable(onClick = onOpen),
        shape = RoundedCornerShape(28.dp),
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(Palette.Gold.copy(alpha = 0.22f)),
                    contentAlignment = Alignment.Center,
                ) { Icon(AppIcons.Radio, null, tint = Palette.Gold, modifier = Modifier.size(24.dp)) }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    SectionTitle("الإذاعة")
                    Text("عظات قداسة البابا شنوده الثالث", color = Palette.TextSoft, fontSize = 12.sp)
                }
                Text("المكتبة  ‹", color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(14.dp))
            if (now != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(if (player.isPlaying) "يُذاع الآن" else "متوقف مؤقتاً", color = Palette.TextFaint, fontSize = 11.sp)
                        Text(now.title, color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    PlayButton(player, 44.dp)
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GlassPill("▶  بث متواصل") { scope.launch { player.startRadio() } }
                    GlassPill("تصفح العظات", onClick = onOpen)
                }
            }
            player.error?.let { Text(it, color = Palette.Saint, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp)) }
        }
    }
}

/** شريط تشغيل صغير فوق الشريط السفلي. */
@Composable
fun MiniPlayer(player: RadioPlayer, onOpen: () -> Unit, modifier: Modifier = Modifier) {
    val now = player.nowPlaying ?: return
    ProgressTicker(player)
    LiquidGlass(
        modifier.fillMaxWidth().height(58.dp).clip(RoundedCornerShape(29.dp)).clickable(onClick = onOpen),
        shape = RoundedCornerShape(29.dp),
        elevation = 14.dp,
    ) {
        Row(Modifier.fillMaxSize().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            PlayButton(player, 42.dp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(now.title, color = Palette.Text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(
                    if (player.radioOn) "بث متواصل • ${now.category}" else now.category,
                    color = Palette.TextSoft,
                    fontSize = 11.sp,
                    maxLines = 1,
                )
            }
            Icon(AppIcons.Radio, null, tint = Palette.Gold, modifier = Modifier.padding(horizontal = 10.dp).size(20.dp))
        }
        // تقدم التشغيل كخط رفيع أسفل الشريط
        if (player.duration > 0) {
            Box(
                Modifier
                    .align(Alignment.BottomStart)
                    .padding(horizontal = 24.dp)
                    .fillMaxWidth((player.position.toFloat() / player.duration).coerceIn(0f, 1f))
                    .height(2.dp)
                    .background(Palette.Gold)
            )
        }
    }
}

@Composable
private fun PlayButton(player: RadioPlayer, size: Dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(Palette.Gold).clickable { player.toggle() },
        contentAlignment = Alignment.Center,
    ) {
        if (player.isBuffering || player.loadingId != null) {
            CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(size * 0.45f))
        } else {
            Icon(
                if (player.isPlaying) AppIcons.Pause else AppIcons.Play,
                if (player.isPlaying) "إيقاف مؤقت" else "تشغيل",
                tint = Color.White,
                modifier = Modifier.size(size * 0.5f),
            )
        }
    }
}

/** شاشة الإذاعة: المشغّل + أقسام المكتبة + البحث. */
@Composable
fun RadioScreen(player: RadioPlayer, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var category by remember { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    val sermons = remember { mutableStateListOf<Sermon>() }
    var page by remember { mutableIntStateOf(1) }
    var totalPages by remember { mutableIntStateOf(1) }
    var loading by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    suspend fun load(reset: Boolean) {
        if (loading) return
        loading = true
        failed = false
        val target = if (reset) 1 else page + 1
        runCatching { player.repository.page(category, query, target) }
            .onSuccess {
                if (reset) sermons.clear()
                sermons.addAll(it.items)
                page = target
                totalPages = it.totalPages
            }
            .onFailure { failed = true }
        loading = false
    }

    LaunchedEffect(category, query) {
        if (query.isNotEmpty()) delay(450)
        load(reset = true)
    }
    val nearEnd by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= listState.layoutInfo.totalItemsCount - 3
        }
    }
    LaunchedEffect(nearEnd) {
        if (nearEnd && page < totalPages && sermons.isNotEmpty()) load(reset = false)
    }
    ProgressTicker(player)

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item { ScreenHeader("الإذاعة", "مكتبة عظات قداسة البابا شنوده الثالث", onBack) }
        item { NowPlayingCard(player) { scope.launch { player.startRadio(category) } } }
        item {
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SERMON_CATEGORIES.forEach { c ->
                    val on = c.id == category
                    Text(
                        c.name,
                        color = if (on) Color.White else Palette.Text,
                        fontSize = 13.sp,
                        fontWeight = if (on) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(if (on) Palette.Gold else Palette.Chip)
                            .clickable { category = c.id }
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                    )
                }
            }
        }
        item { SermonSearch(query) { query = it } }
        if (failed && sermons.isEmpty()) {
            item { Text("تعذّر تحميل العظات، تأكد من الاتصال بالإنترنت", color = Palette.TextSoft) }
        }
        if (!loading && !failed && sermons.isEmpty()) {
            item { Text("لا توجد عظات مطابقة", color = Palette.TextSoft) }
        }
        items(sermons, key = { it.id }) { sermon -> SermonRow(sermon, player) { scope.launch { player.play(sermon) } } }
        if (loading) {
            item {
                Box(Modifier.fillMaxWidth().padding(20.dp), Alignment.Center) {
                    CircularProgressIndicator(color = Palette.Text, modifier = Modifier.size(28.dp))
                }
            }
        }
    }
}

@Composable
private fun NowPlayingCard(player: RadioPlayer, onStartRadio: () -> Unit) {
    val now = player.nowPlaying
    LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(30.dp)) {
        Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                Modifier.size(64.dp).clip(CircleShape).background(Palette.Gold.copy(alpha = 0.22f)),
                contentAlignment = Alignment.Center,
            ) { Icon(AppIcons.Radio, null, tint = Palette.Gold, modifier = Modifier.size(34.dp)) }
            Spacer(Modifier.height(12.dp))
            Text(
                now?.title ?: "اختر عظة أو ابدأ البث المتواصل",
                color = Palette.Text,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                now?.let { if (player.radioOn) "بث متواصل • ${it.category}" else it.category } ?: "عظات عشوائية متتالية من المكتبة",
                color = Palette.TextSoft,
                fontSize = 12.sp,
            )

            if (now != null) {
                Spacer(Modifier.height(8.dp))
                val dur = player.duration.coerceAtLeast(1)
                Slider(
                    value = player.position.coerceAtMost(dur).toFloat(),
                    onValueChange = { player.seekTo(it.toLong()) },
                    valueRange = 0f..dur.toFloat(),
                    colors = SliderDefaults.colors(
                        thumbColor = Palette.Gold,
                        activeTrackColor = Palette.Gold,
                        inactiveTrackColor = Palette.Chip,
                    ),
                )
                Row(Modifier.fillMaxWidth()) {
                    Text(formatTime(player.position), color = Palette.TextFaint, fontSize = 11.sp, modifier = Modifier.weight(1f))
                    Text(formatTime(player.duration), color = Palette.TextFaint, fontSize = 11.sp)
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    ControlButton(AppIcons.Back30, "رجوع ٣٠ ثانية") { player.seekBack() }
                    PlayButton(player, 60.dp)
                    ControlButton(AppIcons.Forward30, "تقديم ٣٠ ثانية") { player.seekForward() }
                    if (player.hasNext) ControlButton(AppIcons.SkipNext, "العظة التالية") { player.next() }
                }
            }
            Spacer(Modifier.height(12.dp))
            if (player.radioOn) {
                GlassPill("إيقاف البث المتواصل", small = true) { player.stopRadio() }
            } else {
                GlassPill("▶  بث متواصل عشوائي", small = true, onClick = onStartRadio)
            }
            player.error?.let { Text(it, color = Palette.Saint, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp)) }
        }
    }
}

@Composable
private fun ControlButton(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(CircleShape).background(Palette.Chip).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, description, tint = Palette.Text, modifier = Modifier.size(22.dp)) }
}

@Composable
private fun SermonRow(sermon: Sermon, player: RadioPlayer, onPlay: () -> Unit) {
    val current = player.nowPlaying?.id == sermon.id.toString()
    LiquidGlass(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).clickable(onClick = onPlay),
        shape = RoundedCornerShape(22.dp),
        elevation = 6.dp,
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(if (current) Palette.Gold else Palette.Chip),
                contentAlignment = Alignment.Center,
            ) {
                if (player.loadingId == sermon.id) {
                    CircularProgressIndicator(color = Palette.Text, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                } else {
                    Icon(
                        if (current && player.isPlaying) AppIcons.Pause else AppIcons.Play,
                        null,
                        tint = if (current) Color.White else Palette.Text,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(sermon.title, color = Palette.Text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(categoryName(sermon.categoryId), color = Palette.Gold, fontSize = 11.sp)
                if (sermon.summary.isNotBlank()) {
                    Text(sermon.summary, color = Palette.TextSoft, fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 18.sp)
                }
            }
        }
    }
}

@Composable
private fun SermonSearch(value: String, onChange: (String) -> Unit) {
    LiquidGlass(Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(25.dp), elevation = 6.dp) {
        Row(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Search, null, tint = Palette.TextSoft)
            Spacer(Modifier.width(10.dp))
            Box(Modifier.weight(1f)) {
                if (value.isEmpty()) Text("ابحث في العظات… (مثال: التوبة)", color = Palette.TextFaint, fontSize = 14.sp)
                BasicTextField(
                    value = value,
                    onValueChange = onChange,
                    singleLine = true,
                    textStyle = TextStyle(color = Palette.Text, fontSize = 15.sp),
                    cursorBrush = SolidColor(Palette.Text),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (value.isNotEmpty()) {
                Icon(Icons.Filled.Clear, "مسح", tint = Palette.TextSoft, modifier = Modifier.clip(CircleShape).clickable { onChange("") })
            }
        }
    }
}

