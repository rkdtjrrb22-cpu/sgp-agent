package com.sgp.sgp_agent

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * USB/Bluetooth/유선 무전 입력 탐지·핫플러그·통화 오디오 라우팅.
 */
class SgpRadioAudioManager(
    private val appContext: Context,
    private val onDevicesChanged: (() -> Unit)? = null,
) {
    private val audioManager =
        appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var deviceCallback: AudioDeviceCallback? = null
    private var eventSink: EventChannel.EventSink? = null

    fun attachEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            registerHotplugListener()
            emitRefresh("initial")
        } else {
            unregisterHotplugListener()
        }
    }

    fun refreshSnapshot(): Map<String, Any?> {
        val usb = detectExternalAudioInput()
        val btSco = detectBluetoothSco()
        val speechAvailable =
            android.speech.SpeechRecognizer.isRecognitionAvailable(appContext)
        val whisperReady = SgpWhisperEngine.isReady(appContext)
        return mapOf(
            "whisperBound" to whisperReady,
            "speechRecognizerAvailable" to speechAvailable,
            "usbAudioDetected" to usb,
            "bluetoothScoActive" to btSco,
            "activeInputLabel" to describeActiveInput(),
            "whisperModelReady" to SgpWhisperEngine.hasModelFile(appContext),
            "whisperNativeLoaded" to SgpWhisperEngine.nativeLibraryLoaded,
        )
    }

    fun activateRadioAudioRoute(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val preferred = audioManager.availableCommunicationDevices.firstOrNull { device ->
                    isRadioInputType(device.type)
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

    fun stopRadioAudioRoute() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            } else {
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = false
                @Suppress("DEPRECATION")
                audioManager.mode = AudioManager.MODE_NORMAL
            }
        } catch (_: SecurityException) {
            // ignore
        }
    }

    private fun registerHotplugListener() {
        if (deviceCallback != null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        deviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                emitRefresh("added")
                onDevicesChanged?.invoke()
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                emitRefresh("removed")
                onDevicesChanged?.invoke()
            }
        }
        audioManager.registerAudioDeviceCallback(deviceCallback!!, mainHandler)
    }

    private fun unregisterHotplugListener() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        deviceCallback = null
    }

    private fun emitRefresh(reason: String) {
        val payload = refreshSnapshot().toMutableMap()
        payload["reason"] = reason
        eventSink?.success(payload)
    }

    private fun describeActiveInput(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return when {
                detectBluetoothSco() -> "Bluetooth SCO"
                detectExternalAudioInput() -> "External audio"
                else -> "Device microphone"
            }
        }
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
        val radio = devices.firstOrNull { isRadioInputType(it.type) }
        if (radio != null) return audioDeviceLabel(radio.type)
        return "Device microphone"
    }

    private fun detectBluetoothSco(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            devices.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isBluetoothScoOn
        }
    }

    private fun detectExternalAudioInput(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            devices.any { isRadioInputType(it.type) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isWiredHeadsetOn || audioManager.isBluetoothScoOn
        }
    }

    private fun isRadioInputType(type: Int): Boolean {
        return type == AudioDeviceInfo.TYPE_USB_DEVICE ||
            type == AudioDeviceInfo.TYPE_USB_HEADSET ||
            type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
            type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
    }

    private fun audioDeviceLabel(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO 무전"
        AudioDeviceInfo.TYPE_USB_DEVICE -> "USB 오디오"
        AudioDeviceInfo.TYPE_USB_HEADSET -> "USB 헤드셋"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "유선 헤드셋"
        else -> "External input"
    }
}
