package com.hamsethob.app

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.hamsethob.app.bible.VerseRef
import com.hamsethob.app.calendar.Season
import com.hamsethob.app.calendar.seasonOf
import com.hamsethob.app.data.ScriptureFont
import com.hamsethob.app.data.Services
import com.hamsethob.app.data.ThemeMode
import com.hamsethob.app.radio.RadioPlayer
import com.hamsethob.app.ui.BibleScreen
import com.hamsethob.app.ui.BottomBar
import com.hamsethob.app.ui.CalendarScreen
import com.hamsethob.app.ui.ChapterScreen
import com.hamsethob.app.ui.FavoritesScreen
import com.hamsethob.app.ui.HomeScreen
import com.hamsethob.app.ui.LocalAppColors
import com.hamsethob.app.ui.LocalBottomInset
import com.hamsethob.app.ui.LocalScriptureFont
import com.hamsethob.app.ui.MiniPlayer
import com.hamsethob.app.ui.MoreScreen
import com.hamsethob.app.ui.RadioScreen
import com.hamsethob.app.ui.ReadingsScreen
import com.hamsethob.app.ui.SynaxariumScreen
import com.hamsethob.app.ui.Tab
import com.hamsethob.app.ui.Wallpaper
import com.hamsethob.app.ui.appColors
import com.hamsethob.app.widget.DailyWorker
import com.hamsethob.app.widget.MorningWorker
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime

/** شاشات فرعية تُفتح فوق التبويبات. */
private sealed interface Overlay {
    data class Chapter(val ref: VerseRef) : Overlay
    data class Synaxarium(val date: LocalDate) : Overlay
    data object Favorites : Overlay
    data object Radio : Overlay
}

class MainActivity : ComponentActivity() {

    private var pendingRef by mutableStateOf<VerseRef?>(null)
    private var pendingRadio by mutableStateOf(false)
    private lateinit var radio: RadioPlayer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        pendingRef = refFrom(intent)
        pendingRadio = intent?.getBooleanExtra(EXTRA_OPEN_RADIO, false) == true
        radio = RadioPlayer(applicationContext)

        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        DailyWorker.schedule(this)
        MorningWorker.schedule(this)

        val services = Services(this)

        setContent {
            val settings = services.settings
            var today by remember { mutableStateOf(LocalDate.now()) }
            val dark = when (settings.themeMode) {
                ThemeMode.SYSTEM -> isSystemInDarkTheme()
                ThemeMode.LIGHT -> false
                ThemeMode.DARK -> true
            }
            val season = remember(today, settings.seasonalColors) {
                if (settings.seasonalColors) seasonOf(today) else Season.ORDINARY
            }
            val colors = remember(dark, season) { appColors(dark, season) }

            var fontReady by remember { mutableStateOf(ScriptureFont.isReady(this)) }
            LaunchedEffect(settings.scriptureFont) {
                if (settings.scriptureFont && !fontReady) fontReady = ScriptureFont.ensure(this@MainActivity)
            }
            val scriptureFont = remember(fontReady, settings.scriptureFont) {
                if (settings.scriptureFont) ScriptureFont.family(this) ?: FontFamily.Default else FontFamily.Default
            }

            LaunchedEffect(dark) {
                val bars = if (dark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
                else SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
                enableEdgeToEdge(bars, bars)
            }

            // تحديث التاريخ تلقائياً عند منتصف الليل
            LaunchedEffect(Unit) {
                while (true) {
                    val now = LocalDateTime.now()
                    delay(Duration.between(now, now.toLocalDate().plusDays(1).atStartOfDay()).toMillis() + 1_000)
                    today = LocalDate.now()
                }
            }

            MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
                CompositionLocalProvider(
                    LocalLayoutDirection provides LayoutDirection.Rtl,
                    LocalAppColors provides colors,
                    LocalScriptureFont provides scriptureFont,
                    LocalBottomInset provides if (radio.nowPlaying != null) 180.dp else 110.dp,
                ) {
                    var tab by rememberSaveable { mutableStateOf(Tab.HOME) }
                    val overlays = remember { mutableStateListOf<Overlay>() }
                    fun open(o: Overlay) = overlays.add(o)
                    fun back() { overlays.removeAt(overlays.lastIndex) }

                    LaunchedEffect(pendingRef) {
                        pendingRef?.let { open(Overlay.Chapter(it)); pendingRef = null }
                    }
                    LaunchedEffect(pendingRadio) {
                        if (pendingRadio) { if (overlays.lastOrNull() != Overlay.Radio) open(Overlay.Radio); pendingRadio = false }
                    }
                    BackHandler(enabled = overlays.isNotEmpty() || tab != Tab.HOME) {
                        if (overlays.isNotEmpty()) back() else tab = Tab.HOME
                    }

                    Box(Modifier.fillMaxSize()) {
                        Wallpaper()
                        when (val top = overlays.lastOrNull()) {
                            is Overlay.Chapter -> ChapterScreen(top.ref, services.bible, ::back)
                            is Overlay.Synaxarium -> SynaxariumScreen(top.date, services.katameros, ::back)
                            Overlay.Favorites -> FavoritesScreen(services.favorites, { open(Overlay.Chapter(it)) }, ::back)
                            Overlay.Radio -> RadioScreen(radio, ::back)
                            null -> {
                                when (tab) {
                                    Tab.HOME -> HomeScreen(
                                        today = today,
                                        services = services,
                                        onOpenChapter = { open(Overlay.Chapter(it)) },
                                        onOpenSynaxarium = { open(Overlay.Synaxarium(today)) },
                                        onOpenReadings = { tab = Tab.READINGS },
                                        onOpenFavorites = { open(Overlay.Favorites) },
                                        onOpenRadio = { open(Overlay.Radio) },
                                        onVerseChanged = { DailyWorker.refreshNow(applicationContext) },
                                        radio = radio,
                                    )
                                    Tab.BIBLE -> BibleScreen(services.bible) { open(Overlay.Chapter(it)) }
                                    Tab.READINGS -> ReadingsScreen(today, services.katameros) { open(Overlay.Synaxarium(it)) }
                                    Tab.CALENDAR -> CalendarScreen(today)
                                    Tab.MORE -> MoreScreen(services) { open(Overlay.Favorites) }
                                }
                                Column(
                                    Modifier
                                        .align(Alignment.BottomCenter)
                                        .navigationBarsPadding()
                                        .padding(16.dp),
                                ) {
                                    MiniPlayer(radio, { open(Overlay.Radio) }, Modifier.padding(bottom = 10.dp))
                                    BottomBar(selected = tab, onSelect = { tab = it })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        radio.connect()
    }

    override fun onStop() {
        radio.release()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        refFrom(intent)?.let { pendingRef = it }
        if (intent.getBooleanExtra(EXTRA_OPEN_RADIO, false)) pendingRadio = true
    }

    private fun refFrom(intent: Intent?): VerseRef? {
        val book = intent?.getIntExtra(EXTRA_BOOK, 0) ?: 0
        if (book == 0) return null
        return VerseRef(book, intent!!.getIntExtra(EXTRA_CHAPTER, 1), intent.getIntExtra(EXTRA_VERSE, 1))
    }

    companion object {
        const val EXTRA_BOOK = "book"
        const val EXTRA_CHAPTER = "chapter"
        const val EXTRA_VERSE = "verse"
        const val EXTRA_OPEN_RADIO = "open_radio"
    }
}
