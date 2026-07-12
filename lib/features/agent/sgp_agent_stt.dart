/// Mobile Whisper STT + Android SpeechRecognizer 실연동 어댑터.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:sgp_agent/native/sgp_native_bridge.dart';

import 'sgp_stt_radio_pipeline.dart';

/// STT 세션 상태.
enum SttSessionState {
  idle,
  listening,
  processing,
  error,
}

/// STT 결과.
class SttTranscriptResult {
  const SttTranscriptResult({
    required this.text,
    required this.isFinal,
    required this.offline,
    this.source = SttInputSource.deviceMic,
    this.confidence = 1.0,
  });

  final String text;
  final bool isFinal;
  final bool offline;
  final SttInputSource source;

  /// 0~1 인식 신뢰도. 엔진 미제공 시 1.0.
  final double confidence;
}

/// 신뢰도 45% 미만 — 현장 재입력 요구.
class SttLowConfidenceException implements Exception {
  const SttLowConfidenceException(this.confidence, this.text);

  final double confidence;
  final String text;

  @override
  String toString() =>
      '음성 인식 신뢰도 ${(confidence * 100).round()}% — 무전·마이크에 가까이 대고 다시 말씀해 주세요.';
}

/// 온디바이스 STT 엔진.
///
/// 1차: Android [SpeechRecognizer] 실마이크 한국어 인식 (현장 즉시 사용)
/// 2차: USB 무전 오디오 입력 탐지 ([SgpNativeBridge.checkUsbAudioInput])
/// 3차: Whisper JNI (네이티브 `whisperBound` 시 활성화 예정)
class SgpSttEngine {
  final SpeechToText _speech = SpeechToText();
  SttSessionState _state = SttSessionState.idle;
  bool _modelReady = false;
  bool _hardwareReady = false;
  bool _platformSpeechReady = false;
  bool _usbAudioDetected = false;
  bool _bluetoothScoActive = false;
  bool _whisperBound = false;
  bool _whisperModelReady = false;
  bool _whisperNativeLoaded = false;
  String _activeInputLabel = 'Device microphone';
  SttAudioInputSnapshot? _lastSnapshot;
  String? _lastError;

  SttSessionState get state => _state;
  bool get isModelReady => _modelReady;
  bool get isHardwareReady => _hardwareReady;
  bool get usbAudioDetected => _usbAudioDetected;
  bool get bluetoothScoActive => _bluetoothScoActive;
  bool get whisperBound => _whisperBound;
  bool get whisperModelReady => _whisperModelReady;
  bool get whisperNativeLoaded => _whisperNativeLoaded;
  String get activeInputLabel => _activeInputLabel;
  SttAudioInputSnapshot? get lastAudioSnapshot => _lastSnapshot;
  String? get lastError => _lastError;
  bool get canTranscribe => _modelReady && _hardwareReady;

  /// UI 표시용 입력원 라벨.
  String get inputSourceLabel {
    final snapshot = _lastSnapshot ??
        SttAudioInputSnapshot(
          whisperBound: _whisperBound,
          speechRecognizerAvailable: _platformSpeechReady,
          usbAudioDetected: _usbAudioDetected,
          bluetoothScoActive: _bluetoothScoActive,
          activeInputLabel: _activeInputLabel,
          whisperModelReady: _whisperModelReady,
          whisperNativeLoaded: _whisperNativeLoaded,
        );
    return sttInputSourceLabelFromSnapshot(snapshot);
  }

  /// 핫플러그·refreshAudioInput 결과를 엔진 상태에 반영.
  void applyAudioInputSnapshot(SttAudioInputSnapshot snapshot) {
    _lastSnapshot = snapshot;
    _whisperBound = snapshot.whisperBound;
    _usbAudioDetected = snapshot.usbAudioDetected;
    _bluetoothScoActive = snapshot.bluetoothScoActive;
    _activeInputLabel = snapshot.activeInputLabel;
    _whisperModelReady = snapshot.whisperModelReady;
    _whisperNativeLoaded = snapshot.whisperNativeLoaded;
    _modelReady = sttCaptureReady(
      snapshot: snapshot,
      platformSpeechReady: _platformSpeechReady,
    );
    _hardwareReady = _modelReady;
  }

  /// 캡처 직전 오디오 입력·무전 라우트를 최신화 (S8.2 핫플러그).
  Future<void> prepareForCapture() async {
    final snapshot = await SgpNativeBridge.refreshAudioInput();
    applyAudioInputSnapshot(snapshot);

    if (!kIsWeb && Platform.isAndroid && _bluetoothScoActive) {
      final bluetooth = await Permission.bluetoothConnect.request();
      if (!bluetooth.isGranted) {
        _lastError = 'Bluetooth 무전 입력 권한이 없어 단말 마이크로 전환합니다.';
        _bluetoothScoActive = false;
      }
    }
    if (_usbAudioDetected || _bluetoothScoActive) {
      await SgpNativeBridge.activateRadioAudioRoute();
    }
  }

