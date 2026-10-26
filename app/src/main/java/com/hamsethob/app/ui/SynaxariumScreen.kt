package com.hamsethob.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.data.KatamerosRepository
import com.hamsethob.app.data.SaintStory
import java.time.LocalDate

/** سير قديسي اليوم كاملة من السنكسار. */
@Composable
fun SynaxariumScreen(start: LocalDate, katameros: KatamerosRepository, onBack: () -> Unit) {
    var date by remember { mutableStateOf(start) }
    var stories by remember { mutableStateOf<List<SaintStory>?>(null) }
    var failed by remember { mutableStateOf(false) }

    LaunchedEffect(date) {
        stories = null
        failed = false
        stories = runCatching { katameros.day(date).synaxarium }.onFailure { failed = true }.getOrNull()
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .navigationBarsPadding()
            .padding(horizontal = 16.dp)
            .padding(bottom = 24.dp)
    ) {
        ScreenHeader("السنكسار", "سير القديسين وتذكاراتهم", onBack)
        DateSwitcher(date) { date = it }
        Spacer(Modifier.height(16.dp))

        val current = stories
        when {
            current != null && current.isEmpty() -> Text("لا يوجد سنكسار لهذا اليوم (قد يكون يوم أحد أو عيد سيدي)", color = Palette.TextSoft)
            current != null -> current.forEach { story ->
                LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), elevation = 10.dp) {
                    Column(Modifier.padding(20.dp)) {
                        Text(story.title, color = Palette.Gold, fontSize = 18.sp, fontWeight = FontWeight.Bold, lineHeight = 28.sp)
                        Spacer(Modifier.height(10.dp))
                        Text(story.text, color = Palette.Text, fontSize = 17.sp, lineHeight = 31.sp, fontFamily = LocalScriptureFont.current)
                    }
                }
                Spacer(Modifier.height(14.dp))
            }
            failed -> Text("تعذّر تحميل السنكسار، تأكد من الاتصال بالإنترنت", color = Palette.TextSoft)
            else -> Box(Modifier.fillMaxWidth().padding(40.dp), Alignment.Center) {
                CircularProgressIndicator(color = Palette.Text)
            }
        }
    }
}
