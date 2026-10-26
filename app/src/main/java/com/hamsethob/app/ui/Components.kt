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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

enum class Tab(val icon: ImageVector, val label: String) {
    HOME(AppIcons.Home, "الرئيسية"),
    BIBLE(AppIcons.Bible, "الكتاب"),
    READINGS(AppIcons.Readings, "القراءات"),
    CALENDAR(AppIcons.Calendar, "النتيجة"),
    MORE(AppIcons.More, "المزيد"),
}

/** الشريط السفلي الزجاجي. */
@Composable
fun BottomBar(selected: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
    LiquidGlass(modifier.fillMaxWidth().height(68.dp), shape = RoundedCornerShape(34.dp)) {
        Row(
            Modifier.fillMaxSize().padding(horizontal = 6.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Tab.entries.forEach { tab ->
                val isSelected = tab == selected
                Column(
                    Modifier
                        .clip(RoundedCornerShape(22.dp))
                        .background(if (isSelected) Palette.Chip else Color.Transparent)
                        .clickable { onSelect(tab) }
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(tab.icon, null, tint = if (isSelected) Palette.Text else Palette.TextSoft, modifier = Modifier.size(22.dp))
                    Text(
                        tab.label,
                        color = if (isSelected) Palette.Text else Palette.TextSoft,
                        fontSize = 11.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    )
                }
            }
        }
    }
}

@Composable
fun GlassPill(text: String, small: Boolean = false, onClick: () -> Unit) {
    LiquidGlass(Modifier.clip(RoundedCornerShape(50)).clickable(onClick = onClick), shape = RoundedCornerShape(50), elevation = 4.dp) {
        Text(
            text,
            color = Palette.Text,
            fontSize = if (small) 12.sp else 14.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = if (small) 7.dp else 10.dp),
        )
    }
}

@Composable
fun RoundButton(icon: ImageVector, description: String?, tint: Color = Palette.Text, onClick: () -> Unit) {
    Box(
        Modifier.size(40.dp).clip(CircleShape).background(Palette.Chip).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, description, tint = tint, modifier = Modifier.size(20.dp))
    }
}

/** رأس الشاشات الفرعية: زر رجوع + عنوان. */
@Composable
fun ScreenHeader(title: String, subtitle: String? = null, onBack: (() -> Unit)? = null, trailing: @Composable () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onBack != null) {
            // سهم الرجوع ينعكس تلقائياً ليشير لليمين في الواجهة العربية
            RoundButton(Icons.AutoMirrored.Filled.ArrowBack, "رجوع", onClick = onBack)
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, color = Palette.Text, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            if (subtitle != null) Text(subtitle, color = Palette.TextSoft, fontSize = 13.sp)
        }
        trailing()
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, color = Palette.Text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = modifier)
}
