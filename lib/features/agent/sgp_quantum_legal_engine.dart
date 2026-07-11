/// 양자적(다관점) 법률 비교 엔진 — 형법 vs 특별법 vs 민사 경로.
library;

import 'sgp_agent_core.dart';
import 'sgp_court_precedents_ota.dart';
import 'sgp_legal_hierarchy.dart';
import 'sgp_procedure_timeline.dart';

/// 현장 긴급도 (UI 컬러 매핑).
enum SgpUrgencyLevel {
  safe,
  caution,
  critical,
}

extension SgpUrgencyLevelColors on SgpUrgencyLevel {
  String get label => switch (this) {
        SgpUrgencyLevel.safe => '안전',
        SgpUrgencyLevel.caution => '주의',
        SgpUrgencyLevel.critical => '위험',
      };
}

/// 사건 유형.
enum IncidentType {
  general,
  dogBiteIncident,
  domesticViolence,
  stalking,
  mutualCombat,
  trafficIncident,
  roadOccupancy,
  civilDispute,
}

extension IncidentTypeLabel on IncidentType {
  String get jsonKey => switch (this) {
        IncidentType.general => 'general',
        IncidentType.dogBiteIncident => 'dog_bite_incident',
        IncidentType.domesticViolence => 'domestic_violence',
        IncidentType.stalking => 'stalking',
        IncidentType.mutualCombat => 'mutual_combat',
        IncidentType.trafficIncident => 'traffic_incident',
        IncidentType.roadOccupancy => 'road_occupancy',
        IncidentType.civilDispute => 'civil_dispute',
      };

  /// 보고서·UI 표기용 한글 명칭.
  String get displayLabel => switch (this) {
        IncidentType.general => '일반 형사 사건',
        IncidentType.dogBiteIncident => '반려견·맹견 교상 사고',
        IncidentType.domesticViolence => '가정폭력',
        IncidentType.stalking => '스토킹',
        IncidentType.mutualCombat => '쌍방 폭행',
        IncidentType.trafficIncident => '교통사고·도로교통법 위반',
        IncidentType.roadOccupancy => '도로 점유·도로법 위반',
        IncidentType.civilDispute => '민사 분쟁 연계',
      };
}

/// 법률 관점 (양자적 비교 카드 1장).
class LegalPerspective {
  const LegalPerspective({
    required this.id,
    required this.kind,
    required this.law,
    required this.attribute,
    required this.weightScore,
    this.risk,
    this.condition,
    this.recommended = false,
    this.precedentGuide,
  });

  final String id;
  final String kind;
  final String law;
  final String attribute;
  final double weightScore;
  final String? risk;
  final String? condition;
  final bool recommended;

  /// CoT 추론 후 카드 하단 [핵심 판례 가이드] 텍스트.
  final String? precedentGuide;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'law': law,
        'attribute': attribute,
        'weightScore': weightScore,
        'risk': risk,
        'condition': condition,
        'recommended': recommended,
        'precedentGuide': precedentGuide,
      };

  factory LegalPerspective.fromJson(Map<String, dynamic> json) {
    return LegalPerspective(
      id: json['id'] as String,
      kind: json['kind'] as String,
      law: json['law'] as String,
      attribute: json['attribute'] as String,
      weightScore: (json['weightScore'] as num).toDouble(),
      risk: json['risk'] as String?,
      condition: json['condition'] as String?,
      recommended: json['recommended'] as bool? ?? false,
      precedentGuide: json['precedentGuide'] as String?,
    );
  }
}

/// 양자적 법률 비교 결과.
class SgpQuantumLegalComparison {
  const SgpQuantumLegalComparison({
    required this.incidentType,
    required this.perspectives,
    required this.recommendedPath,
    required this.actionGuidance,
    required this.urgencyLevel,
    required this.appliedTrendIds,
    required this.summary,
    required this.hasLegalConflict,
    this.hierarchy,
    this.hierarchyGuidance,
  });

  final IncidentType incidentType;
  final List<LegalPerspective> perspectives;
  final LegalPerspective? recommendedPath;
  final String actionGuidance;
  final SgpUrgencyLevel urgencyLevel;
  final List<String> appliedTrendIds;
  final String summary;
  final bool hasLegalConflict;

  /// Sprint S1 — 8단계 법적 위계 Top-Down 체인.
  final SgpHierarchyResolution? hierarchy;

  /// Sprint S2 — Cross-Filter·상위법 우선 가이드.
  final SgpHierarchyResolvedGuidance? hierarchyGuidance;

