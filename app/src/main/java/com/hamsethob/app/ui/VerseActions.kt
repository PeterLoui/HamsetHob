package com.hamsethob.app.ui

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Share
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.hamsethob.app.bible.Favorites
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.share.VerseShare
import kotlinx.coroutines.launch

/** أزرار الآية: حفظ في المفضلة، مشاركة كصورة، ونسخ (اختياري). */
@Composable
fun VerseActions(ref: VerseRef, text: String, showCopy: Boolean = false) {
    val context = LocalContext.current
    val favorites = Favorites.get(context)
    val colors = LocalAppColors.current
    val scope = rememberCoroutineScope()
    val saved = favorites.items.any { it.ref == ref }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        RoundButton(
            if (saved) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
            "حفظ في المفضلة",
            tint = if (saved) Palette.Saint else Palette.Text,
        ) { favorites.toggle(ref, text) }
        RoundButton(Icons.Filled.Share, "مشاركة كصورة") {
            scope.launch { VerseShare.shareImage(context, ref, text, colors) }
        }
        if (showCopy) {
            RoundButton(Icons.Filled.Check, "نسخ") {
                VerseShare.copy(context, ref, text)
                Toast.makeText(context, "تم نسخ الآية", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
