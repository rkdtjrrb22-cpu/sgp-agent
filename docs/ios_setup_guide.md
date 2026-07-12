# iOS 빌드·권한 설정 가이드

SGP-Agent iOS 타깃은 `flutter create --platforms=ios`로 생성되었으며, Android와 동일 패키지 `com.sgp.sgp_agent`를 사용합니다.

## 사전 요구 (macOS)

- Xcode 15+ (iOS 13.0+)
- CocoaPods (`sudo gem install cocoapods`)
- Flutter SDK (`flutter doctor` — iOS toolchain 확인)

Windows 개발 환경에서는 **iOS 빌드·시뮬레이터 실행 불가**. macOS에서 아래 절차를 수행합니다.

## 1. 의존성 설치

```bash
cd /path/to/SGP-Agent
flutter pub get
cd ios
pod install
cd ..
```

`ios/Podfile`에 `permission_handler`용 전처리기가 설정되어 있습니다.

| 매크로 | 용도 |
|--------|------|
| `PERMISSION_MICROPHONE` | STT 마이크 |
| `PERMISSION_SPEECH_RECOGNIZER` | 음성 인식 |
| `PERMISSION_LOCATION` / `WHENINUSE` | 향후 지자체 조례 크로스 필터 |
| `PERMISSION_NOTIFICATIONS` | 향후 타임라인·체포 시한 알림 |

## 2. Info.plist 권한 문구

`ios/Runner/Info.plist`에 다음 Usage Description이 포함되어 있습니다.

| 키 | 기능 |
|----|------|
| `NSMicrophoneUsageDescription` | 현장 STT (사용자 조작 시만) |
| `NSSpeechRecognitionUsageDescription` | 음성→텍스트 변환 |
| `NSLocationWhenInUseUsageDescription` | 지자체(LV5~6) 법령 매칭 (향후) |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | 백그라운드 미사용 명시 |
| `UIBackgroundModes` → `remote-notification` | 향후 푸시 알림 대비 |
| `NSAppTransportSecurity` | HTTPS 기본, 로컬 네트워크 허용(개발·내부망 API) |
| `NSLocalNetworkUsageDescription` | 내부망 Quantum Legal API·OTA |
| `NSBonjourServices` | `_sgp-agent._tcp` (내부 서비스 디스커버리 대비) |
| `NSUserNotificationsUsageDescription` | 사법 타임라인 알림 |

**법령 준수:** 위치·알림은 기능 구현 전까지 Dart에서 요청하지 않습니다. `sgp_legal_compliance.dart` 원칙(온디바이스·명시적 조작)을 유지합니다.

## 3. 무서명 iOS 빌드 검증 (macOS 필수)

```bash
chmod +x scripts/verify-ios-build.sh
./scripts/verify-ios-build.sh
```

내부적으로 `pod install` → `flutter analyze lib ios` → `flutter build ios --no-codesign`을 수행합니다.

> **Windows 정적 검토 (2026-07-12):** `scripts/verify-ios-build.sh`는 Bash 스크립트이므로 `dart analyze` 대상이 아닙니다. Windows에서 `set -euo pipefail`·경로·Flutter 서브커맨드 순서를 수동 검토했으며 문법·논리 결함 없음을 확인했습니다. 실제 iOS 바이너리 빌드는 macOS에서만 실행합니다.

## 4. 크로스 플랫폼 검증 (Windows)

```cmd
cd C:\SGP-Agent
scripts\verify-cross-platform.cmd
```

Android APK + `dart analyze` + IAM/JWKS 단위 테스트를 일괄 실행합니다.

## 5. 플러그인별 참고

| 플러그인 | iOS 비고 |
|----------|----------|
| `speech_to_text` | 실기기에서 마이크·Speech Recognition 권한 필요 |
| `permission_handler` | Podfile 매크로와 Info.plist 키 일치 필수 |
| `share_plus` | 추가 권한 없음 |
| `path_provider` | 샌드박스 문서 경로 자동 |

네이티브 sLLM·Whisper 브리지는 Android `SgpNativePlugin.kt`에만 구현되어 있습니다. iOS는 **Dart 규칙 엔진 폴백**으로 동작합니다.

## 5. 문제 해결

| 증상 | 조치 |
|------|------|
| `Podfile.lock` 없음 | `cd ios && pod install` |
| Signing error | Xcode에서 Bundle ID `com.sgp.sgp_agent`·Team 확인 |
| STT 권한 거부 | 설정 → SGP-Agent → 마이크·음성 인식 허용 |
| `Generated.xcconfig` 없음 | 프로젝트 루트에서 `flutter pub get` |

## 6. Android와 차이

| 항목 | Android | iOS |
|------|---------|-----|
| 실행 대상 | SM-S918N (주) | 시뮬레이터·TestFlight |
| STT | Android SpeechRecognizer | `speech_to_text` (Apple) |
| 네이티브 AI | MethodChannel 골격 | 미구현 (폴백) |
