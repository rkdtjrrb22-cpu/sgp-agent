/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Civil Non-Intervention Filter (Yellow Banner)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 단순 채무·임대차 등 민사불개입 사안 즉시 감지.
library;

/// 민사불개입 판정 결과.
class CivilNonInterventionHit {
  const CivilNonInterventionHit({
    required this.matched,
    required this.triggers,
    required this.bannerTitle,
    required this.bannerBody,
  });

  final bool matched;
  final List<String> triggers;
  final String bannerTitle;
  final String bannerBody;

  static const none = CivilNonInterventionHit(
    matched: false,
    triggers: [],
    bannerTitle: '',
    bannerBody: '',
  );
}

/// 「돈을 안 갚는다」「보증금을 안 돌려준다」 등 → Yellow 민사불개입.
abstract final class SgpCivilNonInterventionFilter {
  static final List<RegExp> _patterns = [
    RegExp(r'돈.{0,6}(안\s*)?갚'),
    RegExp(r'(안\s*)?갚.{0,4}돈'),
    RegExp(r'보증금.{0,8}(안\s*)?(돌|반환)'),
    RegExp(r'(안\s*)?(돌|반환).{0,6}보증금'),
    RegExp(r'임대차|전세금|월세.{0,6}(밀|안|분쟁)'),
    RegExp(r'빌려.{0,8}(안\s*)?갚'),
    RegExp(r'채무|채권.{0,6}독촉'),
    RegExp(r'단순\s*민사|민사\s*(사안|분쟁|불개입)'),
  ];

  /// 온톨로지 유형 ID가 민사 이관군인 경우도 배너 표시.
  static const civilTypeIds = {
    'CC-TYPE-CIVIL-DISPUTE',
  };

  static CivilNonInterventionHit evaluate(
    String rawText, {
    String? routedTypeId,
  }) {
    final text = rawText.trim();
    final triggers = <String>[];
    for (final p in _patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        triggers.add(m.group(0) ?? p.pattern);
      }
    }
    final byType = routedTypeId != null && civilTypeIds.contains(routedTypeId);
    if (triggers.isEmpty && !byType) {
      return CivilNonInterventionHit.none;
    }
    return CivilNonInterventionHit(
      matched: true,
      triggers: triggers.isEmpty ? ['유형: 단순 민사 분쟁'] : triggers,
      bannerTitle: '민사불개입 주의',
      bannerBody:
          '본 사안은 단순 채무·임대차·계약 분쟁으로 경찰이 강제력을 행사할 수 없는 '
          '민사 영역입니다. 법률구조공단(132)·관할 법원·지자체 민원실 안내를 우선하세요. '
          '폭행·협박·손괴가 동반된 경우에만 형사 병행 검토.',
    );
  }
}
