package com.hamsethob.app.radio

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.hamsethob.app.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** حالة البث المتواصل: عند انتهاء العظة تُضاف عظة عشوائية تلقائياً. */
object RadioMode {
    @Volatile var enabled = false
    @Volatile var category = 0
}

fun Sermon.toMediaItem(audio: String): MediaItem = MediaItem.Builder()
    .setMediaId(id.toString())
    .setUri(audio)
    .setMediaMetadata(
        MediaMetadata.Builder()
            .setTitle(title)
            .setArtist("قداسة البابا شنوده الثالث")
            .setAlbumTitle(categoryName(categoryId))
            .setArtworkUri(Uri.parse(SermonRepository.ARTWORK))
            .setExtras(Bundle().apply { putString("link", link) })
            .build()
    )
    .build()

/** خدمة تشغيل في الخلفية مع أزرار التحكم في الإشعار وشاشة القفل. */
class PlaybackService : MediaSessionService() {

    private var session: MediaSession? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var fetching = false
    private val repo by lazy { SermonRepository(this) }

    override fun onCreate() {
        super.onCreate()
        val player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true) // إيقاف عند فصل السماعة
            .setSeekBackIncrementMs(30_000)
            .setSeekForwardIncrementMs(30_000)
            .build()

        player.addListener(object : Player.Listener {
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) = queueNextIfRadio(player)
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) queueNextIfRadio(player)
            }
        })

        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).putExtra(MainActivity.EXTRA_OPEN_RADIO, true),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        session = MediaSession.Builder(this, player).setSessionActivity(open).build()
    }

    /** في وضع البث نجهّز العظة التالية مسبقاً ليكون الانتقال متصلاً. */
    private fun queueNextIfRadio(player: Player) {
        if (!RadioMode.enabled || fetching || player.hasNextMediaItem()) return
        fetching = true
        scope.launch {
            runCatching {
                val sermon = repo.random(RadioMode.category)
                player.addMediaItem(sermon.toMediaItem(repo.audioUrl(sermon)))
            }
            fetching = false
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = session?.player
        if (player == null || !player.playWhenReady || player.mediaItemCount == 0) stopSelf()
    }

    override fun onDestroy() {
        scope.cancel()
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }
}
