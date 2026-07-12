# S8.2 STT 무전 파이프라인 — SM-S918N 실기기 검증

Galaxy S24 Ultra (SM-S918N) 및 현장 무전 연동 시 STT 파이프라인을 확인하는 체크리스트입니다.

## 사전 준비

1. `flutter run` 또는 debug APK를 SM-S918N에 설치
2. 앱 권한: **마이크**, **Bluetooth 연결** (Android 12+)
3. (선택) Whisper 모델: `adb push ggml-base.bin /sdcard/` 후
   `adb shell run-as com.sgp.sgp_agent mkdir -p files/whisper`
   `adb shell run-as com.sgp.sgp_agent cp /sdcard/ggml-base.bin files/whisper/ggml-base.bin`

## 검증 항목

| # | 항목 | 기대 결과 |
|---|------|-----------|
| 1 | 앱 기동 후 상태바 | `activeInputLabel` 표시 (기본: Device microphone) |
| 2 | Bluetooth SCO 무전 연결 | 상태바가 **Bluetooth/USB 무전 연동** 으로 전환 |
| 3 | USB 오디오 연결/분리 | 핫플러그 이벤트로 라벨 즉시 갱신 |
| 4 | STT 캡처 버튼 | 캡처 직전 `refreshAudioInput` → 무전 라우트 활성화 |
| 5 | 온디바이스 SpeechRecognizer | 한국어 전사, 오프라인 표시 |
| 6 | Whisper (모델+JNI) | JNI stub 시 SpeechRecognizer 폴백; whisper.cpp 링크 시 Whisper 전사 |
| 7 | `validateSttPipeline` | `whisperNativeLoaded`, `whisperModelPath`, `minPcmRmsThreshold` 반환 |

## adb 검증 스크립트

Windows:

```cmd
scripts\verify-stt-device.cmd
```

## PCM / RMS

- 샘플레이트: 16 kHz mono
- 최소 RMS: `0.002` (무전 PTT·라우팅 확인)
- RMS 미달 시: "Audio level too low" — PTT·볼륨·SCO 재연결 확인

## 알려진 제한

- 기본 빌드: `sgp_whisper_jni`는 PCM 캡처 계약만 검증, 전사는 `null` → SpeechRecognizer 폴백
- whisper.cpp 연동 빌드: `SGP_WHISPER_CPP=1` CMake 옵션으로 inference 교체 예정
