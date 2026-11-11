package com.hamsethob.hamset_hob

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import io.flutter.plugin.common.EventChannel
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * مستويات الصوت اللي المشغّل بيطلعه، عشان الخط المتوهج يتحرك معاه.
 * Visualizer بيقرا خرج جلسة الصوت بتاعة المشغّل بس (مش الميكروفون)، لكن أندرويد بيشترط إذن RECORD_AUDIO.
 * بيبعت ١٦ نطاق تردد من الغليظ للرفيع، كل واحد من ٠ لـ ١، حوالي ٢٠ مرة في الثانية.
 */
object SoundLevels : EventChannel.StreamHandler {
    private const val BANDS = 16
    private const val LOW_HZ = 90.0
    private const val HIGH_HZ = 8000.0

    private var sink: EventChannel.EventSink? = null
    private var visualizer: Visualizer? = null
    private var session = -1

    /** جلسة مستنية رد المستخدم على طلب الإذن. */
    var pending = -1

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun allowed(ctx: Context) =
        ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    fun start(ctx: Context, id: Int): Boolean {
        if (!allowed(ctx)) return false
        if (visualizer != null && session == id) return true
        stop()
        return try {
            visualizer = Visualizer(id).apply {
                enabled = false
                val range = Visualizer.getCaptureSizeRange()
                captureSize = 512.coerceIn(range[0], range[1])
                // بالمستوى الفعلي: التطبيع كان بيخلّي كل لحظة «عالية» فالإيقاع يضيع
                scalingMode = Visualizer.SCALING_MODE_AS_PLAYED
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(v: Visualizer, waveform: ByteArray, samplingRate: Int) {}
                    override fun onFftDataCapture(v: Visualizer, fft: ByteArray, samplingRate: Int) {
                        sink?.success(bands(fft, samplingRate / 1000.0))
                    }
                }, min(Visualizer.getMaxCaptureRate(), 20000), false, true)
                enabled = true
            }
            session = id
            true
        } catch (_: Throwable) {
            stop()
            false
        }
    }

    fun stop() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Throwable) {
        }
        visualizer = null
        session = -1
    }

    /** fft: الجزء الحقيقي والتخيلي لكل تردد بالتوالي (بايت بإشارة). */
    private fun bands(fft: ByteArray, sampleRate: Double): DoubleArray {
        val bins = fft.size / 2
        val binHz = sampleRate / fft.size
        val out = DoubleArray(BANDS)
        val ratio = HIGH_HZ / LOW_HZ
        var from = max(1, (LOW_HZ / binHz).toInt())
        for (b in 0 until BANDS) {
            val edge = LOW_HZ * ratio.pow((b + 1.0) / BANDS)
            val to = (edge / binHz).toInt().coerceIn(from + 1, max(from + 1, bins))
            var top = 0.0
            for (k in from until min(to, bins)) {
                top = max(top, hypot(fft[2 * k].toDouble(), fft[2 * k + 1].toDouble()))
            }
            out[b] = min(1.0, ln(1 + top) / ln(182.0))
            from = to
        }
        return out
    }
}
