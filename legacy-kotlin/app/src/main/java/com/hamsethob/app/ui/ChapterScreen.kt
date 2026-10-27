package com.hamsethob.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.bible.BOOKS
import com.hamsethob.app.bible.BibleRepository
import com.hamsethob.app.bible.Verse
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.calendar.arabicDigits

/**
 * عرض الإصحاح كاملاً مع تمييز الآية المطلوبة (verse = 0 بدون تمييز)
 * والتنقل بين الإصحاحات. الضغط على آية يُظهر أزرار الحفظ والمشاركة والنسخ.
 */
@Composable
fun ChapterScreen(start: VerseRef, bible: BibleRepository, onBack: () -> Unit) {
    var book by remember { mutableIntStateOf(start.book) }
    var chapter by remember { mutableIntStateOf(start.chapter) }
    var verses by remember { mutableStateOf<List<Verse>?>(null) }
    var failed by remember { mutableStateOf(false) }
    var selected by remember { mutableIntStateOf(0) }
    val listState = rememberLazyListState()
    val highlight = if (book == start.book && chapter == start.chapter) start.verse else -1

    LaunchedEffect(book, chapter) {
        verses = null
        failed = false
        selected = 0
        verses = runCatching { bible.chapter(book, chapter) }.onFailure { failed = true }.getOrNull()
        val index = verses?.indexOfFirst { it.number == highlight } ?: -1
        listState.scrollToItem(if (index > 0) index else 0)
    }

    fun move(step: Int) {
        val current = BOOKS[book - 1]
        val next = chapter + step
        when {
            next in 1..current.chapters -> chapter = next
            step > 0 && book < BOOKS.size -> { book++; chapter = 1 }
            step < 0 && book > 1 -> { book--; chapter = BOOKS[book - 1].chapters }
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 16.dp)) {
        ScreenHeader(BOOKS[book - 1].name, "الإصحاح ${chapter.arabicDigits()}", onBack)

        Box(Modifier.weight(1f).fillMaxWidth()) {
            val current = verses
            when {
                current != null -> LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    items(current, key = { it.number }) { verse ->
                        val isMarked = verse.number == highlight
                        val isSelected = verse.number == selected
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(
                                    when {
                                        isSelected -> Palette.Chip
                                        isMarked -> Palette.Gold.copy(alpha = 0.2f)
                                        else -> Color.Transparent
                                    }
                                )
                                .clickable { selected = if (isSelected) 0 else verse.number }
                                .padding(horizontal = 12.dp, vertical = 8.dp)
                        ) {
                            Row {
                                Text(
                                    verse.number.arabicDigits(),
                                    color = Palette.Gold,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.width(30.dp).padding(top = 6.dp),
                                )
                                Text(
                                    verse.text,
                                    color = Palette.Text,
                                    fontSize = 19.sp,
                                    lineHeight = 34.sp,
                                    fontFamily = LocalScriptureFont.current,
                                )
                            }
                            AnimatedVisibility(isSelected) {
                                Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
                                    VerseActions(VerseRef(book, chapter, verse.number), verse.text, showCopy = true)
                                }
                            }
                        }
                    }
                }
                failed -> Text(
                    "تعذّر تحميل الإصحاح، تأكد من الاتصال بالإنترنت",
                    color = Palette.TextSoft,
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> CircularProgressIndicator(color = Palette.Text, modifier = Modifier.align(Alignment.Center))
            }
        }

        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            GlassPill("→  الإصحاح السابق") { move(-1) }
            GlassPill("الإصحاح التالي  ←") { move(1) }
        }
    }
}
