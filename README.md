# SGP-Agent



SGP-Agent는 현장 경찰관의 초동 수사 판단을 보조하는 온디바이스 법리 매핑 에이전트입니다.



목표는 10월 검경 수사권 변화에 따라 요구되는 경찰 수사역량을 AI로 보완하되, AI가 결정을 대신하지 않고 수사관의 자기판단을 강화하는 것입니다.



## 설계 원칙



- 온디바이스 우선: 무전·진술·법리 판단 정보는 단말 내부에서 처리합니다.

- 고신뢰성: 입력문에 없는 시간, 장소, 행위, 인적사항은 자동 생성하지 않습니다.

- 근거 중심: 키워드 매칭 근거, 적용 법리, 추가 확인 필요 항목을 함께 표시합니다.

- Human-in-the-Loop: 최종 서류 확정은 수사관이 책임 고지를 확인해야만 가능합니다.

- 행정 편의성: 법리 가이드와 별도로 사건 기록 문서 초안을 생성합니다.



## 현재 핵심 기능



- 규칙 기반 법리 매핑: 흉기·위험물, 관계성 폭력, 주취·약물, 도주·신분확인 거부

- CoT형 법리 추론 출력: 핵심 법리, 강제처분, 초동조치 체크리스트

- SGP-Agent Pro 3대 혁신 엔진: 가·피해자 분리, 공소유지 예측, 위수증 방어망

- 신뢰성 점검: 판단 근거, 보완 필요 사실, 환각 방지 상태 표시

- 사건 기록 문서 초안: 접수·인지 경위, 주요 확인 사항, 적용 법리 검토

- 로컬 저장/조회/삭제: 단말 앱 전용 저장소에 JSON 기록 보관

- 체포 T-0 타임라인: 물리력·채증·신병인계·사법 서류 초안

- 양자적 법률 비교: 형법·특별법·민사 다관점 대조 및 행동 지침

- 판례 OTA: `assets/data/court_precedents.json` 기반 판례 트렌드 반영
  (원격 패치는 공식 배포 채널 승인 전까지 비활성 — `kEnableRemoteOta = false`)



## 법령 준수 설계 (통비법·정통법·전파법·보안업무규정)

컴플라이언스 모듈: `lib/features/agent/sgp_legal_compliance.dart`

| 법령 | 잠재 쟁점 | 방어 설계 |
|------|----------|----------|
| 통신비밀보호법 | 무전·대화 녹음이 감청에 해당할 소지 | 버튼 조작식 STT(상시 감청 없음) + 세션 최초 사용 시 준수 고지 게이트(`SgpSttComplianceGate`) + 채증 사전 고지 스크립트(경직법 제10조의2) |
| 정보통신망법 | 수사자료 외부 전송·유출 | 온디바이스 원칙 — 조서·분석 결과 서버 전송 없음. 네트워크는 판례 다운로드 단방향뿐 |
| 전파법 | 무선 설비 운용·주파수 수신 오해 | 앱은 전파 송수신·복조 기능 없음. 전파인증 상용 기기(Bluetooth SCO/USB)의 표준 오디오 입력만 사용 |
| 보안업무규정 | 수사자료 반출 | 외부 공유 전 반출 확인 대화상자 강제 + 승인 채널(폴넷 등) 사용 고지. 비공식 OTA 원격 패치 기본 차단 |



## UI/UX (Material 3 다크)



통합 테마: `lib/features/agent/sgp_app_theme.dart` (`SgpAppTheme`)



| 역할 | 색상 | 용도 |

|------|------|------|

| 배경 | `#121218` | Scaffold, 시스템 내비게이션 |

| 표면 | `#1A1D26` ~ `#242836` | 카드, 입력 필드, 패널 |

| Primary | `#6366F1` 인디고 | 주요 버튼, AppBar 강조 |

| Accent | `#22D3EE` 시안 | STT·링크·탭 강조 |

| 성공/경고/오류 | 에메랄드 / 앰버 / 코랄 | 상태·긴급도 (저자극) |



- `main.dart`에서 `theme: SgpAppTheme.dark` 적용

- CoT·현장 UI는 `SgpCotColors` / `SgpFieldColors` 별칭으로 동일 팔레트 참조

- **내일 확인:** SM-S918N 실기기에서 야간·실외 가독성 검증 권장



## STT 연동 (실연동)



| 단계 | 상태 | 설명 |

|------|------|------|

| 1차 | **활성** | Android `SpeechRecognizer` + 단말 마이크 한국어 실시간 전사 |

| 2차 | 탐지 | USB/유선 헤드셋(무전 케이블) 오디오 입력 자동 감지 |

| 3차 | 예정 | Whisper JNI 온디바이스 (네이티브 `whisperBound`) |



- 가짜 STT 문장을 생성하지 않습니다.

- 마이크 권한(`RECORD_AUDIO`) 필요.

