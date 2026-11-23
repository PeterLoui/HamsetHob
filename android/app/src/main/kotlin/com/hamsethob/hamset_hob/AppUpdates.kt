package com.hamsethob.hamset_hob

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import org.json.JSONArray
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * التحديث من إصدارات GitHub.
 *
 * - الفحص والإشعار: بنفحص كل ١٢ ساعة (من المنبّه اللي بيشتغل كل ٣ ساعات أصلاً)، ولو فيه نسخة أحدث من المركّبة
 *   بنعمل إشعار واحد لكل نسخة. الإعدادات (شغّال ولا لأ، وهل النسخ التجريبية) بتجي من التطبيق.
 * - التركيب: التطبيق بينزّل الـ APK، وهنا بنسلّمه لـ PackageInstaller. أندرويد بيطلب موافقة المستخدم،
 *   وبيرفض أي نسخة مش متوقّعة بنفس مفتاح التوقيع، فمفيش تركيب لنسخة غريبة.
 */
object AppUpdates {
    private const val PREFS = "hamset_update"
    private const val REPO = "PeterLoui/HamsetHob"
    private const val CHANNEL = "updates"
    private const val NOTIFICATION_ID = 30
    private const val CHECK_EVERY_MS = 12L * 60 * 60 * 1000
    const val EXTRA_UPDATE = "open_update"
    const val INSTALL_ACTION = "com.hamsethob.hamset_hob.INSTALL_RESULT"

    private val TAG = Regex("""^v?\d+(?:\.\d+)*\.(\d+)$""")

    /** رقم بناء النسخة المركّبة (versionCode)، وهو رقم التشغيل في GitHub. */
    fun installedBuild(ctx: Context): Long {
        val info = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
    }

    fun setOptions(ctx: Context, enabled: Boolean, beta: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", enabled).putBoolean("beta", beta).apply()
    }

    // ─── الفحص والإشعار ───

    /** من خيط خلفي. مرة كل ١٢ ساعة، وإشعار واحد لكل نسخة. */
    fun maybeNotify(ctx: Context) {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!p.getBoolean("enabled", true)) return
        val now = System.currentTimeMillis()
        if (now - p.getLong("last_check", 0) < CHECK_EVERY_MS) return
        p.edit().putLong("last_check", now).apply()

        val releases = try { fetchReleases() } catch (_: Exception) { return }
        val beta = p.getBoolean("beta", true)
        var best = 0L
        var bestName = ""
        for (i in 0 until releases.length()) {
            val r = releases.optJSONObject(i) ?: continue
            if (r.optBoolean("draft") || (r.optBoolean("prerelease") && !beta)) continue
            val tag = r.optString("tag_name")
            val build = TAG.find(tag)?.groupValues?.get(1)?.toLongOrNull() ?: continue
            if (build > best) {
                best = build
                bestName = tag.removePrefix("v")
            }
        }
        if (best <= installedBuild(ctx) || p.getLong("notified", 0) >= best) return
        p.edit().putLong("notified", best).apply()
        notifyAvailable(ctx, bestName)
    }

    private fun fetchReleases(): JSONArray {
        val conn = URL("https://api.github.com/repos/$REPO/releases?per_page=15").openConnection() as HttpURLConnection
        conn.connectTimeout = 5_000
        conn.readTimeout = 8_000
        conn.setRequestProperty("Accept", "application/vnd.github+json")
        conn.setRequestProperty("User-Agent", "HamsetHob-Android")
        return try {
            JSONArray(conn.inputStream.bufferedReader().use { it.readText() })
        } finally {
            conn.disconnect()
        }
    }

    private fun notifyAvailable(ctx: Context, version: String) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "تحديثات التطبيق", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(
            ctx, 31,
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_UPDATE, true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_cross)
            .setContentTitle("نسخة جديدة من همسة حب")
            .setContentText("النسخة $version متاحة، اضغط للتحديث")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, n)
        } catch (_: SecurityException) {
        }
    }

    // ─── التركيب ───

    /** "started" (ظهرت شاشة موافقة النظام)، "needs_permission" (فتحنا إعداد «تثبيت من هذا المصدر»)، أو "error:سبب". */
    fun install(activity: Activity, path: String): String {
        val ctx = activity.applicationContext
        if (!ctx.packageManager.canRequestPackageInstalls()) {
            try {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${ctx.packageName}")))
            } catch (_: Exception) {
            }
            return "needs_permission"
        }
        return try {
            val file = File(path)
            val installer = ctx.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            params.setAppPackageName(ctx.packageName)
            if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            val id = installer.createSession(params)
            installer.openSession(id).use { session ->
                file.inputStream().use { input ->
                    session.openWrite("hamset.apk", 0, file.length()).use { out ->
                        input.copyTo(out)
                        session.fsync(out)
                    }
                }
                // لازم يكون قابل للتعديل: النظام بيحط فيه حالة التركيب
                val result = PendingIntent.getBroadcast(
                    ctx, id,
                    Intent(ctx, InstallReceiver::class.java).setAction(INSTALL_ACTION),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                )
                session.commit(result.intentSender)
            }
            "started"
        } catch (e: Exception) {
            "error:${e.message ?: e.javaClass.simpleName}"
        }
    }
}

/** نتيجة التركيب: شاشة الموافقة بتتفتح من هنا، والفشل بيظهر برسالة. */
class InstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                }
                try {
                    confirm?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                } catch (_: Exception) {
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {}
            else -> Toast.makeText(
                context,
                "تعذّر تركيب التحديث: ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""}",
                Toast.LENGTH_LONG,
            ).show()
        }
    }
}
