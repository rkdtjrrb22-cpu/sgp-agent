/// STT 음성 → 법리 변수 자동 연동 (미란다 고지 등) — 데이터 바인딩 뼈대.
library;

import 'sgp_agent_law_filters.dart';

/// STT 텍스트에서 감지된 음성-법리 매칭 결과.
class VoiceLegalMatchResult {
  const VoiceLegalMatchResult({
    this.mirandaAdvised = false,
    this.matchedKeywords = const [],
    this.highlightFields = const {},
    this.autoCheckFields = const {},
  });

  /// 미란다(묵비권·변호인) 고지 음성 매칭.
  final bool mirandaAdvised;

  /// 매칭된 키워드 목록.
  final List<String> matchedKeywords;

  /// 카드 테두리 하이라이트 대상 (자동 V 체크 없음 — 수기 모드 기본).
  final Set<LawChecklistField> highlightFields;

  /// 자동 체크 대상 (향후 STT 자동 모드에서 활성화).
  final Set<LawChecklistField> autoCheckFields;

  static const empty = VoiceLegalMatchResult();
}

/// 미란다·절차 고지 STT 키워드 매칭.
abstract final class SgpVoiceLegalBinder {
  static const _mirandaKeywords = [
    '미란다',
    'miranda',
    '묵비권',
    '묵비',
    '변호인',
    '변호사',
    '고지',
    '진술 거부',
    '자백',
  ];

  /// rawText/STT 전사문에서 음성-법리 바인딩 분석.
  ///
  /// [enableAutoCheck] — true 시 [autoCheckFields]에 따라 체크박스 자동 토글.
  /// 현장 기본은 false(수기 확인 모드).
  static VoiceLegalMatchResult analyze(
    String rawText, {
    bool enableAutoCheck = false,
  }) {
    final normalized = rawText.trim().toLowerCase();
    if (normalized.isEmpty) return VoiceLegalMatchResult.empty;

    final hits = <String>[];
    for (final kw in _mirandaKeywords) {
      if (normalized.contains(kw.toLowerCase())) hits.add(kw);
    }

    if (hits.isEmpty) return VoiceLegalMatchResult.empty;

    const highlight = {LawChecklistField.fleeing};
    return VoiceLegalMatchResult(
      mirandaAdvised: true,
      matchedKeywords: hits,
      highlightFields: highlight,
      autoCheckFields: enableAutoCheck ? highlight : const {},
    );
  }
}
