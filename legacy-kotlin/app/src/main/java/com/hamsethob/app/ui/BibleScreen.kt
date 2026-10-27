package com.hamsethob.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.bible.BOOKS
import com.hamsethob.app.bible.Book
import com.hamsethob.app.bible.BibleRepository
import com.hamsethob.app.bible.SearchHit
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.share.label
import kotlinx.coroutines.delay

/** تصفح الأسفار بالعهدين والبحث في نص الكتاب المقدس. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BibleScreen(bible: BibleRepository, onOpenChapter: (VerseRef) -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    var newTestament by rememberSaveable { mutableStateOf(false) }
    var openBook by rememberSaveable { mutableStateOf(0) }
    var results by remember { mutableStateOf<List<SearchHit>?>(null) }
    var searching by remember { mutableStateOf(false) }
    var searchFailed by remember { mutableStateOf(false) }

    LaunchedEffect(query) {
        if (query.trim().length < 2) { results = null; searching = false; return@LaunchedEffect }
        delay(450) // انتظار انتهاء الكتابة
        searching = true
        searchFailed = false
        results = runCatching { bible.search(query) }.onFailure { searchFailed = true }.getOrNull()
        searching = false
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 16.dp)) {
        ScreenHeader("الكتاب المقدس", "ترجمة فاندايك")
        SearchField(query) { query = it }
        Spacer(Modifier.height(14.dp))

        if (query.trim().length >= 2) {
            when {
                searching -> Box(Modifier.fillMaxWidth().padding(32.dp), Alignment.Center) {
                    CircularProgressIndicator(color = Palette.Text)
                }
                searchFailed -> Text("تعذّر البحث، تأكد من الاتصال أو حمّل الكتاب كاملاً من «المزيد»", color = Palette.TextSoft)
                results?.isEmpty() == true -> Text("لا توجد نتائج", color = Palette.TextSoft)
                results != null -> {
                    Text("${results!!.size.arabicDigits()} نتيجة", color = Palette.TextFaint, fontSize = 12.sp)
                    LazyColumn(contentPadding = PaddingValues(top = 8.dp, bottom = LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(results!!) { hit ->
                            LiquidGlass(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).clickable { onOpenChapter(hit.ref) },
                                shape = RoundedCornerShape(22.dp),
                                elevation = 6.dp,
                            ) {
                                Column(Modifier.padding(16.dp)) {
                                    Text(hit.ref.label(), color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                    Spacer(Modifier.height(4.dp))
                                    Text(hit.text, color = Palette.Text, fontSize = 17.sp, lineHeight = 30.sp, fontFamily = LocalScriptureFont.current)
                                }
                            }
                        }
                    }
                }
            }
            return@Column
        }

        TestamentSwitch(newTestament) { newTestament = it; openBook = 0 }
        Spacer(Modifier.height(12.dp))
        val books = if (newTestament) BOOKS.drop(39) else BOOKS.take(39)
        LazyColumn(contentPadding = PaddingValues(bottom = LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(books, key = { it.number }) { book ->
                BookRow(book, expanded = openBook == book.number, onToggle = {
                    openBook = if (openBook == book.number) 0 else book.number
                }) { chapter -> onOpenChapter(VerseRef(book.number, chapter, 0)) }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BookRow(book: Book, expanded: Boolean, onToggle: () -> Unit, onChapter: (Int) -> Unit) {
    LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), elevation = 6.dp) {
        Column {
            Row(
                Modifier.fillMaxWidth().clickable(onClick = onToggle).padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(book.name, color = Palette.Text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text("${book.chapters.arabicDigits()} إصحاح", color = Palette.TextFaint, fontSize = 12.sp)
            }
            if (expanded) {
                FlowRow(
                    Modifier.padding(start = 12.dp, end = 12.dp, bottom = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    for (ch in 1..book.chapters) {
                        Box(
                            Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(Palette.Chip).clickable { onChapter(ch) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(ch.arabicDigits(), color = Palette.Text, fontSize = 14.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(value: String, onChange: (String) -> Unit) {
    LiquidGlass(Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(26.dp), elevation = 8.dp) {
        Row(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Search, null, tint = Palette.TextSoft)
            Spacer(Modifier.width(10.dp))
            Box(Modifier.weight(1f)) {
                if (value.isEmpty()) Text("ابحث في الكتاب المقدس… (مثال: المحبة)", color = Palette.TextFaint, fontSize = 15.sp)
                BasicTextField(
                    value = value,
                    onValueChange = onChange,
                    singleLine = true,
                    textStyle = TextStyle(color = Palette.Text, fontSize = 16.sp),
                    cursorBrush = SolidColor(Palette.Text),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (value.isNotEmpty()) {
                Icon(Icons.Filled.Clear, "مسح", tint = Palette.TextSoft, modifier = Modifier.clip(RoundedCornerShape(50)).clickable { onChange("") })
            }
        }
    }
}

@Composable
private fun TestamentSwitch(newTestament: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Palette.Chip).padding(4.dp)) {
        listOf(false to "العهد القديم", true to "العهد الجديد").forEach { (value, label) ->
            val on = newTestament == value
            Text(
                label,
                color = Palette.Text,
                fontSize = 14.sp,
                fontWeight = if (on) FontWeight.Bold else FontWeight.Normal,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50))
                    .background(if (on) Palette.Chip else androidx.compose.ui.graphics.Color.Transparent)
                    .clickable { onChange(value) }
                    .padding(vertical = 9.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}
