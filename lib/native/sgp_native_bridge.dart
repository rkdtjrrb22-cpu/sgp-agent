/// Android 네이티브 브리지 — Whisper STT / sLLM (llama.cpp) 연동 지점.
library;

import 'package:flutter/services.dart';

/// 네이티브 엔진 상태.
class SgpNativeCapabilities {
  const SgpNativeCapabilities({
    required this.whisperBound,
    required this.sllmBound,
    required this.speechRecognizerAvailable,
    required this.usbAudioDetected,
    this.bluetoothScoActive = false,
  });

  final bool whisperBound;
  final bool sllmBound;
  final bool speechRecognizerAvailable;
  final bool usbAudioDetected;
  final bool bluetoothScoActive;

  factory SgpNativeCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return SgpNativeCapabilities(
      whisperBound: map['whisperBound'] == true,
      sllmBound: map['sllmBound'] == true,
      speechRecognizerAvailable: map['speechRecognizerAvailable'] == true,
      usbAudioDetected: map['usbAudioDetected'] == true,
      bluetoothScoActive: map['bluetoothScoActive'] == true,
    );
  }
}

class SgpSllmLoadResult {
  const SgpSllmLoadResult({required this.loaded, required this.useFallback});

  final bool loaded;
  final bool useFallback;

  factory SgpSllmLoadResult.fromMap(Map<dynamic, dynamic> map) {
    return SgpSllmLoadResult(
      loaded: map['loaded'] == true,
      useFallback: map['useFallback'] != false,
    );
  }
}

class SgpSllmInferenceResult {
  const SgpSllmInferenceResult({this.text, required this.useFallback});

  final String? text;
  final bool useFallback;

  factory SgpSllmInferenceResult.fromMap(Map<dynamic, dynamic> map) {
    return SgpSllmInferenceResult(
      text: map['text'] as String?,
      useFallback: map['useFallback'] != false,
    );
  }
}

/// MethodChannel `com.sgp.sgp_agent/native`
class SgpNativeBridge {
  SgpNativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.sgp.sgp_agent/native');

  static Future<SgpNativeCapabilities> getCapabilities() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
      if (map == null) {
        return const SgpNativeCapabilities(
          whisperBound: false,
          sllmBound: false,
          speechRecognizerAvailable: false,
          usbAudioDetected: false,
          bluetoothScoActive: false,
        );
      }
      return SgpNativeCapabilities.fromMap(map);
    } on MissingPluginException {
      return const SgpNativeCapabilities(
        whisperBound: false,
        sllmBound: false,
        speechRecognizerAvailable: false,
        usbAudioDetected: false,
        bluetoothScoActive: false,
      );
    }
  }

  /// sLLM 가중치 로드 (llama.cpp JNI 연동 전: useFallback=true).
  static Future<SgpSllmLoadResult> loadSllmModel({String? modelPath}) async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'loadSllmModel',
        <String, dynamic>{'modelPath': modelPath},
      );
      if (map == null) return const SgpSllmLoadResult(loaded: false, useFallback: true);
      return SgpSllmLoadResult.fromMap(map);
    } on MissingPluginException {
      return const SgpSllmLoadResult(loaded: false, useFallback: true);
    }
  }

  /// sLLM 추론 (네이티브 미연동 시 useFallback → Dart 규칙 엔진).
  static Future<SgpSllmInferenceResult> runSllmInference(String prompt) async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'runSllmInference',
        <String, dynamic>{'prompt': prompt},
      );
      if (map == null) return const SgpSllmInferenceResult(useFallback: true);
      return SgpSllmInferenceResult.fromMap(map);
    } on MissingPluginException {
      return const SgpSllmInferenceResult(useFallback: true);
    }
  }

  /// Whisper JNI 연동 전 USB/무전 오디오 입력 탐지.
  static Future<bool> checkUsbAudioInput() async {
    try {
      final ok = await _channel.invokeMethod<bool>('checkUsbAudioInput');
      return ok == true;
    } on MissingPluginException {
      return false;
    }
  }
}
