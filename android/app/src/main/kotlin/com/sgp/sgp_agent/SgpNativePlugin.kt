package com.sgp.sgp_agent

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 온디바이스 AI 네이티브 브리지.
 * - STT: Android SpeechRecognizer (실마이크) + 향후 Whisper JNI 슬롯
 * - sLLM: llama.cpp / GGUF mmap 슬롯 (현재 Dart 폴백)
 */
class SgpNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    private var sllmLoaded = false

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
}
