# deploy/ — 프로덕션 Quantum Legal API 스택

## 파일

| 파일 | 설명 |
|------|------|
| `quantum_legal_production.env.example` | 환경 변수 템플릿 |
| `quantum_legal_production.env` | **로컬·서버 실제 값** (git 제외 권장) |
| `docker-compose.yml` | PostgreSQL 16 + Dart API |
| `validate_production_env.dart` | 배포 전 env 검증 |

## 빠른 시작

```cmd
cd C:\SGP-Agent\deploy
copy quantum_legal_production.env.example quantum_legal_production.env
REM quantum_legal_production.env 에 비밀번호·API 키 입력

cd ..
dart run deploy/validate_production_env.dart deploy/quantum_legal_production.env

cd deploy
docker compose up -d
curl http://127.0.0.1:8080/health
```

## NPA_IAM_JWT_MODE

| 값 | 용도 |
|----|------|
| `none` | 개발·PoC (payload만) |
| `claims` | **스테이징·운영 권장** — exp/iss/aud 검증 |
| `strict` | JWKS URL 필수 + API Gateway RS256 |

상세: [`docs/production_kickoff_guide.md`](../docs/production_kickoff_guide.md)
