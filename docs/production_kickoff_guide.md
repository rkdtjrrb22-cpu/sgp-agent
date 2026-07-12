# 프로덕션 배포 킥오프 가이드 (실무자용)

본 문서는 [`s6_ontology_and_production.md`](s6_ontology_and_production.md)를 기반으로, **운영·인프라·보안 담당자**가 SGP-Agent 백엔드(Quantum Legal API)를 처음 가동할 때 따르는 체크리스트입니다.

**대상 독자:** 경찰청/지방청 IT운영, API 게이트웨이·DB·IAM 담당  
**예상 소요:** 스테이징 0.5일 · 운영 전환 1일 (IAM·법령 API 키 확보 포함)

---

## 0. 아키텍처 한눈에 보기

```
[경찰 IAM] ──JWT──► [API Gateway / RS256 검증]
                           │
                           ▼
              [quantum-legal-api :8080]
                     │           │
                     ▼           ▼
              [PostgreSQL]   [legal_hierarchy 시드]
                     │
              legal_nodes + legal_triples (SPO)
```

- **온디바이스 앱:** 기본 오프라인. `kEnableRemoteResolve=true` 승인 후 IAM JWT로 API 호출.
- **참조 구현:** `bin/quantum_legal_server.dart` + `deploy/docker-compose.yml`

---

## 1. 배포 전 준비물

| 항목 | 담당 | 비고 |
|------|------|------|
| Docker·Docker Compose | 인프라 | Linux 서버 또는 내부 VM |
| PostgreSQL 16 | 인프라 | compose 포함 또는 관리형 DB |
| TLS 인증서 | 인프라 | `https://api.sgp-agent.police.go.kr` (예시) |
| 경찰 IAM JWT 발급 | IAM | `iss`·`aud`·클레임 규격 합의 |
| JWKS URL | IAM | `strict` 모드·게이트웨이 연동 |
| 법제처 OC 키 | 데이터 | `LAW_GO_KR_OC_KEY` |
| 정통법·보안업무규정 승인 | 보안 | 원격 resolve·OTA 활성화 |

---

## 2. 환경 파일 작성 (15분)

```cmd
cd C:\SGP-Agent\deploy
copy quantum_legal_production.env.example quantum_legal_production.env
```

### 필수 수정 항목

```ini
POSTGRES_PASSWORD=<강력한_비밀번호>
NPA_IAM_JWT_MODE=claims
NPA_IAM_ISSUER=https://iam.police.go.kr
NPA_IAM_AUDIENCE=sgp-agent-api
NPA_IAM_JWKS_URL=https://iam.police.go.kr/.well-known/jwks.json
```

스테이징 PoC만 할 경우 `NPA_IAM_JWT_MODE=none` 가능 (운영 금지).

### 검증

```cmd
cd C:\SGP-Agent
dart run deploy/validate_production_env.dart deploy/quantum_legal_production.env
```

`OK — ready for docker compose up -d` 확인.

---

## 3. 스택 기동 (30분)

```cmd
cd C:\SGP-Agent\deploy
docker compose up -d
docker compose ps
curl http://127.0.0.1:8080/health
```

### DB 초기화 확인

- 최초 기동 시 `sql/s6_ontology_ddl.sql`이 `docker-entrypoint-initdb.d`로 적용됩니다.
- 수동 적용: `psql %DATABASE_URL% -f sql/s6_ontology_ddl.sql`

### 헬스체크

| URL | 기대 |
|-----|------|
| `GET /health` | `ok` |
| `GET /v1/legal-ontology/migrate/preview` | JWT 필요, triple 통계 JSON |

---

## 4. 경찰 IAM JWT 연동

### 4.1 서버 측 (`NPA_IAM_JWT_MODE=claims`)

| 모드 | 검증 내용 | 권장 환경 |
|------|-----------|-----------|
| `none` | org_id payload만 | 로컬 개발 |
| `claims` | exp·iss·aud·nbf + **JWKS RS256** (`NPA_IAM_VERIFY_JWKS=true`) | **스테이징·운영** |
| `strict` | claims + JWKS URL 필수 | API Gateway와 병행 |

`sgp_npa_iam_jwks.dart` — JWKS fetch·캐시·RS256 서명 검증. API 서버 기동 시 `warmUp(jwksUrl)` 자동 실행.

### 4.2 JWT 클레임 규격

```json
{
  "iss": "https://iam.police.go.kr",
  "aud": "sgp-agent-api",
  "sub": "officer-uuid",
  "org_id": "KR-NPA",
  "local_gov_code": "11",
  "station_id": "1140000",
  "task_category": "field_arrest",
  "exp": 1735689600
}
```

### 4.3 API 호출 예시

