/// Android 네이티브 브리지 — Whisper STT / sLLM (llama.cpp) 연동 지점.
library;

import 'package:flutter/services.dart';

import '../features/agent/sgp_secure_cache_crypto.dart';

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

class SgpNativeSttResult {
  const SgpNativeSttResult({
    required this.available,
    this.text,
    this.error,
  });

  final bool available;
  final String? text;
  final String? error;

  bool get hasTranscript => text != null && text!.trim().isNotEmpty;

  factory SgpNativeSttResult.fromMap(Map<dynamic, dynamic> map) {
    return SgpNativeSttResult(
      available: map['available'] == true,
      text: map['text'] as String?,
      error: map['error'] as String?,
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

  /// USB/Bluetooth 무전 입력 장치를 통화용 오디오 경로로 우선 지정.
  static Future<bool> activateRadioAudioRoute() async {
    try {
      return await _channel.invokeMethod<bool>('activateRadioAudioRoute') == true;
    } on MissingPluginException {
      return false;
    }
  }

  /// whisper.cpp JNI 바인딩이 있을 때 PCM 캡처→한국어 전사를 수행한다.
  static Future<SgpNativeSttResult> transcribeWhisper({
    Duration timeout = const Duration(seconds: 25),
    String locale = 'ko',
  }) async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'transcribeWhisper',
        <String, dynamic>{
          'timeoutMs': timeout.inMilliseconds,
          'locale': locale,
        },
      );
      if (map == null) {
        return const SgpNativeSttResult(
          available: false,
          error: 'Whisper 응답이 없습니다.',
        );
      }
      return SgpNativeSttResult.fromMap(map);
    } on MissingPluginException {
      return const SgpNativeSttResult(
        available: false,
        error: 'Whisper 네이티브 플러그인이 없습니다.',
      );
    }
  }

  /// Android Keystore 비내보내기 키로 AES-256-GCM 암호화.
  static Future<String> encryptCachePayload(String plainText) async {
    try {
      final value = await _channel.invokeMethod<String>(
        'encryptCachePayload',
        <String, dynamic>{'plainText': plainText},
      );
      if (value == null || value.isEmpty) {
        throw StateError('네이티브 암호화 결과가 비어 있습니다.');
      }
      return value;
    } on MissingPluginException {
      throw UnsupportedError('이 플랫폼에는 보안 캐시 키 저장소가 없습니다.');
    }
  }

  /// Android Keystore 키로 AES-256-GCM 봉투 복호화.
  static Future<String> decryptCachePayload(String envelopeJson) async {
    try {
      final value = await _channel.invokeMethod<String>(
        'decryptCachePayload',
        <String, dynamic>{'envelopeJson': envelopeJson},
      );
      if (value == null) {
        throw StateError('네이티브 복호화 결과가 없습니다.');
      }
      return value;
    } on MissingPluginException {
      throw UnsupportedError('이 플랫폼에는 보안 캐시 키 저장소가 없습니다.');
    }
  }

  /// 운영 저장소용 암복호화 어댑터.
  static SgpCacheCipher get cacheCipher => const _SgpNativeCacheCipher();
}

class _SgpNativeCacheCipher implements SgpCacheCipher {
  const _SgpNativeCacheCipher();

  @override
  Future<String> encrypt(String plainText) {
    return SgpNativeBridge.encryptCachePayload(plainText);
  }

  @override
  Future<String> decrypt(String envelopeJson) {
    return SgpNativeBridge.decryptCachePayload(envelopeJson);
  }
}
