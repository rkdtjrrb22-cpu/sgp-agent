# S5 — 서버 API · DB · JWT (Phase 2)

온디바이스 `SgpQuantumLegalEngine.analyze()` 결과와 1:1 호환되는 REST API·DB 초안.

## 1. POST /v1/quantum-legal/resolve

### Request

```json
{
  "actor": {
    "org_id": "KR-NPA",
    "local_gov_code": "11",
    "task_category": "field_arrest"
  },
  "situation": {
    "domain": "criminal",
    "raw_text": "서울 강남 쌍방 폭행 현장",
    "incident_type": "mutual_combat",
    "checklist": {
      "isWeaponUsed": false,
      "isDomesticViolence": false,
      "isIntoxicated": false,
      "isFleeing": false,
      "isSeizureConstraintReviewed": false
    }
  },
  "options": {
    "include_manuals": true,
    "strict_hierarchy": true
  }
}
```

| API 필드 | Dart (`SgpQuantumLegalComparison`) |
|----------|-------------------------------------|
| `situation.raw_text` | `analyze(rawText:)` |
| `situation.checklist` | `LawCheckList` |
| `actor.org_id` | `orgId` / `SgpOrgAccessGate` |
| `actor.local_gov_code` | `LegalHierarchyContext.localGovCode` |
| `perspectives` | `comparison.perspectives` |
| `recommendedPathId` | `comparison.recommendedPath?.id` |
| `action_guidance` | `comparison.actionGuidance` |
| `hierarchy` | `comparison.hierarchy` |
| `hierarchyGuidance` | `comparison.hierarchyGuidance` |
| `hierarchy_chain[]` | `hierarchy.chain` (API 편의 필드) |
| `conflicts[]` | `hierarchy.conflicts` (API 편의 필드) |

### Response (200)

`QuantumLegalResolveResponse.toJson()` — `schema_version`, `resolved_by`, `SgpQuantumLegalComparison` 필드 포함.

### JWT

`Authorization: Bearer <JWT>`

Payload 클레임 (필수: `org_id`):

```json
{
  "org_id": "KR-NPA",
  "local_gov_code": "11",
  "task_category": "field_arrest",
  "sub": "officer-session-id"
}
```

PoC 테스트 토큰 (서명 없음, payload만 검증):

```
eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJvcmdfaWQiOiJLUi1OUEEiLCJsb2NhbF9nb3ZfY29kZSI6IjExIiwidGFza19jYXRlZ29yeSI6ImZpZWxkX2FycmVzdCIsInN1YiI6InRlc3QifQ.
```

### cURL (참조 서버)

```cmd
dart run bin/quantum_legal_server.dart

curl -X POST http://127.0.0.1:8080/v1/quantum-legal/resolve ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJvcmdfaWQiOiJLUi1OUEEiLCJsb2NhbF9nb3ZfY29kZSI6IjExIiwidGFza19jYXRlZ29yeSI6ImZpZWxkX2FycmVzdCIsInN1YiI6InRlc3QifQ." ^
  -d "{\"actor\":{\"org_id\":\"KR-NPA\",\"local_gov_code\":\"11\"},\"situation\":{\"raw_text\":\"서울 교통사고 음주운전\"}}"
```

## 2. DB DDL (PostgreSQL 초안)

```sql
CREATE TABLE legal_nodes (
  id            TEXT PRIMARY KEY,
  level         SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 8),
  title         TEXT NOT NULL,
  parent_id     TEXT REFERENCES legal_nodes(id),
  scope         JSONB NOT NULL DEFAULT '{}',
  filter_keys   TEXT[] NOT NULL DEFAULT '{}',
  domain_tags   TEXT[] NOT NULL DEFAULT '{}',
  articles      TEXT[] NOT NULL DEFAULT '{}',
  linked_articles JSONB NOT NULL DEFAULT '[]',
  summary       TEXT,
  conflict_check BOOLEAN NOT NULL DEFAULT FALSE,
  source        TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_legal_nodes_level ON legal_nodes(level);
CREATE INDEX idx_legal_nodes_parent ON legal_nodes(parent_id);
CREATE INDEX idx_legal_nodes_scope ON legal_nodes USING GIN (scope);

CREATE TABLE actor_sessions (
  session_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          TEXT NOT NULL,
  local_gov_code  TEXT,
  task_category   TEXT NOT NULL DEFAULT 'field_arrest',
  jwt_sub         TEXT,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_actor_sessions_org ON actor_sessions(org_id);
```

## 3. Flutter 연동 (온디바이스)

| 모듈 | 역할 |
|------|------|
| `sgp_quantum_legal_api.dart` | Request/Response DTO, JWT 클레임 파싱 |
| `sgp_quantum_legal_remote.dart` | `resolveWithFallback()` — 원격 실패 시 로컬 |
| `sgp_legal_hierarchy_ota.dart` | 위계 시드 OTA (판례 OTA와 분리) |
| `sgp_legal_compliance.dart` | `kEnableRemoteResolve`, `kEnableLegalHierarchyOta` |

**기본값:** 두 플래그 모두 `false` (정통법·보안업무규정 — 승인 전 서버·OTA 비활성).

## 4. Cron PoC (법제처 LV1~4)

```cmd
dart run tool/cron/sync_law_nodes.dart assets/data/legal_hierarchy_seed.json assets/data/legal_hierarchy_seed.json
```

외부 JSON과 시드 diff → OTA 채널 배포 전 리포트.

## 5. 참조 서버

```cmd
cd C:\SGP-Agent
dart pub get
dart run bin/quantum_legal_server.dart
```

환경 변수: `PORT`, `SEED_PATH`
