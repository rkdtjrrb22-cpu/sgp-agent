/// Docker·법제처 API 오프라인 스텁 플래그 (Flutter 비의존).
library;

/// Docker 미설치·법제처 키 미발급 환경에서 true 유지 (기본).
const bool kUseProductionStub = true;

/// 법령 Cron — 키 없을 때 오프라인 스텁 허용 (운영 전환 시 true로 변경).
const bool kLawSyncRequireLiveKey = false;
