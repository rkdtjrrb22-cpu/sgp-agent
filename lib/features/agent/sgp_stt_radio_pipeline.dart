/// S8.2 — 무전 STT 입력 스냅샷·라벨 (Flutter 비의존).
library;

/// STT 입력 경로.
enum SttInputSource {
  deviceMic,
  usbRadio,
  whisperNative,
}

/// S8 — 음성 인식 신뢰도 하한 (45% 미만이면 재입력 요구).
const double kSttMinConfidence = 0.45;

/// 신뢰도 가드. 엔진이 신뢰도를 제공하지 않는 경우(<= 0)는 통과시킨다.
bool sttConfidenceAcceptable(
  double confidence, {
  double threshold = kSttMinConfidence,
}) {
  if (confidence <= 0) return true;
  return confidence >= threshold;
}

/// 네이티브 refreshAudioInput / 핫플러그 이벤트 페이로드.
class SttAudioInputSnapshot {
  const SttAudioInputSnapshot({
    required this.whisperBound,
    required this.speechRecognizerAvailable,
    required this.usbAudioDetected,
    required this.bluetoothScoActive,
    required this.activeInputLabel,
    this.whisperModelReady = false,
    this.whisperNativeLoaded = false,
    this.reason,
  });

  final bool whisperBound;
  final bool speechRecognizerAvailable;
  final bool usbAudioDetected;
  final bool bluetoothScoActive;
  final String activeInputLabel;
  final bool whisperModelReady;
  final bool whisperNativeLoaded;
  final String? reason;

  bool get radioInputActive => usbAudioDetected || bluetoothScoActive;

  factory SttAudioInputSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return SttAudioInputSnapshot(
      whisperBound: map['whisperBound'] == true,
      speechRecognizerAvailable: map['speechRecognizerAvailable'] == true,
      usbAudioDetected: map['usbAudioDetected'] == true,
      bluetoothScoActive: map['bluetoothScoActive'] == true,
      activeInputLabel: map['activeInputLabel'] as String? ?? 'Device microphone',
      whisperModelReady: map['whisperModelReady'] == true,
      whisperNativeLoaded: map['whisperNativeLoaded'] == true,
      reason: map['reason'] as String?,
    );
  }

  SttInputSource resolveInputSource() {
    if (whisperBound) return SttInputSource.whisperNative;
    if (bluetoothScoActive || usbAudioDetected) return SttInputSource.usbRadio;
    return SttInputSource.deviceMic;
  }

  SttAudioInputSnapshot copyWithSpeechAvailable(bool available) {
    return SttAudioInputSnapshot(
      whisperBound: whisperBound,
      speechRecognizerAvailable: available,
      usbAudioDetected: usbAudioDetected,
      bluetoothScoActive: bluetoothScoActive,
      activeInputLabel: activeInputLabel,
      whisperModelReady: whisperModelReady,
      whisperNativeLoaded: whisperNativeLoaded,
      reason: reason,
    );
  }
}

String sttInputSourceLabelFromSnapshot(SttAudioInputSnapshot snapshot) {
  if (snapshot.whisperBound) {
    return 'Whisper 온디바이스 (${snapshot.activeInputLabel})';
  }
  if (snapshot.bluetoothScoActive) {
    return 'Bluetooth SCO 무전 + STT · ${snapshot.activeInputLabel}';
  }
  if (snapshot.usbAudioDetected) {
    return 'USB/유선 무전 + 마이크 STT · ${snapshot.activeInputLabel}';
  }
  if (snapshot.whisperModelReady && !snapshot.whisperNativeLoaded) {
    return 'Whisper 모델 준비됨 — JNI 재빌드 필요 · ${snapshot.activeInputLabel}';
  }
  return '단말 마이크 STT (한국어) · ${snapshot.activeInputLabel}';
}

SttInputSource sttOfflineSourceHint(SttAudioInputSnapshot snapshot) {
  return snapshot.resolveInputSource();
}

/// STT 캡처 전 준비 단계가 성공했는지 판단.
bool sttCaptureReady({
  required SttAudioInputSnapshot snapshot,
  required bool platformSpeechReady,
}) {
  return snapshot.whisperBound || platformSpeechReady;
}