  Future<void> initialize() async {
    final snapshot = await SgpNativeBridge.refreshAudioInput();
    applyAudioInputSnapshot(snapshot);
    if (!_usbAudioDetected) {
      _usbAudioDetected = await SgpNativeBridge.checkUsbAudioInput();
    }

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        _hardwareReady = false;
        _modelReady = false;
        _lastError = '마이크 권한이 필요합니다. 설정에서 허용해 주세요.';
        return;
      }
    }

    if (!kIsWeb && Platform.isAndroid && _bluetoothScoActive) {
      final bluetooth = await Permission.bluetoothConnect.request();
      if (!bluetooth.isGranted) {
        _lastError = 'Bluetooth 무전 입력 권한이 없어 단말 마이크로 전환합니다.';
        _bluetoothScoActive = false;
      }
    }
    if (_usbAudioDetected || _bluetoothScoActive) {
      await SgpNativeBridge.activateRadioAudioRoute();
    }

    final available = await _speech.initialize(
      onError: (e) => _lastError = e.errorMsg,
      onStatus: (_) {},
    );

    _platformSpeechReady = available;
    applyAudioInputSnapshot(
      (_lastSnapshot ??
              SttAudioInputSnapshot(
                whisperBound: _whisperBound,
                speechRecognizerAvailable: available,
                usbAudioDetected: _usbAudioDetected,
                bluetoothScoActive: _bluetoothScoActive,
                activeInputLabel: _activeInputLabel,
                whisperModelReady: _whisperModelReady,
                whisperNativeLoaded: _whisperNativeLoaded,
              ))
          .copyWithSpeechAvailable(available),
    );
    _lastError = _modelReady ? null : '이 단말에서 음성 인식을 사용할 수 없습니다.';
  }

  void dispose() {
    _speech.stop();
    _speech.cancel();
    SgpNativeBridge.stopRadioAudioRoute();
    _modelReady = false;
    _hardwareReady = false;
    _platformSpeechReady = false;
    _state = SttSessionState.idle;
  }

  /// 마이크(또는 향후 USB 무전) → 텍스트. 가짜 문장 생성 없음.
  Future<SttTranscriptResult> transcribeFromMic({
    Duration listenTimeout = const Duration(seconds: 25),
  }) async {
    if (!_modelReady) await initialize();
    await prepareForCapture();
    if (!_hardwareReady) {
      throw StateError(
        _lastError ??
            '음성 입력을 사용할 수 없습니다. 마이크 권한·Google 음성 인식 패키지를 확인하세요.',
      );
    }

    if (_whisperBound) {
      try {
        return await _transcribeWhisperNative(listenTimeout);
      } catch (error) {
        _lastError = 'Whisper 폴백: $error';
        if (!_platformSpeechReady) rethrow;
      }
    }

    _state = SttSessionState.listening;
    final completer = Completer<SttTranscriptResult>();
    var latestText = '';
    var latestConfidence = 0.0;

    final locales = await _speech.locales();
    var localeId = 'ko_KR';
    for (final l in locales) {
      if (l.localeId.startsWith('ko')) {
        localeId = l.localeId;
        break;
      }
    }

    final started = await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        latestText = result.recognizedWords.trim();
        latestConfidence =
            result.hasConfidenceRating ? result.confidence : 1.0;
        if (result.finalResult && latestText.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete(
              SttTranscriptResult(
                text: latestText,
                isFinal: true,
                offline: !kIsWeb && Platform.isAndroid,
                confidence: latestConfidence,
                source: _lastSnapshot?.resolveInputSource() ??
                    (_bluetoothScoActive || _usbAudioDetected
                        ? SttInputSource.usbRadio
                        : SttInputSource.deviceMic),
              ),
            );
          }
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: listenTimeout,
        partialResults: true,
        cancelOnError: true,
        onDevice: true,
      ),
    );

    if (!started) {
      _state = SttSessionState.error;
      throw StateError(_lastError ?? '음성 인식을 시작할 수 없습니다.');
    }

    _state = SttSessionState.processing;

    try {
      final result = await completer.future.timeout(
        listenTimeout + const Duration(seconds: 2),
        onTimeout: () {
          if (latestText.isNotEmpty) {
            return SttTranscriptResult(
              text: latestText,
              isFinal: true,
              offline: !kIsWeb && Platform.isAndroid,
              confidence: latestConfidence <= 0 ? 1.0 : latestConfidence,
              source: _lastSnapshot?.resolveInputSource() ??
                  (_bluetoothScoActive || _usbAudioDetected
                      ? SttInputSource.usbRadio
                      : SttInputSource.deviceMic),
            );
          }
          throw StateError('음성이 감지되지 않았습니다. 무전·마이크에 대고 다시 말씀해 주세요.');
        },
      );
      _state = SttSessionState.idle;
      if (!sttConfidenceAcceptable(result.confidence)) {
        throw SttLowConfidenceException(result.confidence, result.text);
      }
      return result;
    } finally {
      await _speech.stop();
      if (_state != SttSessionState.idle) _state = SttSessionState.idle;
    }
  }

  Future<SttTranscriptResult> _transcribeWhisperNative(Duration timeout) async {
    _state = SttSessionState.listening;
    try {
      final result = await SgpNativeBridge.transcribeWhisper(timeout: timeout);
      _state = SttSessionState.processing;
      if (!result.available || !result.hasTranscript) {
        throw StateError(result.error ?? 'Whisper 전사 결과가 없습니다.');
      }
      return SttTranscriptResult(
        text: result.text!.trim(),
        isFinal: true,
        offline: true,
        source: SttInputSource.whisperNative,
      );
    } finally {
      _state = SttSessionState.idle;
    }
  }
}

String sttStateLabel(SttSessionState state) {
  switch (state) {
    case SttSessionState.idle:
      return '무전 STT 대기';
    case SttSessionState.listening:
      return '무전 수신 중…';
    case SttSessionState.processing:
      return '온디바이스 STT 변환 중…';
    case SttSessionState.error:
      return 'STT 오류';
  }
}
