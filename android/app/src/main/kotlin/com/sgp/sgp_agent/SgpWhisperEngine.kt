package com.sgp.sgp_agent

import android.content.Context
import java.io.File

/**
 * whisper.cpp JNI 브리지.
 *
 * GGML 모델을 [filesDir]/whisper/ 아래에 배치하고 whisper.cpp를 링크한 빌드에서
 * [nativeTranscribePcm]이 실제 전사를 수행한다. 기본 빌드는 PCM 캡처·계약 검증만 한다.
 */
object SgpWhisperEngine {
    const val MODEL_FILE_NAME = "ggml-base.bin"

    var nativeLibraryLoaded: Boolean = false
        private set

    init {
        try {
            System.loadLibrary("sgp_whisper_jni")
            nativeLibraryLoaded = true
        } catch (_: UnsatisfiedLinkError) {
            nativeLibraryLoaded = false
        }
    }

    fun modelFile(context: Context): File =
        File(File(context.filesDir, "whisper"), MODEL_FILE_NAME)

    fun hasModelFile(context: Context): Boolean = modelFile(context).exists()

    fun isReady(context: Context): Boolean =
        nativeLibraryLoaded && hasModelFile(context)

    fun transcribe(
        context: Context,
        pcm: FloatArray,
        sampleRate: Int,
        locale: String,
    ): WhisperTranscription {
        if (!nativeLibraryLoaded) {
            return WhisperTranscription(
                available = false,
                text = null,
                error = "sgp_whisper_jni library not loaded",
            )
        }
        if (!hasModelFile(context)) {
            return WhisperTranscription(
                available = false,
                text = null,
                error = "Whisper model missing at ${modelFile(context).absolutePath}",
            )
        }
        val text = nativeTranscribePcm(
            modelFile(context).absolutePath,
            pcm,
            sampleRate,
            locale,
        )
        return if (text.isNullOrBlank()) {
            WhisperTranscription(
                available = false,
                text = null,
                error = "Whisper returned empty transcript (link whisper.cpp for inference)",
            )
        } else {
            WhisperTranscription(available = true, text = text.trim(), error = null)
        }
    }

    private external fun nativeTranscribePcm(
        modelPath: String,
        pcm: FloatArray,
        sampleRate: Int,
        locale: String,
    ): String?
}

data class WhisperTranscription(
    val available: Boolean,
    val text: String?,
    val error: String?,
)
