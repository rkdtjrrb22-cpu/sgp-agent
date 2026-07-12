# S6 — 온톨로지·프로덕션 배포 (Phase 3)

S5 REST API·DB를 **SPO 온톨로지 의미망**으로 확장하고, **경찰 IAM JWT**·**법제처 실연동 Cron**·**프로덕션 배포** 준비를 반영한다.

## 1. 온톨로지 모델 (legal_nodes → legal_triples)

### Predicate (관계 유형)

| predicate | 의미 | 기존 필드 매핑 |
|-----------|------|----------------|
| `is_subordinate_to` | 하위법 → 상위법 | `parent_id` |
| `cites_article` | 조문 인용·준거 | `linked_articles[]` |
| `applies_to_domain` | 도메인 태그 | `domain_tags[]` |
| `governed_by` | LV7~8 상위법 준거 | `linked_articles[]` |
| `conflicts_with` | 상위법 충돌 후보 | `conflict_check` |
| `derived_from` | 파싱·시드 출처 | `source` |

### SPO 예시

```json
{
  "subject_id": "KR-NPA-MANUAL-ARREST",
  "predicate": "cites_article",
  "object_id": "KR-LAW-CRIM-PROC",
  "object_value": "제212조",
  "confidence": 1.0,
  "source": "ingest_pipeline"
}
```

### DB DDL

`sql/s6_ontology_ddl.sql` — `legal_triples` 테이블, `legal_ontology_edges` 뷰, S5→S6 백필 INSERT.

```cmd
psql %DATABASE_URL% -f sql\s6_ontology_ddl.sql
```

## 2. API 확장 (schema 1.1)

### 기존 (S5)

- `POST /v1/quantum-legal/resolve` — 응답에 `ontology_context` 추가 (schema `1.1`)

### 신규 (S6)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/v1/legal-ontology/graph` | 전체 그래프 (`?root_id=&depth=` 서브그래프) |
| POST | `/v1/legal-ontology/triples/query` | SPO 조건 검색·BFS 서브그래프 |
| GET | `/v1/legal-ontology/migrate/preview` | nodes→triples 마이그레이션 미리보기 |

### POST /v1/legal-ontology/triples/query

```json
{
  "subject_id": "KR-LAW-CRIM-PROC",
  "predicate": "cites_article",
  "root_subject_id": "KR-CONST-001",
  "max_depth": 3
}
```

### resolve 응답 ontology_context

```json
{
  "schema_version": "1.1",
  "ontology_context": {
    "chain_node_ids": ["KR-CONST-001", "KR-LAW-CRIMINAL", "..."],
    "related_triples": [ { "subject_id": "...", "predicate": "...", ... } ]
  }
}
```

## 3. 경찰 IAM JWT 실무 연동

### 클레임 규격 (초안)

```json
{
  "iss": "https://iam.police.go.kr",
  "aud": "sgp-agent-api",
  "sub": "officer-uuid",
  "exp": 1735689600,
  "iat": 1735686000,
  "org_id": "KR-NPA",
  "local_gov_code": "11",
  "station_id": "1140000",
  "dept_code": "CID",
  "rank_code": "PO",
  "task_category": "field_arrest",
  "jti": "unique-token-id"
}
```

### 검증 모드 (`NPA_IAM_JWT_MODE`)

| 모드 | 동작 |
|------|------|
| `none` | S5 PoC — payload 파싱·org_id만 (기본) |
| `claims` | exp·iss·aud·nbf 검증 |
| `strict` | claims + `NPA_IAM_JWKS_URL` 필수 (RS256은 API Gateway 위임) |

### 환경 변수

```
NPA_IAM_JWT_MODE=claims
NPA_IAM_ISSUER=https://iam.police.go.kr
NPA_IAM_AUDIENCE=sgp-agent-api
NPA_IAM_JWKS_URL=https://iam.police.go.kr/.well-known/jwks.json
```

### Dart 모듈

- `sgp_npa_iam_jwt.dart` — `NpaIamClaims`, `NpaIamJwtVerifier`
- `bin/quantum_legal_server.dart` — IAM 모드별 authorize

## 4. 프로덕션 Cron (법제처·공공데이터)

### 환경 변수

```
LAW_GO_KR_OC_KEY=<국가법령정보센터 OC>
DATA_GO_KR_SERVICE_KEY=<공공데이터포털 서비스키>
OUTPUT_PATH=build/legal_nodes_sync.json
SQL_OUTPUT_PATH=build/legal_triples_upsert.sql
```

### 실행

```cmd
dart run tool/cron/sync_law_nodes_production.dart
```

- 키 미설정 시 **오프라인 스텁**으로 diff·SQL 생성 (CI·개발용)
- 키 설정 시 `law.go.kr/DRF/lawSearch.do` 실조회 → `legal_nodes` 병합 → `legal_triples` UPSERT SQL 출력

### S5 PoC (유지)

```cmd
dart run tool/cron/sync_law_nodes.dart [seed] [incoming]
```

## 5. 프로덕션 배포

```cmd
cd deploy
copy quantum_legal_production.env.example quantum_legal_production.env
docker compose up -d
```

- PostgreSQL 16 + `s6_ontology_ddl.sql` 자동 적용
- Dart 참조 API (`quantum-legal-api` 서비스)

### cURL (온톨로지 그래프)

```cmd
dart run bin/quantum_legal_server.dart

curl http://127.0.0.1:8080/v1/legal-ontology/graph?root_id=KR-CONST-001^&depth=2 ^
  -H "Authorization: Bearer <JWT>"
```

## 6. Flutter 연동

| 모듈 | 역할 |
|------|------|
| `sgp_legal_ontology.dart` | SPO 모델·Migrator·Graph |
| `sgp_legal_ontology_api.dart` | REST DTO·resolve ontology_context |
| `sgp_npa_iam_jwt.dart` | 경찰 IAM JWT 검증 (서버·테스트) |

온디바이스 기본 동작은 S5와 동일. 원격 resolve 시 schema 1.1 `ontology_context` 수신 가능.

## 7. 검증

```cmd
dart test test\features\agent\sgp_legal_ontology_test.dart test\features\agent\sgp_npa_iam_jwt_test.dart
dart test test\features\agent\sgp_legal_hierarchy_test.dart test\features\agent\sgp_quantum_legal_api_test.dart
dart run deploy/validate_production_env.dart deploy/quantum_legal_production.env.example
dart run tool/cron/sync_law_nodes_production.dart
dart run bin/quantum_legal_server.dart
```

**운영 킥오프:** [`docs/production_kickoff_guide.md`](production_kickoff_guide.md)  
**iOS 빌드:** [`docs/ios_setup_guide.md`](ios_setup_guide.md)
