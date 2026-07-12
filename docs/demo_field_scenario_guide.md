# 현장 시연 가이드 — SM-S918N (무전 → 양자분석 → 체포 타임라인)

APK가 설치된 **SM-S918N** 단말에서 Docker·법제처 API·원격 서버 없이 핵심 시나리오를 검증하는 절차입니다.

## 사전 조건

| 항목 | 상태 |
|------|------|
| 단말 | Samsung SM-S918N (`R3CW203HFGK`) |
| APK | `flutter build apk --debug` 산출물 설치 완료 |
| 네트워크 | **불필요** (온디바이스·오프라인 스텁) |
| Docker | **불필요** (`kUseProductionStub=true`) |
| `LAW_GO_KR_OC_KEY` | **불필요** (`LAW_SYNC_REQUIRE_LIVE_KEY=false`) |

앱 상단 Bluetooth/OTA 상태줄에 `ontology:128 · offline_stub` 형태가 표시되면 온톨로지 세션이 정상 로드된 것입니다.

## 핵심 시나리오 (Mock)

**파일:** `assets/data/demo_field_scenario.json`  
**ID:** `demo_mutual_combat_gangnam` — 서울 강남 쌍방 폭행

### 무전 입력 (자동 주입)

앱 **AppBar 우측 ▶(시연)** 버튼을 누르면 아래 무전 문장과 체크리스트가 자동 입력됩니다.

```
14:32 서울 강남구 역삼동 교차로. 신고자 A·B 쌍방 폭행. A가 먼저 밀쳤으나 B가 주먹 2회 반격.
흉기 없음. 주취 아님. 현장 도주 없음. 피해자 B 휴대폰 파손. 현행범 체포 검토 요청.
```

## 단계별 검증 체크리스트

### 1단계 — 무전 입력 → 양자 비교 패널

1. 앱 실행 후 **▶ 시연** 버튼 탭
2. 무전 텍스트 필드에 시나리오 문장이 채워지는지 확인
3. **양자 비교 패널**이 나타나는지 확인
4. 기대값:
   - 사건 유형: `mutual_combat` (쌍방 폭행)
   - 긴급도: `caution`
   - 위계 체인에 **형법**, **형사소송법** 포함

### 2단계 — 온톨로지 양자분석 (128 Triples)

1. 상단 상태줄에서 `ontology:128` (100 이상) 확인
2. 위계 체인 카드에서 헌법 → 형법 → 형소법 경로 표시 확인
3. **「2·3단계: 법리 추론 (CoT)」** 버튼 실행
4. Pro 분석 카드(고급 분석) 표시 확인

> 백엔드: `SgpLegalOntologySession`이 `legal_hierarchy_seed.json`에서 SPO 그래프를 메모리에 강제 로드합니다.  
> `SgpProductionStub.resolveLocal()`이 Docker/법제처 API 없이 동일 경로를 에뮬레이션합니다.

### 3단계 — 체포 타임라인 직관적 확인

1. **「체포 확정 — 타임라인 시작」** 버튼 탭
2. AI 감지: **현행범 체포** (`currentOffender`) 확인
3. T-0 기준 카운트다운·마감 시한 표시:
   - 체포통지 **24h**
   - 영장신청 **45h**
   - 검사청구 **48h**
4. 하단 타임라인 위젯에서 노드 체크·증거 고지·보고서 생성 흐름 확인

## 자동 검증 (개발 PC)

```cmd
cd C:\SGP-Agent
dart test test/features/agent/sgp_demo_field_scenario_test.dart
dart test test/features/agent/sgp_legal_ontology_session_test.dart
dart test test/features/agent/sgp_production_stub_test.dart
dart test
```

## 오프라인 스텁 상수 (프로덕션 전환 시)

| 상수 / 환경변수 | 시연 기본값 | 운영 전환 |
|-----------------|------------|-----------|
| `kUseProductionStub` | `true` | `false` + Docker |
| `kLawSyncRequireLiveKey` | `false` | `true` + API 키 |
| `LAW_SYNC_REQUIRE_LIVE_KEY` | `false` | `true` |
| `kEnableRemoteResolve` | `false` | IAM JWT + 서버 URL |

## Docker 없이 서버·Cron 검증 (Windows)

```cmd
deploy\run_without_docker.cmd
```

- 참조 REST 서버: `dart run bin/quantum_legal_server.dart` (시드 기반 128 triples)
- 법령 Cron: `dart run tool/cron/sync_law_nodes_production.dart` (오프라인 스텁)

## 문제 해결

| 증상 | 조치 |
|------|------|
| 시연 버튼 후 패널 없음 | 무전 텍스트가 비어 있지 않은지 확인, 앱 재시작 |
| `ontology:0` | `assets/data/legal_hierarchy_seed.json` 번들 포함 여부·`flutter pub get` |
| 체포 타입 미감지 | 「현행범 체포」 문구 포함 여부 확인 |
| 스낵바 «검증 주의» | `dart test`로 기대값·엔진 출력 대조 |

## 관련 소스

- `lib/features/agent/sgp_demo_field_scenario.dart` — Mock 로더·검증
- `lib/features/agent/sgp_legal_ontology_session.dart` — Triples 세션
- `lib/features/agent/sgp_production_stub.dart` — 오프라인 스텁
- `lib/features/agent/sgp_agent_screen.dart` — ▶ 시연 버튼
