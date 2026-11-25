package com.hamsethob.hamset_hob

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.min

/**
 * مستويات الصوت الشغال (باص/وسط/حاد) للضوء اللي بيتحرك مع الإيقاع.
 * بيقرا الـ FFT من جلسة صوت المشغّل بـ Visualizer. أندرويد بيطلب إذن الميكروفون للـ Visualizer
 * حتى لو مابيسجّلش حاجة، فده بيشتغل بس لو المستخدم فعّل «تزامن الضوء مع الإيقاع» ووافق على الإذن.
 */
class AudioLevels(private val ctx: Context) : EventChannel.StreamHandler {
    private var viz: Visualizer? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    fun hasPermission() = ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    /** يبدأ القراءة من جلسة الصوت [session]. بيرجع false لو مافيش إذن أو الجلسة مش متاحة. */
    fun start(session: Int): Boolean {
        stop()
        if (session <= 0 || !hasPermission()) return false
        return try {
            val v = Visualizer(session)
            val range = Visualizer.getCaptureSizeRange()
            v.captureSize = min(512, range[1]).coerceAtLeast(range[0])
            v.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray?, rate: Int) {}

                override fun onFftDataCapture(v: Visualizer?, fft: ByteArray?, rate: Int) {
                    if (fft == null) return
                    val levels = bands(fft, v?.samplingRate ?: 44100000)
                    main.post { sink?.success(levels) }
                }
            }, min(Visualizer.getMaxCaptureRate(), 20000), false, true)
            v.enabled = true
            viz = v
            true
        } catch (_: Exception) {
            stop()
            false
        }
    }

    fun stop() {
        try {
            viz?.enabled = false
            viz?.release()
        } catch (_: Exception) {
        }
        viz = null
    }

    /** باص (لحد ٢٥٠ هرتز)، وسط (لحد ٢ كيلو)، حاد (لحد ٧ كيلو)، كل واحد من ٠ لـ ١. */
    private fun bands(fft: ByteArray, samplingRateMilliHz: Int): List<Double> {
        val n = fft.size / 2
        val hzPerBin = samplingRateMilliHz / 1000.0 / 2 / n
        fun energy(fromHz: Double, toHz: Double): Double {
            val a = (fromHz / hzPerBin).toInt().coerceIn(1, n - 1)
            val b = (toHz / hzPerBin).toInt().coerceIn(a + 1, n)
            var sum = 0.0
            for (k in a until b) sum += hypot(fft[2 * k].toDouble(), fft[2 * k + 1].toDouble())
            val avg = sum / (b - a)
            return (ln(1 + avg) / ln(1 + 64.0)).coerceIn(0.0, 1.0)
        }
        return listOf(energy(30.0, 250.0), energy(250.0, 2000.0), energy(2000.0, 7000.0))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
