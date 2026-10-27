package com.hamsethob.app.ui

import android.app.TimePickerDialog
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hamsethob.app.bible.DownloadState
import com.hamsethob.app.bible.OfflineBible
import com.hamsethob.app.calendar.arabicDigits
import com.hamsethob.app.data.Services
import com.hamsethob.app.data.ThemeMode
import com.hamsethob.app.widget.DailyWorker
import com.hamsethob.app.widget.MorningWorker

/** المزيد: المفضلة والإعدادات وتحميل الكتاب المقدس. */
@Composable
fun MoreScreen(services: Services, onOpenFavorites: () -> Unit) {
    val context = LocalContext.current
    val settings = services.settings
    val download by OfflineBible.state.collectAsState()
    LaunchedEffect(Unit) { OfflineBible.refresh(context) }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = LocalBottomInset.current),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ScreenHeader("المزيد")

        Group {
            Item("♡  المفضلة", "${services.favorites.items.size.arabicDigits()} آية محفوظة", onClick = onOpenFavorites)
        }

        Group("المظهر") {
            Text("الوضع", color = Palette.TextSoft, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 18.dp))
            Spacer(Modifier.height(8.dp))
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 14.dp).clip(RoundedCornerShape(50)).background(Palette.Chip).padding(4.dp)
            ) {
                ThemeMode.entries.forEach { mode ->
                    val on = settings.themeMode == mode
                    Text(
                        mode.label,
                        color = Palette.Text,
                        fontWeight = if (on) FontWeight.Bold else FontWeight.Normal,
                        fontSize = 14.sp,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(50))
                            .background(if (on) Palette.Chip else Color.Transparent)
                            .clickable { settings.themeMode = mode }
                            .padding(vertical = 8.dp),
                    )
                }
            }
            Spacer(Modifier.height(6.dp))
            Toggle("ألوان المواسم الكنسية", "بنفسجي في الأصوام وذهبي في الأعياد", settings.seasonalColors) {
                settings.seasonalColors = it
            }
            Toggle("خط أميري للآيات", "يُحمَّل مرة واحدة (حوالي ٨٠٠ كيلوبايت)", settings.scriptureFont) {
                settings.scriptureFont = it
            }
        }

        Group("الإشعارات") {
            Toggle("رسالة الصباح", "إشعار يومي برسالة اليوم", settings.morningEnabled) {
                settings.morningEnabled = it
                MorningWorker.schedule(context)
            }
            if (settings.morningEnabled) {
                val h = settings.morningMinutes / 60
                val m = settings.morningMinutes % 60
                Item("وقت الإشعار", "${(if (h % 12 == 0) 12 else h % 12).arabicDigits()}:${m.toString().padStart(2, '0').map { '٠' + (it - '0') }.joinToString("")} ${if (h < 12) "صباحاً" else "مساءً"}") {
                    TimePickerDialog(context, { _, hour, minute ->
                        settings.morningMinutes = hour * 60 + minute
                        MorningWorker.schedule(context)
                    }, h, m, false).show()
                }
            }
            Toggle("شاشة القفل", "التاريخ القبطي ورسالة اليوم في إشعار هادئ", settings.lockNotification) {
                settings.lockNotification = it
                DailyWorker.refreshNow(context)
            }
        }

        Group("الكتاب المقدس بدون إنترنت") {
            when (val s = download) {
                DownloadState.Idle -> Item("تحميل الكتاب كاملاً", "حوالي ٢٫٤ ميجا • يتيح القراءة والبحث بدون إنترنت") {
                    OfflineBible.start(context)
                }
                is DownloadState.Running -> Column(Modifier.padding(horizontal = 18.dp, vertical = 10.dp)) {
                    Text("جارٍ التحميل… ${(s.progress * 100).toInt().arabicDigits()}٪", color = Palette.Text, fontSize = 15.sp)
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { s.progress },
                        modifier = Modifier.fillMaxWidth(),
                        color = Palette.Gold,
                        trackColor = Palette.Chip,
                    )
                }
                DownloadState.Done -> Item("الكتاب محمّل على الجهاز ✓", "اضغط لحذفه وتوفير المساحة") {
                    OfflineBible.delete(context)
                }
                is DownloadState.Failed -> Item("تعذّر التحميل", "${s.message} • اضغط لإعادة المحاولة") {
                    OfflineBible.start(context)
                }
            }
        }

        Text(
            "النصوص: ترجمة فاندايك (bolls.life) • القطمارس والسنكسار: katameros.app • الصور: ويكيبيديا",
            color = Palette.TextFaint,
            fontSize = 11.sp,
            lineHeight = 18.sp,
            modifier = Modifier.padding(horizontal = 8.dp),
        )
    }
}

@Composable
private fun Group(title: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column {
        if (title != null) {
            Text(title, color = Palette.Gold, fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 10.dp, bottom = 6.dp))
        }
        LiquidGlass(Modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), elevation = 10.dp) {
            Column(Modifier.padding(vertical = 8.dp), content = content)
        }
    }
}

@Composable
private fun Item(title: String, subtitle: String? = null, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 18.dp, vertical = 10.dp)) {
        Text(title, color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        if (subtitle != null) Text(subtitle, color = Palette.TextSoft, fontSize = 12.sp)
    }
}

@Composable
private fun Toggle(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(horizontal = 18.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = Palette.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = Palette.TextSoft, fontSize = 12.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Palette.Gold,
                uncheckedTrackColor = Palette.Chip,
            ),
        )
    }
}
