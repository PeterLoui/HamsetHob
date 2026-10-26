package com.hamsethob.app.radio

import android.content.ComponentName
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken

data class NowPlaying(val id: String, val title: String, val category: String)

/**
 * واجهة التحكم في خدمة التشغيل من الشاشات. الحالة هنا حالة Compose
 * فتتحدث الواجهة تلقائياً.
 */
class RadioPlayer(private val context: Context) {

    val repository = SermonRepository(context.applicationContext)

    var nowPlaying by mutableStateOf<NowPlaying?>(null); private set
    var isPlaying by mutableStateOf(false); private set
    var isBuffering by mutableStateOf(false); private set
    var loadingId by mutableStateOf<Int?>(null); private set
    var error by mutableStateOf<String?>(null)
    var position by mutableLongStateOf(0L); private set
    var duration by mutableLongStateOf(0L); private set
    var radioOn by mutableStateOf(RadioMode.enabled); private set
    var hasNext by mutableStateOf(false); private set

    private var controller: MediaController? = null

    private val listener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) = sync(player)
    }

    fun connect() {
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener({
            controller = runCatching { future.get() }.getOrNull()?.also {
                it.addListener(listener)
                sync(it)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun release() {
        controller?.removeListener(listener)
        controller?.release()
        controller = null
    }

    /** يُستدعى دورياً أثناء التشغيل لتحديث شريط التقدم. */
    fun tick() {
        controller?.let {
            position = it.currentPosition.coerceAtLeast(0)
            duration = it.duration.takeIf { d -> d > 0 } ?: 0
        }
    }

    suspend fun play(sermon: Sermon) {
        RadioMode.enabled = false
        radioOn = false
        start(sermon)
    }

    /** البث المتواصل: عظات عشوائية متتالية من القسم المختار. */
    suspend fun startRadio(category: Int = 0) {
        RadioMode.enabled = true
        RadioMode.category = category
        radioOn = true
        error = null
        val sermon = runCatching { repository.random(category) }
            .onFailure { error = "تعذّر الاتصال بمكتبة العظات" }
            .getOrNull() ?: return
        start(sermon)
    }

    fun stopRadio() {
        RadioMode.enabled = false
        radioOn = false
    }

    private suspend fun start(sermon: Sermon) {
        loadingId = sermon.id
        error = null
        runCatching { repository.audioUrl(sermon) }
            .onSuccess { url ->
                controller?.run {
                    setMediaItem(sermon.toMediaItem(url))
                    prepare()
                    play()
                } ?: run { error = "مشغّل الصوت غير جاهز، حاول مرة أخرى" }
            }
            .onFailure { error = it.message ?: "تعذّر تشغيل العظة" }
        loadingId = null
    }

    fun toggle() {
        controller?.run { if (isPlaying) pause() else play() }
    }

    fun seekBack() = controller?.seekBack()
    fun seekForward() = controller?.seekForward()
    fun seekTo(ms: Long) = controller?.seekTo(ms)

    fun next() {
        controller?.run {
            if (hasNextMediaItem()) seekToNextMediaItem()
        }
    }

    private fun sync(player: Player) {
        isPlaying = player.isPlaying
        isBuffering = player.playbackState == Player.STATE_BUFFERING
        nowPlaying = player.currentMediaItem?.toNowPlaying()
        hasNext = player.hasNextMediaItem()
        tick()
    }

    private fun MediaItem.toNowPlaying() = NowPlaying(
        mediaId,
        mediaMetadata.title?.toString().orEmpty(),
        mediaMetadata.albumTitle?.toString().orEmpty(),
    )
}
