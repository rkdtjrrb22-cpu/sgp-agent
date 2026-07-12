-- Sprint S6 — legal_nodes → 온톨로지(SPO) 마이그레이션 DDL
-- PostgreSQL 14+
-- 선행: S5 legal_nodes·actor_sessions (없으면 아래 CREATE 실행)

CREATE TABLE IF NOT EXISTS legal_nodes (
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

CREATE INDEX IF NOT EXISTS idx_legal_nodes_level ON legal_nodes(level);
CREATE INDEX IF NOT EXISTS idx_legal_nodes_parent ON legal_nodes(parent_id);

CREATE TABLE IF NOT EXISTS actor_sessions (
  session_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          TEXT NOT NULL,
  local_gov_code  TEXT,
  task_category   TEXT NOT NULL DEFAULT 'field_arrest',
  jwt_sub         TEXT,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1) 기존 legal_nodes 유지 (엔티티·속성 노드)
--    parent_id는 하위 호환용으로 유지, 신규 관계는 legal_triples 우선.

-- 2) SPO 트리플 테이블
CREATE TABLE IF NOT EXISTS legal_triples (
  id            BIGSERIAL PRIMARY KEY,
  subject_id    TEXT NOT NULL REFERENCES legal_nodes(id) ON DELETE CASCADE,
  predicate     TEXT NOT NULL CHECK (predicate IN (
    'is_subordinate_to',
    'cites_article',
    'applies_to_domain',
    'conflicts_with',
    'governed_by',
    'derived_from',
    'has_jurisdiction',
    'requires_document'
  )),
  object_id     TEXT REFERENCES legal_nodes(id) ON DELETE SET NULL,
  object_value  TEXT,
  confidence    REAL NOT NULL DEFAULT 1.0 CHECK (confidence >= 0 AND confidence <= 1),
  source        TEXT,
  metadata      JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT legal_triples_object_check CHECK (
    object_id IS NOT NULL OR object_value IS NOT NULL
  ),
  CONSTRAINT legal_triples_unique_edge UNIQUE NULLS NOT DISTINCT (
    subject_id, predicate, object_id, object_value
  )
);

CREATE INDEX IF NOT EXISTS idx_legal_triples_subject ON legal_triples(subject_id);
CREATE INDEX IF NOT EXISTS idx_legal_triples_predicate ON legal_triples(predicate);
CREATE INDEX IF NOT EXISTS idx_legal_triples_object ON legal_triples(object_id);
CREATE INDEX IF NOT EXISTS idx_legal_triples_object_value ON legal_triples(object_value);

-- 3) 의미망 조회 뷰 (parent_id + triples 통합)
CREATE OR REPLACE VIEW legal_ontology_edges AS
SELECT
  n.id AS subject_id,
  'is_subordinate_to'::TEXT AS predicate,
  n.parent_id AS object_id,
  NULL::TEXT AS object_value,
  1.0::REAL AS confidence,
  'legacy_parent_id'::TEXT AS source
FROM legal_nodes n
WHERE n.parent_id IS NOT NULL
UNION ALL
SELECT
  t.subject_id,
  t.predicate,
  t.object_id,
  t.object_value,
  t.confidence,
  t.source
FROM legal_triples t;

-- 4) 경찰 IAM 세션 (S6 확장)
ALTER TABLE actor_sessions
  ADD COLUMN IF NOT EXISTS station_id TEXT,
  ADD COLUMN IF NOT EXISTS dept_code TEXT,
  ADD COLUMN IF NOT EXISTS rank_code TEXT,
  ADD COLUMN IF NOT EXISTS jwt_iss TEXT,
  ADD COLUMN IF NOT EXISTS jwt_aud TEXT,
  ADD COLUMN IF NOT EXISTS jwt_jti TEXT;

CREATE INDEX IF NOT EXISTS idx_actor_sessions_station ON actor_sessions(station_id);

-- 5) legal_nodes → legal_triples 일회성 백필 (parent_id)
INSERT INTO legal_triples (subject_id, predicate, object_id, source)
SELECT id, 'is_subordinate_to', parent_id, 'migration_s6_parent_id'
FROM legal_nodes
WHERE parent_id IS NOT NULL
ON CONFLICT (subject_id, predicate, object_id, object_value) DO NOTHING;

-- 6) linked_articles JSONB → cites_article 트리플 백필
INSERT INTO legal_triples (subject_id, predicate, object_id, object_value, source)
SELECT
  n.id,
  'cites_article',
  (link->>'upper_node_id')::TEXT,
  (link->>'article')::TEXT,
  'migration_s6_linked_articles'
FROM legal_nodes n,
     jsonb_array_elements(n.linked_articles) AS link
WHERE jsonb_array_length(n.linked_articles) > 0
ON CONFLICT (subject_id, predicate, object_id, object_value) DO NOTHING;

-- 7) domain_tags → applies_to_domain 백필
INSERT INTO legal_triples (subject_id, predicate, object_value, source)
SELECT
  n.id,
  'applies_to_domain',
  unnest(n.domain_tags),
  'migration_s6_domain_tags'
FROM legal_nodes n
WHERE array_length(n.domain_tags, 1) > 0
ON CONFLICT (subject_id, predicate, object_id, object_value) DO NOTHING;

-- 8) S7-A — 5단계 물리력 매트릭스 (MANUAL-SGP-FORCE-MATRIX, PF-STAGE-1..5)
--    assets/data/legal_hierarchy_seed.json 과 동기화. Cron 산출물 UPSERT 권장.
