package com.sgp.sgp_agent

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 온디바이스 AI 네이티브 브리지.
 * - STT: 무전 PCM 캡처 + Whisper JNI + SpeechRecognizer 폴백
 * - sLLM: llama.cpp / GGUF mmap 슬롯 (현재 Dart 폴백)
 */
class SgpNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var audioEventChannel: EventChannel
    private lateinit var appContext: Context
    private lateinit var radioAudioManager: SgpRadioAudioManager

    private var sllmLoaded = false

    companion object {
        private const val METHOD_CHANNEL = "com.sgp.sgp_agent/native"
        private const val AUDIO_EVENT_CHANNEL = "com.sgp.sgp_agent/audio_events"
        private const val CACHE_KEY_ALIAS = "sgp_agent_cache_key_v1"
        private const val CACHE_ALGORITHM = "AES-256-GCM"
        private const val CACHE_VERSION = 1
        private const val GCM_TAG_BITS = 128
        private const val GCM_NONCE_BYTES = 12
        private val CACHE_AAD =
            "SGP-Agent|record-cache|v1|AES-256-GCM".toByteArray(Charsets.UTF_8)
        private const val MIN_PCM_RMS = 0.002f
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        radioAudioManager = SgpRadioAudioManager(appContext)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        audioEventChannel = EventChannel(binding.binaryMessenger, AUDIO_EVENT_CHANNEL)
        audioEventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        audioEventChannel.setStreamHandler(null)
        radioAudioManager.attachEventSink(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        radioAudioManager.attachEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        radioAudioManager.attachEventSink(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities", "refreshAudioInput" -> result.success(radioAudioManager.refreshSnapshot())
            "loadSllmModel" -> {
                val path = call.argument<String>("modelPath")
                sllmLoaded = path != null && path.isNotEmpty()
                result.success(
                    mapOf(
                        "loaded" to false,
                        "useFallback" to true,
                    ),
                )
            }
            "runSllmInference" -> {
                result.success(
                    mapOf(
                        "text" to null,
                        "useFallback" to true,
                    ),
                )
            }
            "checkUsbAudioInput" -> {
                val snapshot = radioAudioManager.refreshSnapshot()
                result.success(snapshot["usbAudioDetected"] == true)
            }
            "activateRadioAudioRoute" -> {
                result.success(radioAudioManager.activateRadioAudioRoute())
            }
            "stopRadioAudioRoute" -> {
                radioAudioManager.stopRadioAudioRoute()
                result.success(true)
            }
            "transcribeWhisper" -> {
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 25_000
                val locale = call.argument<String>("locale") ?: "ko"
                result.success(transcribeWhisper(timeoutMs, locale))
            }
            "validateSttPipeline" -> {
                result.success(validateSttPipeline())
            }
            "encryptCachePayload" -> {
                try {
                    val plainText = call.argument<String>("plainText")
                        ?: throw IllegalArgumentException("plainText is required")
                    result.success(encryptCachePayload(plainText))
                } catch (error: Exception) {
                    result.error("CACHE_ENCRYPT_FAILED", error.message, null)
                }
            }
            "decryptCachePayload" -> {
                try {
                    val envelope = call.argument<String>("envelopeJson")
                        ?: throw IllegalArgumentException("envelopeJson is required")
                    result.success(decryptCachePayload(envelope))
                } catch (error: Exception) {
                    result.error("CACHE_DECRYPT_FAILED", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun transcribeWhisper(timeoutMs: Int, locale: String): Map<String, Any?> {
        val capture = SgpPcmCapture.capture(appContext, timeoutMs, radioAudioManager)
        if (!capture.success) {
            return mapOf(
                "available" to false,
                "text" to null,
                "error" to capture.error,
                "pcmSamples" to 0,
                "pcmRms" to 0.0,
            )
        }
        if (capture.rmsLevel < MIN_PCM_RMS) {
            return mapOf(
                "available" to false,
                "text" to null,
                "error" to "Audio level too low — check radio PTT / microphone routing",
                "pcmSamples" to capture.pcm.size,
                "pcmRms" to capture.rmsLevel.toDouble(),
            )
        }

        val whisper = SgpWhisperEngine.transcribe(
            appContext,
            capture.pcm,
            SgpPcmCapture.SAMPLE_RATE,
            locale,
        )
        return mapOf(
            "available" to whisper.available,
            "text" to whisper.text,
            "error" to whisper.error,
            "pcmSamples" to capture.pcm.size,
            "pcmRms" to capture.rmsLevel.toDouble(),
        )
    }

    private fun validateSttPipeline(): Map<String, Any?> {
        val snapshot = radioAudioManager.refreshSnapshot().toMutableMap()
        snapshot["whisperModelPath"] = SgpWhisperEngine.modelFile(appContext).absolutePath
        snapshot["whisperNativeLoaded"] = SgpWhisperEngine.nativeLibraryLoaded
        snapshot["minPcmRmsThreshold"] = MIN_PCM_RMS.toDouble()
        return snapshot
    }

    private fun encryptCachePayload(plainText: String): String {
        val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, getOrCreateCacheKey())
        cipher.updateAAD(CACHE_AAD)
        val nonce = cipher.iv
        check(nonce.size == GCM_NONCE_BYTES) { "Unexpected GCM nonce length" }
        val cipherText = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))

        return org.json.JSONObject()
            .put("version", CACHE_VERSION)
            .put("algorithm", CACHE_ALGORITHM)
            .put("keyAlias", CACHE_KEY_ALIAS)
            .put("nonce", android.util.Base64.encodeToString(nonce, android.util.Base64.NO_WRAP))
            .put("cipherText", android.util.Base64.encodeToString(cipherText, android.util.Base64.NO_WRAP))
            .toString()
    }

    private fun decryptCachePayload(envelopeJson: String): String {
        val envelope = org.json.JSONObject(envelopeJson)
        require(envelope.getInt("version") == CACHE_VERSION) {
            "Unsupported cache envelope version"
        }
        require(envelope.getString("algorithm") == CACHE_ALGORITHM) {
            "Unsupported cache algorithm"
        }
        require(envelope.optString("keyAlias", CACHE_KEY_ALIAS) == CACHE_KEY_ALIAS) {
            "Unexpected cache key alias"
        }

        val nonce = android.util.Base64.decode(envelope.getString("nonce"), android.util.Base64.NO_WRAP)
        val cipherText = android.util.Base64.decode(envelope.getString("cipherText"), android.util.Base64.NO_WRAP)
        require(nonce.size == GCM_NONCE_BYTES) { "Invalid GCM nonce length" }

        val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            javax.crypto.Cipher.DECRYPT_MODE,
            getOrCreateCacheKey(),
            javax.crypto.spec.GCMParameterSpec(GCM_TAG_BITS, nonce),
        )
        cipher.updateAAD(CACHE_AAD)
        return String(cipher.doFinal(cipherText), Charsets.UTF_8)
    }

    private fun getOrCreateCacheKey(): javax.crypto.SecretKey {
        val keyStore = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(CACHE_KEY_ALIAS, null) as? javax.crypto.SecretKey
        if (existing != null) return existing

        val generator = javax.crypto.KeyGenerator.getInstance(
            android.security.keystore.KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        val spec = android.security.keystore.KeyGenParameterSpec.Builder(
            CACHE_KEY_ALIAS,
            android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                android.security.keystore.KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(256)
            .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }
}
