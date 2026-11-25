package com.hamsethob.hamset_hob

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaDescription
import android.media.MediaMetadata
import android.media.MediaPlayer
import android.media.browse.MediaBrowser
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.service.media.MediaBrowserService
import org.json.JSONArray
import org.json.JSONObject

/**
 * أندرويد أوتو (وأي واجهة سيارة أو ساعة): قايمة محطات الإذاعة بتتصفّح وتتشغّل من شاشة العربية.
 * الصوت بيشتغل هنا من غير ما التطبيق نفسه يكون مفتوح. قايمة المحطات بيحدّثها التطبيق (saveStations)
 * كل مرة يفتح، وبتتحفظ في SharedPreferences.
 */
class AutoService : MediaBrowserService() {
    companion object {
        private const val PREFS = "hamset_auto"
        private const val CHANNEL = "auto_playback"
        private const val ID = 4343

        fun saveStations(ctx: Context, list: List<Map<*, *>>) {
            val arr = JSONArray()
            for (m in list) arr.put(JSONObject().put("id", m["id"]).put("name", m["name"]).put("url", m["url"]))
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("stations", arr.toString()).apply()
        }
    }

    private class Station(val id: String, val name: String, val url: String)

    private var session: MediaSession? = null
    private var player: MediaPlayer? = null
    private var stations = listOf<Station>()
    private var index = -1
    private var focus: AudioFocusRequest? = null
    private var state = PlaybackState.STATE_STOPPED
    private var error: String? = null

    override fun onCreate() {
        super.onCreate()
        loadStations()
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, "التشغيل في السيارة", NotificationManager.IMPORTANCE_LOW))
        session = MediaSession(this, "hamset-auto").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
                    stations.indexOfFirst { it.id == mediaId }.takeIf { it >= 0 }?.let { play(it) }
                }
                override fun onPlay() {
                    val p = player
                    if (p != null && index >= 0 && state == PlaybackState.STATE_PAUSED) {
                        if (requestFocus()) { p.start(); publish(PlaybackState.STATE_PLAYING) }
                    } else play(if (index >= 0) index else 0)
                }
                override fun onPause() { player?.takeIf { it.isPlaying }?.pause(); publish(PlaybackState.STATE_PAUSED) }
                override fun onStop() { stopAll() }
                override fun onSkipToNext() { if (stations.isNotEmpty()) play((index + 1).mod(stations.size)) }
                override fun onSkipToPrevious() { if (stations.isNotEmpty()) play((index - 1).mod(stations.size)) }
            })
            isActive = true
        }
        sessionToken = session!!.sessionToken
        publish(PlaybackState.STATE_STOPPED)
    }

    private fun loadStations() {
        val raw = getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("stations", null) ?: return
        try {
            val arr = JSONArray(raw)
            stations = (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Station(o.getString("id"), o.getString("name"), o.getString("url"))
            }
        } catch (_: Exception) {
        }
    }

    override fun onGetRoot(clientPackageName: String, clientUid: Int, rootHints: Bundle?): BrowserRoot = BrowserRoot("root", null)

    override fun onLoadChildren(parentId: String, result: Result<MutableList<MediaBrowser.MediaItem>>) {
        loadStations()
        val items = if (parentId == "root") stations.map {
            MediaBrowser.MediaItem(
                MediaDescription.Builder().setMediaId(it.id).setTitle(it.name).setSubtitle("إذاعة مباشرة").build(),
                MediaBrowser.MediaItem.FLAG_PLAYABLE,
            )
        } else emptyList()
        result.sendResult(items.toMutableList())
    }

    private fun requestFocus(): Boolean {
        val am = getSystemService(AudioManager::class.java)
        val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setOnAudioFocusChangeListener { change ->
                when (change) {
                    AudioManager.AUDIOFOCUS_LOSS -> session?.controller?.transportControls?.pause()
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> player?.takeIf { it.isPlaying }?.pause()
                    AudioManager.AUDIOFOCUS_GAIN -> if (state == PlaybackState.STATE_PLAYING) player?.start()
                }
            }.build()
        focus = req
        return am.requestAudioFocus(req) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun play(i: Int) {
        val st = stations.getOrNull(i) ?: return
        index = i
        error = null
        player?.release()
        player = null
        if (!requestFocus()) {
            error = "الصوت مشغول بتطبيق تاني"
            publish(PlaybackState.STATE_ERROR)
            return
        }
        publish(PlaybackState.STATE_BUFFERING)
        try {
            startService(Intent(this, AutoService::class.java))
        } catch (_: Exception) {
        }
        PlaybackLocks.set(this, true)
        val mp = MediaPlayer()
        player = mp
        try {
            mp.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            mp.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setDataSource(st.url)
            mp.setOnPreparedListener { if (player === it) { it.start(); publish(PlaybackState.STATE_PLAYING) } }
            mp.setOnErrorListener { m, _, _ ->
                if (player === m) { error = "تعذّر تشغيل المحطة"; publish(PlaybackState.STATE_ERROR) }
                true
            }
            mp.setOnCompletionListener { if (player === it) publish(PlaybackState.STATE_STOPPED) }
            mp.prepareAsync()
        } catch (_: Exception) {
            error = "تعذّر تشغيل المحطة"
            publish(PlaybackState.STATE_ERROR)
        }
    }

    private fun stopAll() {
        player?.release()
        player = null
        focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
        PlaybackLocks.set(this, false)
        publish(PlaybackState.STATE_STOPPED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun publish(s: Int) {
        state = s
        val st = stations.getOrNull(index)
        val ms = session ?: return
        ms.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, st?.name ?: "همسة حب")
                .putString(MediaMetadata.METADATA_KEY_ARTIST, "إذاعة مباشرة")
                .build(),
        )
        val actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_PLAY_FROM_MEDIA_ID
        val b = PlaybackState.Builder().setActions(actions).setState(s, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f)
        error?.takeIf { s == PlaybackState.STATE_ERROR }?.let { b.setErrorMessage(it) }
        ms.setPlaybackState(b.build())
        if (s == PlaybackState.STATE_PLAYING || s == PlaybackState.STATE_BUFFERING) foreground(st?.name ?: "همسة حب")
        if (s == PlaybackState.STATE_PAUSED) PlaybackLocks.set(this, false)
    }

    private fun foreground(title: String) {
        try {
            val n = Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_cross)
                .setContentTitle(title)
                .setContentText("تشغيل في السيارة")
                .setStyle(Notification.MediaStyle().setMediaSession(session?.sessionToken))
                .setOngoing(true)
                .build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) else startForeground(ID, n)
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        PlaybackLocks.set(this, false)
        session?.release()
        super.onDestroy()
    }
}