- 삼성 등 단말: 설정 → Google → 음성 → 오프라인 음성 인식(한국어) 설치 시 오프라인 동작.



## sLLM 연동 (브리지)



- `lib/native/sgp_native_bridge.dart` — Dart ↔ Android MethodChannel

- `SgpNativePlugin.kt` — llama.cpp / GGUF mmap 슬롯 (현재 Dart 규칙 엔진 폴백)

- 네이티브 연동 완료 시 `_runInference`가 자동으로 sLLM 출력 사용



## Windows — Run 시 `dart.bat` 보안 경고



**원인:** Flutter SDK의 `dart.bat`이 서명 없는 배치 파일이라 Windows가 실행 전 확인 창을 띄웁니다. Android Studio Run이 매번 `dart.bat`을 호출합니다.



**조치 (1회):**



```powershell

cd C:\SGP-Agent

Set-ExecutionPolicy -Scope Process Bypass

.\scripts\fix-windows-flutter-security.ps1

```



그다음 보안 창이 뜨면:



1. **「이 파일을 열기 전에 항상 확인(W)」 체크 해제**

2. **「실행(R)」** 클릭



**추가 권장:** Android Studio → Settings → Dart → SDK path를  

`C:\src\flutter\bin\cache\dart-sdk` 로 설정 (`dart.bat` 직접 호출 방지).



프로젝트에 `.vscode/settings.json` 동일 설정 포함.

### 레지스트리 신뢰 구역 (보안창이 계속 뜰 때)

```powershell
cd C:\SGP-Agent
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\fix-windows-flutter-security.ps1 -ApplyRegistry
```

또는 `scripts\add-flutter-trusted-zone.reg` 더블클릭 → 예.

### 터미널 Run (보안창 없음)

```cmd
cd C:\SGP-Agent
tools\flutter-direct.cmd run -d YOUR_DEVICE_ID
```

`flutter-direct.cmd`는 `dart.exe`만 직접 호출하므로 `.bat` 보안 경고가 뜨지 않습니다.

## 문서

| 문서 | 설명 |
|------|------|
| [`docs/quantum_legal_hierarchy_work_order.html`](docs/quantum_legal_hierarchy_work_order.html) | **양자 법률적용·위계 필터링 엔진** 개발 작업지시서 (8단계 LV, 스프린트, API·DB 초안) |
| [`docs/작업지시서.md`](docs/작업지시서.md) | 일일 재개용 작업 지시·체크리스트 |
| [`docs/s5_api_and_db.md`](docs/s5_api_and_db.md) | **S5** REST API·DB DDL·JWT·참조 서버 |
| [`docs/s6_ontology_and_production.md`](docs/s6_ontology_and_production.md) | **S6** 온톨로지·경찰 IAM·프로덕션 Cron·배포 |

## 빌드

**실행 대상: Android 단말만** (Windows 데스크톱 미지원 — `device-id=windows` 사용 시 오류)

```cmd
cd C:\SGP-Agent
scripts\run-android.cmd
```

또는 Android Studio Run 구성: **main.dart (SM-S918N)** · 기기 `R3CW203HFGK`

```bash
flutter pub get
tools\flutter-direct.cmd run -d R3CW203HFGK
tools\flutter-direct.cmd build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```



## 다음 작업 (S0~S6 완료 후)

**8단계 위계 로드맵 Phase 1~3 완료 (S0~S6).** 운영 전환 시 아래만 진행.

### 운영 배포 체크리스트
- [ ] 경찰청 IAM JWT 발급 연동 + `NPA_IAM_JWT_MODE=claims` (`docs/s6_ontology_and_production.md`)
- [ ] `kEnableRemoteResolve = true` (정통법·보안업무규정 승인)
- [ ] `kEnableLegalHierarchyOta = true` + `X-SGP-Signature` 공식 키 설정
- [ ] `deploy/docker-compose.yml` 운영 API 배포 + `sql/s6_ontology_ddl.sql` 적용
- [ ] `LAW_GO_KR_OC_KEY` 설정 후 `dart run tool/cron/sync_law_nodes_production.dart`

### 검증
```cmd
dart test test\features\agent\sgp_legal_ontology_test.dart test\features\agent\sgp_npa_iam_jwt_test.dart
dart test test\features\agent\sgp_legal_hierarchy_test.dart test\features\agent\sgp_quantum_legal_api_test.dart
dart run tool/cron/sync_law_nodes_production.dart
dart run bin/quantum_legal_server.dart
tools\flutter-direct.cmd build apk --debug
```

### 알려진 이슈
- `flutter test` isolate hang — `dart test` 사용 (27 tests)
- 판례 `대법원 20XX도XXXX` 자리표시자 교체는 별도 태스크
- `kEnableRemoteOta` / `kEnableRemoteResolve` / `kEnableLegalHierarchyOta` 기본 `false`