```cmd
curl -X POST http://127.0.0.1:8080/v1/quantum-legal/resolve ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer <IAM_JWT>" ^
  -d "{\"actor\":{\"org_id\":\"KR-NPA\",\"local_gov_code\":\"11\"},\"situation\":{\"raw_text\":\"서울 교통사고\"}}"
```

### 4.4 Flutter 단말 연동 (초안)

| 모듈 | 역할 |
|------|------|
| `sgp_npa_iam_client.dart` | MDM에서 JWT 프로비저닝·`NpaIamClientSession` |
| `sgp_quantum_legal_remote.dart` | IAM 세션 자동 bearer 사용 |
| `sgp_legal_compliance.dart` | `kEnableRemoteResolve`, `kEnableNpaIamStrictJwt` |

**운영 전환 순서:**

1. MDM으로 `NpaIamClientSession.setBearerToken(iamJwt)` 주입 (또는 앱 초기화 훅)
2. `NpaIamClientSession.configure(NpaIamClientConfig(apiBaseUrl: 'https://api...'))`
3. 보안 승인 후 `kEnableRemoteResolve = true`
4. `NpaIamClientSession.configure(NpaIamClientConfig(strictJwtValidation: true))` — 클라이언트 JWT 선검증

---

## 5. 법령 데이터 Cron (일 배치)

운영 환경 변수:

```
LAW_GO_KR_OC_KEY=<법제처_OC>
LAW_SYNC_REQUIRE_LIVE_KEY=true
LAW_API_MAX_RETRIES=3
```

Exit code: `0` OK · `2` 키 누락/실조회 실패 · `3` 부분 실패

```cmd
set LAW_GO_KR_OC_KEY=<법제처_OC>
dart run tool/cron/sync_law_nodes_production.dart
```

산출물:

- `build/legal_nodes_sync.json` — 병합 노드
- `build/legal_triples_upsert.sql` — DB UPSERT

운영 파이프라인 예: Cron → SQL 적용 → `legal_hierarchy` OTA 채널 배포.

---

## 6. 스테이징 → 운영 전환 체크리스트

### 인프라
- [ ] `validate_production_env.dart` 오류 0건
- [ ] `POSTGRES_PASSWORD` 예시값 교체
- [ ] TLS 종단 (로드밸런서·인증서)
- [ ] 방화벽: 8080 내부만, 외부는 443 Gateway

### 보안
- [ ] `NPA_IAM_JWT_MODE=claims` 이상
- [ ] API Gateway RS256·JWKS 연동
- [ ] `raw_text` 서버 전송 승인 (`kEnableRemoteResolve`)
- [ ] 감사 로그: `sub`·`station_id`·`jti` 보존

### 데이터
- [ ] `legal_nodes` 시드 26+ 노드 로드 확인
- [ ] `legal_triples` 백필·온톨로지 API 응답 확인
- [ ] 법제처 Cron 실키 연동 1회 성공

### 단말
- [ ] Android SM-S918N 실기기 회귀
- [ ] iOS 시뮬레이터/TestFlight 빌드 ([`ios_setup_guide.md`](ios_setup_guide.md))
- [ ] IAM JWT로 resolve 200 응답·로컬 fallback 동작

---

## 7. 장애·롤백

| 상황 | 조치 |
|------|------|
| JWT 401 | IAM iss/aud·만료·org_id 불일치 확인 |
| DB 연결 실패 | `DATABASE_URL`·compose 네트워크 |
| Cron 스텁만 동작 | `LAW_GO_KR_OC_KEY` 미설정 |
| 단말 원격 실패 | 자동 로컬 fallback — 서비스 중단 없음 |

롤백: `docker compose down` → 이전 이미지·시드 복원 → `kEnableRemoteResolve=false` 단말 플래그.

---

## 8. 담당자 연락·문서 맵

| 문서 | 내용 |
|------|------|
| [`s5_api_and_db.md`](s5_api_and_db.md) | REST API·S5 DDL |
| [`s6_ontology_and_production.md`](s6_ontology_and_production.md) | 온톨로지·IAM·Cron 상세 |
| [`deploy/README.md`](../deploy/README.md) | compose·env 빠른 시작 |
| [`ios_setup_guide.md`](ios_setup_guide.md) | iOS 빌드·권한 |

**개발 저장소 경로:** `C:\SGP-Agent`  
**검증 명령 일괄:**

```cmd
dart test test\features\agent\sgp_npa_iam_jwt_test.dart test\features\agent\sgp_legal_ontology_test.dart
dart run deploy/validate_production_env.dart deploy/quantum_legal_production.env.example
dart run tool/cron/sync_law_nodes_production.dart
```

---

*작성: SGP-Agent Phase 3 운영 킥오프 — S6 완료 기준*
