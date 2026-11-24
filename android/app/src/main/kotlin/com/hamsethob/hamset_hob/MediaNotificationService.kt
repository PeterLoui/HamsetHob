package com.hamsethob.hamset_hob

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel

/**
 * إشعار التحكم في الصوت (تشغيل/إيقاف وتقديم ورجوع) وجلسة وسائط لشاشة القفل وسماعات البلوتوث.
 * احتياطي: لو إشعار audio_service ماظهرش (حصل في بعض الأجهزة) التطبيق بيطلب من هنا يظهر إشعاره.
 * الأزرار بتتبعت لـ Flutter عن طريق القناة، والصوت نفسه بيفضل في مشغّل التطبيق.
 */
class MediaNotificationService : Service() {
    companion object {
        private const val CHANNEL = "playback_fallback"
        private const val ID = 4242
        private const val UPDATE = "com.hamsethob.hamset_hob.MEDIA_UPDATE"
        private const val TOGGLE = "com.hamsethob.hamset_hob.MEDIA_TOGGLE"
        private const val BACK = "com.hamsethob.hamset_hob.MEDIA_BACK"
        private const val FORWARD = "com.hamsethob.hamset_hob.MEDIA_FORWARD"
        private const val CLOSE = "com.hamsethob.hamset_hob.MEDIA_CLOSE"

        /** قناة Flutter الحالية (بتتحط من MainActivity)، عشان الأزرار توصل للتطبيق. */
        @Volatile
        var channel: MethodChannel? = null

        fun update(ctx: Context, title: String, subtitle: String, playing: Boolean, live: Boolean, positionMs: Long, durationMs: Long) {
            val i = Intent(ctx, MediaNotificationService::class.java).setAction(UPDATE)
                .putExtra("title", title).putExtra("subtitle", subtitle).putExtra("playing", playing)
                .putExtra("live", live).putExtra("pos", positionMs).putExtra("dur", durationMs)
            try {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (_: Exception) {
            }
        }

        fun hide(ctx: Context) {
            try {
                ctx.stopService(Intent(ctx, MediaNotificationService::class.java))
            } catch (_: Exception) {
            }
        }

        /** فيه إشعار تحكم (MediaStyle) ظاهر من التطبيق غير إشعارنا الاحتياطي؟ */
        fun hasOtherMediaNotification(ctx: Context): Boolean {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            return nm.activeNotifications.any {
                it.id != ID && it.notification.extras.getString(Notification.EXTRA_TEMPLATE)?.contains("MediaStyle") == true
            }
        }
    }

    private var session: MediaSession? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "التحكم في الصوت", NotificationManager.IMPORTANCE_LOW).apply {
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        })
        session = MediaSession(this, "hamset-fallback").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = send("toggle")
                override fun onPause() = send("toggle")
                override fun onFastForward() = send("fwd30")
                override fun onRewind() = send("back30")
                override fun onSkipToNext() = send("next")
                override fun onStop() = send("stop")
            })
            isActive = true
        }
    }

    private fun send(action: String) {
        try {
            channel?.invokeMethod("mediaAction", action)
        } catch (_: Exception) {
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            UPDATE -> render(intent)
            TOGGLE -> send("toggle")
            BACK -> send("back30")
            FORWARD -> send("fwd30")
            CLOSE -> {
                send("stop")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun action(icon: Int, label: String, what: String, req: Int): Notification.Action {
        val pi = PendingIntent.getService(
            this, req, Intent(this, MediaNotificationService::class.java).setAction(what),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(Icon.createWithResource("android", icon), label, pi).build()
    }

    private fun render(i: Intent) {
        val title = i.getStringExtra("title") ?: ""
        val subtitle = i.getStringExtra("subtitle") ?: ""
        val playing = i.getBooleanExtra("playing", false)
        val live = i.getBooleanExtra("live", false)
        val pos = i.getLongExtra("pos", 0)
        val dur = i.getLongExtra("dur", 0)
        val s = session ?: return

        s.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, if (live || dur <= 0) -1 else dur)
                .build(),
        )
        var actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP
        if (!live) actions = actions or PlaybackState.ACTION_REWIND or PlaybackState.ACTION_FAST_FORWARD
        s.setPlaybackState(
            PlaybackState.Builder().setActions(actions)
                .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, if (live) PlaybackState.PLAYBACK_POSITION_UNKNOWN else pos, 1f)
                .build(),
        )

        val open = PendingIntent.getActivity(
            this, 43, Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(playing)
            .setContentIntent(open)
        val compact = mutableListOf<Int>()
        var n = 0
        if (!live) {
            b.addAction(action(android.R.drawable.ic_media_rew, "رجوع ٣٠ ثانية", BACK, 1))
            n++
        }
        compact += n
        b.addAction(action(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play, if (playing) "إيقاف مؤقت" else "تشغيل", TOGGLE, 2))
        n++
        if (!live) {
            b.addAction(action(android.R.drawable.ic_media_ff, "تقديم ٣٠ ثانية", FORWARD, 3))
            compact += n
            n++
        }
        b.setStyle(Notification.MediaStyle().setMediaSession(s.sessionToken).setShowActionsInCompactView(*compact.toIntArray()))
        val notification = b.build()
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(ID, notification)
            // وهو موقّف مؤقتاً: الإشعار يفضل ويتشال بالسحب
            if (!playing) stopForeground(STOP_FOREGROUND_DETACH)
        } catch (_: Exception) {
            getSystemService(NotificationManager::class.java).notify(ID, notification)
        }
    }

    override fun onDestroy() {
        session?.release()
        session = null
        super.onDestroy()
    }
}
