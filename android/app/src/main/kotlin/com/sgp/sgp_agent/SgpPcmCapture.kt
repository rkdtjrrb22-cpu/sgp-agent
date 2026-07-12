package com.sgp.sgp_agent

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import kotlin.math.sqrt

/**
 * 무전/마이크 PCM 캡처 — Whisper JNI·레벨 검증용.
 */
object SgpPcmCapture {
    const val SAMPLE_RATE = 16_000

    fun capture(
        context: Context,
        timeoutMs: Int,
        radioManager: SgpRadioAudioManager,
    ): CaptureResult {
        radioManager.activateRadioAudioRoute()

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            return CaptureResult.failure("AudioRecord buffer size invalid")
        }

        val recorder = buildRecorder(context, minBuffer * 2)
        try {
            recorder.startRecording()
            if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                return CaptureResult.failure("AudioRecord failed to start")
            }

            val totalSamples = (SAMPLE_RATE * timeoutMs) / 1000
            val pcmShort = ShortArray(totalSamples)
            var read = 0
            val deadline = System.currentTimeMillis() + timeoutMs.toLong()

            while (read < totalSamples && System.currentTimeMillis() < deadline) {
                val chunk = recorder.read(
                    pcmShort,
                    read,
                    minOf(4096, totalSamples - read),
                )
                if (chunk > 0) read += chunk
            }

            recorder.stop()
            if (read <= 0) {
                return CaptureResult.failure("No PCM samples captured")
            }

            val floats = FloatArray(read) { i -> pcmShort[i] / 32768.0f }
            var sum = 0.0
            for (sample in floats) sum += sample * sample
            val rms = sqrt(sum / floats.size)
            return CaptureResult.success(floats, rms.toFloat())
        } catch (error: SecurityException) {
            return CaptureResult.failure("RECORD_AUDIO permission required")
        } catch (error: Exception) {
            return CaptureResult.failure(error.message ?: "PCM capture failed")
        } finally {
            recorder.release()
            radioManager.stopRadioAudioRoute()
        }
    }

    private fun buildRecorder(context: Context, bufferSize: Int): AudioRecord {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val builder = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(bufferSize)
            return builder.build()
        }
        @Suppress("DEPRECATION")
        return AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
        )
    }
}

data class CaptureResult(
    val success: Boolean,
    val pcm: FloatArray,
    val rmsLevel: Float,
    val error: String?,
) {
    companion object {
        fun success(pcm: FloatArray, rmsLevel: Float) =
            CaptureResult(true, pcm, rmsLevel, null)

        fun failure(message: String) =
            CaptureResult(false, FloatArray(0), 0f, message)
    }
}