  Map<String, dynamic> toJson() => {
        'incidentType': incidentType.jsonKey,
        'perspectives': perspectives.map((p) => p.toJson()).toList(),
        'recommendedPathId': recommendedPath?.id,
        'actionGuidance': actionGuidance,
        'urgencyLevel': urgencyLevel.name,
        'appliedTrendIds': appliedTrendIds,
        'summary': summary,
        'hasLegalConflict': hasLegalConflict,
        if (hierarchy != null) 'hierarchy': hierarchy!.toJson(),
        if (hierarchyGuidance != null) 'hierarchyGuidance': hierarchyGuidance!.toJson(),
      };

  factory SgpQuantumLegalComparison.fromJson(Map<String, dynamic> json) {
    final perspectives = (json['perspectives'] as List<dynamic>? ?? [])
        .map((e) => LegalPerspective.fromJson(e as Map<String, dynamic>))
        .toList();
    final recId = json['recommendedPathId'] as String?;
    final hierarchyJson = json['hierarchy'];
    final hierarchyGuidanceJson = json['hierarchyGuidance'];
    return SgpQuantumLegalComparison(
      incidentType: IncidentType.values.firstWhere(
        (t) => t.jsonKey == json['incidentType'],
        orElse: () => IncidentType.general,
      ),
      perspectives: perspectives,
      recommendedPath: perspectives.where((p) => p.id == recId).firstOrNull,
      actionGuidance: json['actionGuidance'] as String? ?? '',
      urgencyLevel: SgpUrgencyLevel.values.byName(
        json['urgencyLevel'] as String? ?? SgpUrgencyLevel.caution.name,
      ),
      appliedTrendIds:
          (json['appliedTrendIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      summary: json['summary'] as String? ?? '',
      hasLegalConflict: json['hasLegalConflict'] as bool? ?? false,
      hierarchy: hierarchyJson is Map<String, dynamic>
          ? SgpHierarchyResolution.fromJson(hierarchyJson)
          : null,
      hierarchyGuidance: hierarchyGuidanceJson is Map<String, dynamic>
          ? SgpHierarchyResolvedGuidance.fromJson(hierarchyGuidanceJson)
          : null,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

/// 양자적 법률 비교 엔진.
class SgpQuantumLegalEngine {
  const SgpQuantumLegalEngine._();

  static final _dogKw = RegExp(r'(개|견|맹견|진돗개|반려견|견주|물어|교상|목줄|입마개)');
  static final _dvKw = RegExp(r'(가정폭력|남편|아내|가족|신고)');
  static final _stalkKw = RegExp(r'(스토킹|따라|잠복|감시|연락)');
  static final _mutualKw = RegExp(r'(쌍방|서로|맞붙)');
  static final _noLeashKw = RegExp(r'(목줄\s*없|미착용|풀어놓|입마개\s*없)');
  static final _trafficKw = RegExp(
    r'(교통|신호|음주운전|운전|과속|신호위반|추돌|차량|교차로|횡단보도|적색|녹색|도로교통)',
  );
  static final _roadKw = RegExp(
    r'(도로법|불법\s*점용|도로\s*침범|공작물|공사\s*장|점유|도로\s*점유)',
  );
  static final _civilKw = RegExp(
    r'(손해배상|가압류|민사|소송|지급명령|조정|내용증명|민사소송)',
  );

  static SgpQuantumLegalComparison analyze({
    required String rawText,
    required LawCheckList checklist,
    RuleMatchResult? ruleResult,
    SgpAdvancedAnalysis? advancedAnalysis,
    SgpProcedureTimeline? timeline,
    List<CourtPrecedentTrend>? trends,
    String? orgId,
  }) {
    final text = rawText.trim();
    final incident = _detectIncident(text, checklist);
    final activeTrends = trends ??
        SgpCourtPrecedentsOta.instance.matchTrends(
          text: text,
          incidentScope: incident.jsonKey,
        );

    final perspectives = _buildPerspectives(incident, text, checklist, activeTrends);
    final scored = _applyTrendWeights(perspectives, activeTrends, incident);
    scored.sort((a, b) => b.weightScore.compareTo(a.weightScore));

    final top = scored.isNotEmpty ? scored.first : null;
    final second = scored.length > 1 ? scored[1] : null;
    final conflict = top != null &&
        second != null &&
        (top.weightScore - second.weightScore).abs() < 0.12;

    final marked = scored
        .map((p) => p.copyWith(recommended: p.id == top?.id))
        .toList();

    final urgency = _resolveUrgency(
      incident: incident,
      conflict: conflict,
      advancedAnalysis: advancedAnalysis,
      timeline: timeline,
      text: text,
    );

    final guidance = _actionGuidance(
      incident: incident,
      recommended: top,
      text: text,
      checklist: checklist,
      urgency: urgency,
    );

    final hierarchy = _resolveHierarchy(incident, checklist, text, orgId);
    final (finalPerspectives, finalGuidance, hierarchyGuidance) =
        _applyHierarchyGuidance(hierarchy, marked, guidance);
    final finalTop = finalPerspectives.where((p) => p.recommended).firstOrNull;

    return SgpQuantumLegalComparison(
      incidentType: incident,
      perspectives: finalPerspectives,
      recommendedPath: finalTop,
      actionGuidance: finalGuidance,
      urgencyLevel: urgency,
      appliedTrendIds: activeTrends.map((t) => t.id).toList(),
      summary: _buildSummary(incident, finalTop, conflict),
      hasLegalConflict: conflict || (hierarchy?.hasUpperLawWarnings ?? false),
      hierarchy: hierarchy,
      hierarchyGuidance: hierarchyGuidance,
    );
  }

  static (List<LegalPerspective>, String, SgpHierarchyResolvedGuidance?) _applyHierarchyGuidance(
    SgpHierarchyResolution? hierarchy,
    List<LegalPerspective> perspectives,
    String baseGuidance,
  ) {
    if (hierarchy == null || hierarchy.isEmpty) {
      return (perspectives, baseGuidance, null);
    }

    final refs = perspectives
        .map((p) => HierarchyPerspectiveRef(
              id: p.id,
              kind: p.kind,
              law: p.law,
              weightScore: p.weightScore,
            ))
        .toList();

    final resolved = HierarchyConflictResolver.resolve(
      hierarchy: hierarchy,
      perspectives: refs,
      baseActionGuidance: baseGuidance,
    );

    final demoted = resolved.demotedPerspectiveIds.toSet();
    final adjusted = perspectives.map((p) {
      if (!demoted.contains(p.id)) return p;
      return p.copyWith(weightScore: p.weightScore * 0.45, recommended: false);
    }).toList();

    adjusted.sort((a, b) => b.weightScore.compareTo(a.weightScore));
    final reMarked = [
      for (var i = 0; i < adjusted.length; i++)
        adjusted[i].copyWith(recommended: i == 0 && !demoted.contains(adjusted[i].id)),
    ];

    return (reMarked, resolved.actionGuidance, resolved);
  }

  static SgpHierarchyResolution? _resolveHierarchy(
    IncidentType incident,
    LawCheckList checklist,
    String text,
    String? orgId,
  ) {
    if (!SgpLegalHierarchyRegistry.instance.isLoaded) return null;

    final domainTags = {...domainTagsForIncidentKey(incident.jsonKey)};
    if (checklist.isDomesticViolence) domainTags.add('domestic_violence');
    if (checklist.isSeizureConstraintReviewed) domainTags.add('procedure');

    // Sprint S4 — 조직 미프로비저닝(orgId=null) 시 LV7~8 조직 규정·매뉴얼 제외.
    final includeOrgManual = orgId != null;

    final anchors = SgpLegalHierarchyEngine.inferAnchorIds(
      domainTags: domainTags,
      includeProcedure: true,
      includeEvidence: RegExp(r'(채증|녹화|바디캠|고지)').hasMatch(text),
      includeOrgManual: includeOrgManual,
    );

    return SgpLegalHierarchyEngine.resolve(
      context: LegalHierarchyContext(
        orgId: orgId,
        taskCategory: 'field_arrest',
        localGovCode: inferLocalGovCodeFromText(text),
        domainTags: domainTags,
      ),
      anchorNodeIds: anchors,
    );
  }

  static IncidentType _detectIncident(String text, LawCheckList checklist) {
    if (_dogKw.hasMatch(text)) return IncidentType.dogBiteIncident;
    if (_trafficKw.hasMatch(text)) return IncidentType.trafficIncident;
    if (_roadKw.hasMatch(text)) return IncidentType.roadOccupancy;
    if (_civilKw.hasMatch(text)) return IncidentType.civilDispute;
    if (_stalkKw.hasMatch(text)) return IncidentType.stalking;
    if (checklist.isDomesticViolence || _dvKw.hasMatch(text)) {
      return IncidentType.domesticViolence;
    }
    if (_mutualKw.hasMatch(text)) return IncidentType.mutualCombat;
    return IncidentType.general;
  }

  static List<LegalPerspective> _buildPerspectives(
    IncidentType incident,
    String text,
    LawCheckList checklist,
    List<CourtPrecedentTrend> trends,
  ) {
    switch (incident) {
      case IncidentType.dogBiteIncident:
        final safetyViolation = _noLeashKw.hasMatch(text) ||
            text.contains('목줄 없') ||
            text.contains('입마개');
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: '형법 제266조 (과실치상)',
            attribute: '반의사불벌죄 (피해자 처벌불원 시 공소권 없음)',
            weightScore: safetyViolation ? 0.42 : 0.55,
            risk: '피의자 합의 종용으로 인한 피해자 2차 피해 우려',
            precedentGuide:
                '피해자의 처벌불원의사 확인 시 반의사불벌죄 원칙에 의거 공소권 없음 처분 경로 확인.',
          ),
          LegalPerspective(
            id: 'perspective_B_special',
            kind: 'special',
            law: '동물보호법 제97조 (소유자등 관리의무 위반 상해)',
            attribute: '비(非)반의사불벌죄 (합의 여부 불문 처벌)',
            weightScore: safetyViolation ? 0.88 : 0.62,
            condition: '목줄·입마개 등 법정 안전조치 미이행 요건 충족 시 즉시 트리거',
            precedentGuide:
                '대법원 20XX도XXXX: 맹견 목줄 미착용 상태의 주거지 이탈은 소유자의 관리의무 위반 기수 인정.',
          ),
          LegalPerspective(
            id: 'perspective_C_civil',
            kind: 'civil',
            law: '민법 제759조 (동물의 점유자 책임)',
            attribute: '민사상 손해배상·치료비 청구 영역',
            weightScore: 0.35,
            risk: '형사·민사 병행 안내 필요',
          ),
        ];
      case IncidentType.domesticViolence:
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: '형법 제260조·제261조 (폭행·상해)',
            attribute: '반의사불벌죄 (피해자 고소 필요)',
            weightScore: 0.48,
          ),
          LegalPerspective(
            id: 'perspective_B_special',
            kind: 'special',
            law: '가정폭력처벌법 (긴급응급조치·임시조치)',
            attribute: '비반의사불벌·즉시 분리·보호 조치',
            weightScore: 0.82,
            condition: '가족·동거 관계 시 특별법 우선 검토',
          ),
        ];
      case IncidentType.stalking:
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: '형법 제283조 (협박) 등',
            attribute: '반의사불벌죄 해당 가능',
            weightScore: 0.45,
          ),
          LegalPerspective(
            id: 'perspective_B_special',
            kind: 'special',
            law: '스토킹처벌법',
            attribute: '비반의사불벌·긴급응급조치·전자장치',
            weightScore: 0.85,
          ),
        ];
      case IncidentType.mutualCombat:
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: '형법 제260조 (폭행) — 쌍방 입건',
            attribute: '쌍방 과잉 입건 위험',
            weightScore: 0.40,
            risk: '기계적 쌍방 처벌 시비',
            precedentGuide:
                '대법원: 선제 공격·흉기 주도권·침해의 현재성 요건으로 실질 가해자 구분.',
          ),
          LegalPerspective(
            id: 'perspective_B_special',
            kind: 'criminal',
            law: '형법 제21조 (정당방위) + 판례 요건',
            attribute: '선제 공격·흉기 주도권으로 실질 가해자 구분',
            weightScore: 0.72,
            condition: trends.any((t) => t.id.contains('self_defense')) ? '정당방위 완화 추세 반영' : null,
            precedentGuide:
                '정당방위 — 부당한 침해의 현재성·상당성·방어 의사를 순차 검토.',
          ),
        ];
      case IncidentType.trafficIncident:
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: '도로교통법 (음주운전·신호위반 등)',
            attribute: '행정·형사 병행 — 면허 취소·벌금·구속영장',
            weightScore: RegExp(r'(음주|만취|혈중)').hasMatch(text) ? 0.85 : 0.62,
            precedentGuide:
                '대법원: 음주운전 혈중알코올 0.08% 이상 시 형사 처벌·면허 취소 병행.',
          ),
          LegalPerspective(
            id: 'perspective_B_special',
            kind: 'special',
            law: '특정범죄가중처벌법 (어린이·보호구역)',
            attribute: '어린이 보호구역·스쿨존 가중처벌 검토',
            weightScore: RegExp(r'(스쿨존|어린이|보호구역)').hasMatch(text) ? 0.78 : 0.45,
            condition: '보호구역 내 사고 시 가중 요건 확인',
            precedentGuide:
                '어린이 보호구역 내 사고 — 특가법 가중·현장 CCTV·블랙박스 확보.',
          ),
          LegalPerspective(
            id: 'perspective_C_civil',
            kind: 'civil',
            law: '민법 제750조 (불법행위 손해배상)',
            attribute: '피해자 치료비·휴업손해·위자료 청구',
            weightScore: 0.38,
            precedentGuide:
                '교통사고 — 보험사·과실비율·합의 절차 병행 안내.',
          ),
        ];
      case IncidentType.roadOccupancy:
        return [
          LegalPerspective(
            id: 'perspective_A_admin',
            kind: 'administrative',
            law: '도로법 제61조·제44조 (도로 점유·공작물)',
            attribute: '불법 점용·공작물 설치 — 행정처분·원상회복',
            weightScore: 0.72,
            precedentGuide:
                '도로법: 허가 없는 점유·공작물 설치 시 시·군·구청 이행강제금·원상회복.',
          ),
          LegalPerspective(
            id: 'perspective_B_criminal',
            kind: 'criminal',
            law: '형법 제347조 (공무방해) 등',
            attribute: '공무집행 방해·폭력 수반 시 형사 입건',
            weightScore: RegExp(r'(폭력|공무|방해)').hasMatch(text) ? 0.68 : 0.35,
            precedentGuide:
                '원상회복 명령 불이행 + 폭력 — 공무방해·특수폭행 경로 검토.',
          ),
        ];
      case IncidentType.civilDispute:
        return [
          LegalPerspective(
            id: 'perspective_A_civil',
            kind: 'civil',
            law: '민사소송법 (지급명령·가압류·가처분)',
            attribute: '피해자 권리구제 — 민사 절차 우선 안내',
            weightScore: 0.70,
            precedentGuide:
                '민사소송법: 손해배상 청구·가압류·가처분으로 재산 보전 절차 안내.',
          ),
          LegalPerspective(
            id: 'perspective_B_criminal',
            kind: 'criminal',
            law: '형법 (사기·횡령·폭행 등)',
            attribute: '범죄 성립 시 형사 경로 병행',
            weightScore: RegExp(r'(사기|횡령|폭행|협박)').hasMatch(text) ? 0.65 : 0.40,
            precedentGuide:
                '형사·민사 병행 가능 — 고소장 접수·증거 보전 동시 검토.',
          ),
        ];
      case IncidentType.general:
        return [
          LegalPerspective(
            id: 'perspective_A_criminal',
            kind: 'criminal',
            law: checklist.isWeaponUsed ? '형법 특수폭행·상해' : '형법 폭행·상해',
            attribute: checklist.isWeaponUsed
                ? '반의사불벌죄 배제 (합의 불문 처벌 가능)'
                : '반의사불벌죄 해당 여부 확인',
            weightScore: 0.58,
          ),
          if (checklist.isDomesticViolence)
            LegalPerspective(
              id: 'perspective_B_special',
              kind: 'special',
              law: '가정폭력처벌법',
              attribute: '피해자 보호·분리 조치 우선',
              weightScore: 0.75,
            ),
          if (checklist.isIntoxicated)
            LegalPerspective(
              id: 'perspective_C_admin',
              kind: 'administrative',
              law: '형법 제10조 3항 (자의적 행위)',
              attribute: '주취감경 주장 제한 — 심신미약 감경 배제 검토',
              weightScore: 0.68,
              risk: '자의적 음주 시 감경 사유 제한 (대법원)',
            ),
        ];
    }
  }

  static List<LegalPerspective> _applyTrendWeights(
    List<LegalPerspective> perspectives,
    List<CourtPrecedentTrend> trends,
    IncidentType incident,
  ) {
    return perspectives.map((p) {
      var boost = 0.0;
      for (final t in trends) {
        if (p.kind == 'special' && t.appliesTo.contains('special')) {
          boost += t.weightBoost;
        } else if (p.kind == 'criminal' && t.appliesTo.contains('criminal')) {
          boost += t.weightBoost * 0.5;
        } else if (t.appliesTo.contains(incident.jsonKey)) {
          boost += t.weightBoost;
        }
      }
      return p.copyWith(weightScore: (p.weightScore + boost).clamp(0.0, 1.0));
    }).toList();
  }

  static SgpUrgencyLevel _resolveUrgency({
    required IncidentType incident,
    required bool conflict,
    SgpAdvancedAnalysis? advancedAnalysis,
    SgpProcedureTimeline? timeline,
    required String text,
  }) {
    if (advancedAnalysis?.hasCriticalProceduralAlert == true) {
      return SgpUrgencyLevel.critical;
    }
    if (timeline?.hasCriticalDeadline == true) {
      return SgpUrgencyLevel.critical;
    }
    if (incident == IncidentType.dogBiteIncident &&
        RegExp(r'(맹견|목숨|의식|쇼크|대동맥)').hasMatch(text)) {
      return SgpUrgencyLevel.critical;
    }
    if (conflict) return SgpUrgencyLevel.caution;
    if (timeline != null) {
      final immediateDone = timeline.nodes
          .where((n) => kImmediatePhaseNodeIds.contains(n.id))
          .every((n) => n.checkItems.every((c) => c.checked));
      if (immediateDone) return SgpUrgencyLevel.safe;
    }
    return SgpUrgencyLevel.caution;
  }

  static String _actionGuidance({
    required IncidentType incident,
    LegalPerspective? recommended,
    required String text,
    required LawCheckList checklist,
    required SgpUrgencyLevel urgency,
  }) {
    if (urgency == SgpUrgencyLevel.critical) {
      return '【긴급】 위수증·시한·인명 위험 — 절차 마감 및 안전조치 즉시 이행';
    }
    if (incident == IncidentType.dogBiteIncident) {
      if (_noLeashKw.hasMatch(text) || text.contains('목줄 없')) {
        return '지금 즉시 견주 안전조치 위반 채증 — 동물보호법 제97조 적용 검토';
      }
      return '견주·견 분리 후 상해 정도·안전조치 이행 여부 기록';
    }
    if (incident == IncidentType.trafficIncident) {
      return '교통사고 — 도로교통법·특가법·민사 손해배상 경로 동시 검토';
    }
    if (incident == IncidentType.roadOccupancy) {
      return '도로 점유·공작물 — 도로법 행정처분 + 형사 병행 여부 확인';
    }
    if (incident == IncidentType.civilDispute) {
      return '민사 분쟁 — 민사소송법 절차 안내 + 형사 성립 시 병행';
    }
    if (recommended != null) {
      return '권장 경로: ${recommended.law} — ${recommended.attribute}';
    }
    return '양자적 법률 경합 — 수사관 자기판단으로 최적 경로 확정';
  }

  static String _buildSummary(
    IncidentType incident,
    LegalPerspective? top,
    bool conflict,
  ) {
    final base = switch (incident) {
      IncidentType.dogBiteIncident => '반려견·맹견 사고 — 형법 과실치상 vs 동물보호법 비교',
      IncidentType.domesticViolence => '가정폭력 — 형법 vs 가정폭력처벌법 경합',
      IncidentType.stalking => '스토킹 — 협박죄 vs 스토킹처벌법',
      IncidentType.mutualCombat => '쌍방 폭행 — 정당방위·선제공격 판례 대조',
      IncidentType.trafficIncident => '교통사고 — 도로교통법·특가법·민사 손해배상',
      IncidentType.roadOccupancy => '도로 점유 — 도로법 행정처분 vs 형사',
      IncidentType.civilDispute => '민사 분쟁 — 민사소송법 vs 형사 병행',
      IncidentType.general => '일반 형사 — 기본형법·특별법·면책 조항 비교',
    };
    if (top == null) return base;
    if (conflict) {
      return '$base · ⚠️ 상위 2개 경로 점수 근접 — 신중 검토 필요';
    }
    return '$base · 권장: ${top.law}';
  }
}

extension _LegalPerspectiveCopy on LegalPerspective {
  LegalPerspective copyWith({
    String? id,
    String? kind,
    String? law,
    String? attribute,
    double? weightScore,
    String? risk,
    String? condition,
    bool? recommended,
    String? precedentGuide,
  }) {
    return LegalPerspective(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      law: law ?? this.law,
      attribute: attribute ?? this.attribute,
      weightScore: weightScore ?? this.weightScore,
      risk: risk ?? this.risk,
      condition: condition ?? this.condition,
      recommended: recommended ?? this.recommended,
      precedentGuide: precedentGuide ?? this.precedentGuide,
    );
  }
}
