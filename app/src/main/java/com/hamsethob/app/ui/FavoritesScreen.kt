package com.hamsethob.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.bible.Favorites
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.share.label

@Composable
fun FavoritesScreen(favorites: Favorites, onOpenChapter: (VerseRef) -> Unit, onBack: () -> Unit) {
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 16.dp)) {
        ScreenHeader("المفضلة", "الآيات التي حفظتها", onBack)
        if (favorites.items.isEmpty()) {
            Text(
                "لم تحفظ آيات بعد. اضغط ♡ بجوار رسالة اليوم أو على أي آية في الإصحاح.",
                color = Palette.TextSoft,
                lineHeight = 24.sp,
            )
        }
        LazyColumn(contentPadding = PaddingValues(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(favorites.items, key = { "${it.ref.book}:${it.ref.chapter}:${it.ref.verse}" }) { fav ->
                LiquidGlass(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).clickable { onOpenChapter(fav.ref) },
                    shape = RoundedCornerShape(24.dp),
                    elevation = 8.dp,
                ) {
                    Column(Modifier.padding(18.dp)) {
                        Text("«${fav.text}»", color = Palette.Text, fontSize = 18.sp, lineHeight = 32.sp, fontFamily = LocalScriptureFont.current)
                        Spacer(Modifier.height(10.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(fav.ref.label(), color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            VerseActions(fav.ref, fav.text, showCopy = true)
                        }
                    }
                }
            }
        }
    }
}
