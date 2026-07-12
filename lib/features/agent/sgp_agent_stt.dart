/// Mobile Whisper STT + Android SpeechRecognizer 실연동 어댑터.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:sgp_agent/native/sgp_native_bridge.dart';

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
  });

  final String text;
  final bool isFinal;
  final bool offline;
  final SttInputSource source;
}

enum SttInputSource {
  deviceMic,
  usbRadio,
  whisperNative,
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
  String? _lastError;

  SttSessionState get state => _state;
  bool get isModelReady => _modelReady;
  bool get isHardwareReady => _hardwareReady;
  bool get usbAudioDetected => _usbAudioDetected;
  bool get bluetoothScoActive => _bluetoothScoActive;
  bool get whisperBound => _whisperBound;
  String? get lastError => _lastError;
  bool get canTranscribe => _modelReady && _hardwareReady;

  /// UI 표시용 입력원 라벨.
  String get inputSourceLabel {
    if (_whisperBound) return 'Whisper 온디바이스';
    if (_bluetoothScoActive) return 'Bluetooth SCO 무전 + STT';
    if (_usbAudioDetected) return 'USB/유선 무전 + 마이크 STT';
    return '단말 마이크 STT (한국어)';
  }

  Future<void> initialize() async {
    final caps = await SgpNativeBridge.getCapabilities();
    _whisperBound = caps.whisperBound;
    _usbAudioDetected = caps.usbAudioDetected || await SgpNativeBridge.checkUsbAudioInput();
    _bluetoothScoActive = caps.bluetoothScoActive;

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
    _modelReady = _whisperBound || available;
    _hardwareReady = _modelReady;
    _lastError = _modelReady ? null : '이 단말에서 음성 인식을 사용할 수 없습니다.';
  }

  void dispose() {
    _speech.stop();
    _speech.cancel();
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
        if (result.finalResult && latestText.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete(
              SttTranscriptResult(
                text: latestText,
                isFinal: true,
                offline: !kIsWeb && Platform.isAndroid,
                source: _bluetoothScoActive
                    ? SttInputSource.usbRadio
                    : _usbAudioDetected
                        ? SttInputSource.usbRadio
                        : SttInputSource.deviceMic,
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
              source: _bluetoothScoActive || _usbAudioDetected
                  ? SttInputSource.usbRadio
                  : SttInputSource.deviceMic,
            );
          }
          throw StateError('음성이 감지되지 않았습니다. 무전·마이크에 대고 다시 말씀해 주세요.');
        },
      );
      _state = SttSessionState.idle;
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
