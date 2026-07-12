package com.sgp.sgp_agent

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 온디바이스 AI 네이티브 브리지.
 * - STT: Android SpeechRecognizer (실마이크) + 향후 Whisper JNI 슬롯
 * - sLLM: llama.cpp / GGUF mmap 슬롯 (현재 Dart 폴백)
 */
class SgpNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    private var sllmLoaded = false

    companion object {
        private const val CACHE_KEY_ALIAS = "sgp_agent_cache_key_v1"
        private const val CACHE_ALGORITHM = "AES-256-GCM"
        private const val CACHE_VERSION = 1
        private const val GCM_TAG_BITS = 128
        private const val GCM_NONCE_BYTES = 12
        private val CACHE_AAD =
            "SGP-Agent|record-cache|v1|AES-256-GCM".toByteArray(StandardCharsets.UTF_8)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.sgp.sgp_agent/native")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> result.success(capabilities())
            "loadSllmModel" -> {
                // TODO: GGUF mmap — llama.cpp JNI
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
                // TODO: 네이티브 토큰 생성
                result.success(
                    mapOf(
                        "text" to null,
                        "useFallback" to true,
                    ),
                )
            }
            "checkUsbAudioInput" -> {
                result.success(detectExternalAudioInput())
            }
            "activateRadioAudioRoute" -> {
                result.success(activateRadioAudioRoute())
            }
            "transcribeWhisper" -> {
                // JNI 라이브러리·GGML 모델이 번들된 빌드에서 이 계약을 구현한다.
                // 미바인딩 빌드는 Dart의 오프라인 우선 SpeechRecognizer로 안전하게 폴백한다.
                result.success(
                    mapOf(
                        "available" to false,
                        "text" to null,
                        "error" to "whisper.cpp JNI/model not bundled",
                    ),
                )
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

    private fun capabilities(): Map<String, Any> {
        val speechAvailable = SpeechRecognizer.isRecognitionAvailable(appContext)
        val btSco = detectBluetoothSco()
        return mapOf(
            "whisperBound" to false,
            "sllmBound" to sllmLoaded,
            "speechRecognizerAvailable" to speechAvailable,
            "usbAudioDetected" to detectExternalAudioInput(),
            "bluetoothScoActive" to btSco,
        )
    }

    private fun detectBluetoothSco(): Boolean {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            devices.any { it.type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isBluetoothScoOn
        }
    }

    /** USB 오디오·유선 헤드셋(무전 케이블) 연결 여부 휴리스틱. */
    private fun detectExternalAudioInput(): Boolean {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            devices.any { device ->
                val type = device.type
                type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                    type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET ||
                    type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isWiredHeadsetOn || audioManager.isBluetoothScoOn
        }
    }

    /** 외부 무전 입력을 Android 통신 오디오 경로로 우선 지정한다. */
    private fun activateRadioAudioRoute(): Boolean {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val preferred = audioManager.availableCommunicationDevices.firstOrNull { device ->
                    device.type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        device.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET ||
                        device.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                        device.type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET
                }
                preferred != null && audioManager.setCommunicationDevice(preferred)
            } else {
                @Suppress("DEPRECATION")
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                if (detectBluetoothSco()) {
                    @Suppress("DEPRECATION")
                    audioManager.startBluetoothSco()
                    @Suppress("DEPRECATION")
                    audioManager.isBluetoothScoOn = true
                }
                detectExternalAudioInput()
            }
        } catch (_: SecurityException) {
            false
        }
    }

    /** Android Keystore 비내보내기 AES-256 키를 생성하거나 조회한다. */
    private fun getOrCreateCacheKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(CACHE_KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        val spec = KeyGenParameterSpec.Builder(
            CACHE_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun encryptCachePayload(plainText: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateCacheKey())
        cipher.updateAAD(CACHE_AAD)
        val nonce = cipher.iv
        check(nonce.size == GCM_NONCE_BYTES) { "Unexpected GCM nonce length" }
        val cipherText = cipher.doFinal(plainText.toByteArray(StandardCharsets.UTF_8))

        return JSONObject()
            .put("version", CACHE_VERSION)
            .put("algorithm", CACHE_ALGORITHM)
            .put("keyAlias", CACHE_KEY_ALIAS)
            .put("nonce", Base64.encodeToString(nonce, Base64.NO_WRAP))
            .put("cipherText", Base64.encodeToString(cipherText, Base64.NO_WRAP))
            .toString()
    }

    private fun decryptCachePayload(envelopeJson: String): String {
        val envelope = JSONObject(envelopeJson)
        require(envelope.getInt("version") == CACHE_VERSION) {
            "Unsupported cache envelope version"
        }
        require(envelope.getString("algorithm") == CACHE_ALGORITHM) {
            "Unsupported cache algorithm"
        }
        require(envelope.optString("keyAlias", CACHE_KEY_ALIAS) == CACHE_KEY_ALIAS) {
            "Unexpected cache key alias"
        }

        val nonce = Base64.decode(envelope.getString("nonce"), Base64.NO_WRAP)
        val cipherText = Base64.decode(envelope.getString("cipherText"), Base64.NO_WRAP)
        require(nonce.size == GCM_NONCE_BYTES) { "Invalid GCM nonce length" }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateCacheKey(),
            GCMParameterSpec(GCM_TAG_BITS, nonce),
        )
        cipher.updateAAD(CACHE_AAD)
        return String(cipher.doFinal(cipherText), StandardCharsets.UTF_8)
    }
}
