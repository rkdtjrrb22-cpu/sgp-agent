import 'package:test/test.dart';

import 'package:sgp_agent/features/agent/sgp_stt_radio_pipeline.dart';

void main() {
  group('SttAudioInputSnapshot', () {
    test('fromMap parses native refresh payload', () {
      final snapshot = SttAudioInputSnapshot.fromMap({
        'whisperBound': true,
        'speechRecognizerAvailable': true,
        'usbAudioDetected': false,
        'bluetoothScoActive': true,
        'activeInputLabel': 'Bluetooth SCO 무전',
        'whisperModelReady': true,
        'whisperNativeLoaded': true,
        'reason': 'added',
      });

      expect(snapshot.whisperBound, isTrue);
      expect(snapshot.radioInputActive, isTrue);
      expect(snapshot.activeInputLabel, 'Bluetooth SCO 무전');
      expect(snapshot.reason, 'added');
      expect(snapshot.resolveInputSource(), SttInputSource.whisperNative);
    });

    test('resolveInputSource prefers radio over device mic', () {
      const usb = SttAudioInputSnapshot(
        whisperBound: false,
        speechRecognizerAvailable: true,
        usbAudioDetected: true,
        bluetoothScoActive: false,
        activeInputLabel: 'USB 오디오',
      );
      expect(usb.resolveInputSource(), SttInputSource.usbRadio);
    });

    test('copyWithSpeechAvailable updates speech flag only', () {
      const base = SttAudioInputSnapshot(
        whisperBound: false,
        speechRecognizerAvailable: false,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'Device microphone',
      );
      final updated = base.copyWithSpeechAvailable(true);
      expect(updated.speechRecognizerAvailable, isTrue);
      expect(updated.activeInputLabel, base.activeInputLabel);
    });
  });

  group('sttInputSourceLabelFromSnapshot', () {
    test('shows Whisper label when bound', () {
      const snapshot = SttAudioInputSnapshot(
        whisperBound: true,
        speechRecognizerAvailable: true,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'USB 오디오',
      );
      expect(
        sttInputSourceLabelFromSnapshot(snapshot),
        contains('Whisper'),
      );
    });

    test('shows JNI hint when model ready but library missing', () {
      const snapshot = SttAudioInputSnapshot(
        whisperBound: false,
        speechRecognizerAvailable: true,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'Device microphone',
        whisperModelReady: true,
        whisperNativeLoaded: false,
      );
      expect(
        sttInputSourceLabelFromSnapshot(snapshot),
        contains('JNI'),
      );
    });
  });

  group('sttConfidenceAcceptable (S8 45% 가드)', () {
    test('45% 미만이면 재입력 요구', () {
      expect(sttConfidenceAcceptable(0.44), isFalse);
      expect(sttConfidenceAcceptable(0.10), isFalse);
    });

    test('45% 이상이면 통과', () {
      expect(sttConfidenceAcceptable(0.45), isTrue);
      expect(sttConfidenceAcceptable(0.92), isTrue);
    });

    test('신뢰도 미제공(<= 0)이면 가드를 우회한다', () {
      expect(sttConfidenceAcceptable(0), isTrue);
      expect(sttConfidenceAcceptable(-1), isTrue);
    });
  });

  group('sttCaptureReady', () {
    test('true when Whisper bound', () {
      const snapshot = SttAudioInputSnapshot(
        whisperBound: true,
        speechRecognizerAvailable: false,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'Device microphone',
      );
      expect(
        sttCaptureReady(snapshot: snapshot, platformSpeechReady: false),
        isTrue,
      );
    });

    test('true when platform speech available', () {
      const snapshot = SttAudioInputSnapshot(
        whisperBound: false,
        speechRecognizerAvailable: true,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'Device microphone',
      );
      expect(
        sttCaptureReady(snapshot: snapshot, platformSpeechReady: true),
        isTrue,
      );
    });

    test('false when neither Whisper nor platform speech', () {
      const snapshot = SttAudioInputSnapshot(
        whisperBound: false,
        speechRecognizerAvailable: false,
        usbAudioDetected: false,
        bluetoothScoActive: false,
        activeInputLabel: 'Device microphone',
      );
      expect(
        sttCaptureReady(snapshot: snapshot, platformSpeechReady: false),
        isFalse,
      );
    });
  });
}
