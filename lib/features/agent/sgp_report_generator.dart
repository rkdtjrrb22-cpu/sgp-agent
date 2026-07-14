/// 사법 무결성 초동조치 보고서 — 판례 인용 텍스트 합성 엔진.
library;

import 'sgp_agent_core.dart';
import 'sgp_court_precedents_ota.dart';
import 'sgp_officer_defense_shield_assembler.dart';
import 'sgp_physical_force_guide.dart';
import 'sgp_precedent_dictionary.dart';
import 'sgp_procedure_timeline.dart';
import 'sgp_quantum_legal_engine.dart';
import 'sgp_official_document_drafts.dart';
import 'sgp_medical_custody_engine.dart';
import 'sgp_kgrag_router.dart';
import '../control/sgp_anti_corruption_filter.dart';
import '../evidence/sgp_evidence_coc_engine.dart';
import '../glymphatic/sgp_glymphatic_innovation_engine.dart';
import 'sgp_law_extractor.dart';

/// 보고서 생성에 필요한 현장 세션 데이터.
class SgpReportInput {
  const SgpReportInput({
    required this.rawText,
    required this.checklist,
    required this.generatedAt,
    this.advancedAnalysis,
    this.timeline,
    this.quantumComparison,
    this.medicalTransferSession,
    this.kgragReasoning,
    this.evidenceCoC,
    this.hierarchicalLawSet,
  });

  final String rawText;
  final LawCheckList checklist;
  final DateTime generatedAt;
  final SgpAdvancedAnalysis? advancedAnalysis;
  final SgpProcedureTimeline? timeline;
  final SgpQuantumLegalComparison? quantumComparison;
  final SgpMedicalTransferSession? medicalTransferSession;
  final KgragReasoningResult? kgragReasoning;

  /// 디지털 증거 연속성 (유치인 custody와 분리된 evidenceCoC).
  final EvidenceCoCSession? evidenceCoC;

  /// Stage 5 Hierarchical Law Extractor 결과 슬롯.
  final HierarchicalLawSet? hierarchicalLawSet;

  /// 저장 기록·파이프라인 JSON에서 복원.
  factory SgpReportInput.fromSessionJson(Map<String, dynamic> json) {
    final advancedJson = json['advancedAnalysis'];
    final timelineJson = json['procedureTimeline'];
    return SgpReportInput(
      rawText: json['rawText'] as String? ?? '',
      checklist: json['checklist'] is Map<String, dynamic>
          ? LawCheckList.fromJson(Map<String, dynamic>.from(json['checklist'] as Map))
          : const LawCheckList(),
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
      advancedAnalysis: advancedJson is Map<String, dynamic>
          ? SgpAdvancedAnalysis.fromJson(advancedJson)
          : null,
      timeline: timelineJson is Map<String, dynamic>
          ? procedureTimelineFromJson(timelineJson)
          : null,
      quantumComparison: json['quantumComparison'] is Map<String, dynamic>
          ? SgpQuantumLegalComparison.fromJson(
              Map<String, dynamic>.from(json['quantumComparison'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toSessionJson() => {
        'rawText': rawText,
        'checklist': checklist.toJson(),
        'generatedAt': generatedAt.toIso8601String(),
        if (advancedAnalysis != null) 'advancedAnalysis': advancedAnalysis!.toJson(),
        if (timeline != null) 'procedureTimeline': procedureTimelineToJson(timeline!),
        if (quantumComparison != null) 'quantumComparison': quantumComparison!.toJson(),
      };
}

/// 생성된 보고서 결과.
class SgpLegalReport {
  const SgpLegalReport({
    required this.markdown,
    required this.plainText,
    required this.citedPrecedentIds,
    required this.generatedAt,
    this.officialDocuments,
  });

  /// 초동조치 보고서 본문 (공식 서류 미포함 — 팝업 탭 간 중복 방지).
  final String markdown;

  /// [markdown]의 플레인 텍스트 버전.
  final String plainText;

  final List<String> citedPrecedentIds;
  final DateTime generatedAt;
  final SgpOfficialDocuments? officialDocuments;

  /// 전체 공유용 — 초동조치 + 발생보고서 + 체포서 (각 1회씩만 포함).
  String get combinedPlainText {
    final docs = officialDocuments;
    if (docs == null) return plainText;
    return '$plainText\n\n${'=' * 40}\n\n${docs.combinedPlainText}';
  }
}

/// 대법원 판례 인용 초동조치 보고서 합성기 (오프라인·경량 템플릿).
class SgpReportGenerator {
  const SgpReportGenerator._();

  static SgpLegalReport generate(SgpReportInput input) {
    final precedents = _resolvePrecedents(input);
    final citedIds = precedents.map((p) => p.id).toList();
    final buf = StringBuffer();

    // 본문 절에서 이미 인용한 판례는 요지 절에서 재반복하지 않는다.
    final inlineCited = <String>{};

    buf.writeln(_documentLetterhead(input));
    buf.writeln();
    buf.writeln('# SGP-Agent 사법 무결성 초동조치 보고서');
    buf.writeln();
    buf.writeln(
      '> 본 문서는 현장 초동조치·증거능력·위수증 예방을 위한 **내부용 초안**입니다. '
      '외부 송부 전 수사관 최종 교열·결재가 필요합니다.',
    );
    buf.writeln();
    _section(buf, '1. 문서 식별·개요', _buildOverview(input));
    _section(buf, '2. 가·피해자 분리 조치',
        _buildVictimSeparation(input, precedents, inlineCited));
    _section(buf, '3. 물리력 대응',
        _buildPhysicalForce(input, precedents, inlineCited));
    final defenseLines = _buildOfficerDefenseShield(input);
    if (defenseLines.isNotEmpty) {
      _section(buf, '3-A. 독직폭행 피소 대비 방어막', defenseLines);
    }
    _section(buf, '4. 현장 채증 법적 고지',
        _buildEvidenceNotice(input, precedents, inlineCited));
    if (input.evidenceCoC != null) {
      _section(
        buf,
        '4-A. 디지털 증거 Chain of Custody (evidenceCoC)',
        _buildEvidenceCoCSection(input.evidenceCoC!),
      );
    }
    _section(buf, '5. 신병 인계·구금', _buildCustodyHandover(input));
    if (input.advancedAnalysis != null) {
      _section(buf, '6. 법리 분석 (SGP-Agent Pro)',
          _buildLegalAnalysis(input, precedents, inlineCited));
    }
    if (input.kgragReasoning != null) {
      _section(buf, '6-A. KG-RAG 하이브리드 추론',
          _buildKgragSection(input.kgragReasoning!));
    }
    final antiCorruption = SgpAntiCorruptionFilter.assess(
      documentText: input.rawText,
    );
    if (!antiCorruption.isClean) {
      _section(buf, '6-B. 사법 무결성·감찰 통제 (Anti-Corruption)',
          _buildAntiCorruptionSection(antiCorruption));
    }
    final remaining =
        precedents.where((p) => !inlineCited.contains(p.id)).toList();
    if (input.quantumComparison != null) {
      _section(buf, '7. 양자적 법률 비교', _buildQuantumSection(input.quantumComparison!));
      _section(buf, '8. 추가 인용 대법원 판례 요지', _buildPrecedentBlock(remaining));
      _section(buf, '9. 절차 이행 현황', _buildProcedureChecklist(input));
      _section(buf, '10. 수사관 확인·서명', _buildOfficerConfirmation(input.generatedAt));
    } else {
      _section(buf, '7. 추가 인용 대법원 판례 요지', _buildPrecedentBlock(remaining));
      _section(buf, '8. 절차 이행 현황', _buildProcedureChecklist(input));
      _section(buf, '9. 수사관 확인·서명', _buildOfficerConfirmation(input.generatedAt));
    }

    final lawSet = input.hierarchicalLawSet ??
        (input.rawText.trim().isEmpty
            ? null
            : SgpLawExtractor.extract(input.rawText));
    if (lawSet != null && !lawSet.isEmpty) {
      _section(
        buf,
        '계층형 법률 추출 (SgpLawExtractor LV1–LV4)',
        lawSet.toMarkdownSummary().split('\n'),
      );
    }

    // 공식 서류는 markdown 본문에 이어붙이지 않는다 —
    // 팝업 탭 2·3(발생보고서·체포서)과 탭 1의 내용 중복 방지.
    final officialDocs = SgpOfficialDocumentDrafts.generate(input);

    final markdown = buf.toString().trim();
    return SgpLegalReport(
      markdown: markdown,
      plainText: _markdownToPlain(markdown),
      citedPrecedentIds: citedIds,
      generatedAt: input.generatedAt,
      officialDocuments: officialDocs,
    );
  }

  static String _documentLetterhead(SgpReportInput input) {
    return '''
---
**문서 분류**  보안 · 수사 내부용 (외부 유출 금지)
**문서 성격**  판례 인용 초동조치 보고서 초안
**적용 규범**  형사소송법 · 경찰관직무집행법 · 디지털 증거 압수 법리
**생성 엔진**  SGP-Agent On-Device · ${SgpGlymphaticInnovationEngine.architectSignature}
**생성 시각**  ${_fmtDateTime(input.generatedAt)}
**폐쇄망**     forbidsNetworkEgress · AES Secure Vault (evidenceCoC)
---'''.trim();
  }

  /// 판례를 본문에 1회만 인용 — 이미 인용된 판례는 null.
  static String? _citeOnce(
    PrecedentRef p,
    Set<String> inlineCited,
  ) {
    if (!inlineCited.add(p.id)) return null;
    return p.holding;
  }

  static List<PrecedentRef> _resolvePrecedents(SgpReportInput input) {
    final dict = getPrecedentDictionary();
    final byId = {for (final p in dict) p.id: p};
    final result = <PrecedentRef>[];
    final seen = <String>{};

    void add(PrecedentRef? p) {
      if (p != null && seen.add(p.id)) result.add(p);
    }

    final adv = input.advancedAnalysis;
    if (adv != null) {
      for (final id in adv.appliedPrecedentIds) {
        add(byId[id]);
      }
      if (adv.defenseActDetected || adv.selfDefenseLikelihood >= 0.4) {
        add(byId['SC_self_defense']);
      }
      if (adv.preemptiveAttackDetected) add(byId['SC_preemptive_attack']);
      if (adv.mutualCombatSuspected) add(byId['SC_mutual_combat']);
      if (adv.hasCriticalProceduralAlert) add(byId['SC_illegal_evidence']);
      if (adv.weaponDominanceHolder.isNotEmpty &&
          adv.weaponDominanceHolder != '미확인') {
        add(byId['SC_weapon_dominance']);
      }
    }

    final matched = matchPrecedents(
      text: input.rawText,
      isDomesticViolence: input.checklist.isDomesticViolence,
      isIntoxicated: input.checklist.isIntoxicated,
      isWeaponUsed: input.checklist.isWeaponUsed,
    );
    for (final p in matched) {
      add(p);
    }

    if (input.checklist.isIntoxicated) add(byId['SC_intox_voluntary']);
    if (input.timeline != null) {
      final evidenceDone = _isCheckDone(input.timeline!, 'evidence_notice', 'evidence_legal_notice');
      if (evidenceDone) add(byId['SC_illegal_evidence']);
    }

    return result;
  }

  static void _section(StringBuffer buf, String title, List<String> lines) {
    buf.writeln('## $title');
    buf.writeln();
    for (final line in lines) {
      buf.writeln(line);
    }
    buf.writeln();
  }

  static List<String> _buildOverview(SgpReportInput input) {
    final t = input.timeline;
    final lines = <String>[
      '- **작성 일시**: ${_fmtDateTime(input.generatedAt)}',
      '- **보고 유형**: 현장 초동조치 · 사법 무결성 · 판례 인용 기록',
      '- **활용 목적**: 폴넷·수사서식 붙여넣기용 초안 (수사관 교열 후 확정)',
    ];
    if (t != null) {
      lines.addAll([
        '- **체포 방식**: ${t.arrestType.displayName}',
        '- **법적 근거**: ${t.arrestType.legalBasis}',
        '- **T-0 체포 시각**: ${_fmtDateTime(t.t0)}',
        '- **체포 후 경과**: ${_fmtElapsed(t.elapsedFrom(input.generatedAt))}',
      ]);
    } else {
      lines.add('- **체포 시각**: (타임라인 미시작 — 현장 시각 수기 기재)');
    }
    if (input.evidenceCoC != null) {
      lines.add(
        '- **디지털 증거 신호등**: ${input.evidenceCoC!.trafficLabel} '
        '(${input.evidenceCoC!.completedCount}/4 단계)',
      );
    }
    if (input.rawText.trim().isNotEmpty) {
      final excerpt = input.rawText.trim();
      final short = excerpt.length > 160 ? '${excerpt.substring(0, 160)}…' : excerpt;
      lines.add('- **현장 요지(원문)**: $short');
    }
    return lines;
  }

  static List<String> _buildEvidenceCoCSection(EvidenceCoCSession coc) {
    final lines = <String>[
      '- **용어 구분**: 본 절은 디지털 증거 연속성(evidenceCoC)이며, '
          '유치인 관리(custody)와 별개입니다.',
      '- **신호등**: ${coc.trafficLabel}',
      '- **매체**: ${coc.deviceType ?? coc.mediaLabel ?? "미상"}',
    ];
    for (final step in EvidenceCoCStep.values) {
      final rec = coc.steps[step];
      final done = rec?.completed == true;
      final mark = done ? '✓' : ' ';
      final extra = <String>[];
      if (rec?.completedAt != null) {
        extra.add(_fmtDateTime(rec!.completedAt!));
      }
      if (rec?.hashValue != null) {
        extra.add('SHA-256 `${rec!.hashValue}`');
      }
      lines.add(
        '- [$mark] **${step.label}**'
        '${extra.isEmpty ? "" : " — ${extra.join(" · ")}"}',
      );
    }
    if (coc.blindSpots.isNotEmpty) {
      lines.add('- **맹점·보완수사 안내**');
      lines.add(
        '  ${SgpEvidenceCoCEngine.supplementaryInvestigationWarning(coc)}',
      );
      for (final b in coc.blindSpots) {
        lines.add('  - ${b.label}: ${b.actionGuide}');
      }
    } else {
      lines.add('- **맹점**: 현 시점 자동 탐지 항목 없음 (수사관 최종 확인 요)');
    }
    return lines;
  }

  static List<String> _buildVictimSeparation(
    SgpReportInput input,
    List<PrecedentRef> precedents,
    Set<String> inlineCited,
  ) {
    final t = input.timeline;
    final lines = <String>[];
    if (t == null) {
      lines.add('- 분리 조치: (타임라인 데이터 없음)');
      return lines;
    }

    final node = _findNode(t, 'victim_separation');
    if (node != null) {
      lines.add('- **분리 시한**: ${node.offsetLabel} (마감 ${_fmtDateTime(node.deadline)})');
      for (final c in node.checkItems) {
        lines.add('- [${c.checked ? '✓' : ' '}] ${c.label}');
      }
    }

    final dv = precedents.where((p) => p.id == 'SC_dv_victim').toList();
    final mutual = precedents.where((p) => p.id == 'SC_mutual_combat').toList();
    if (input.checklist.isDomesticViolence && dv.isNotEmpty) {
      final holding = _citeOnce(dv.first, inlineCited);
      if (holding != null) lines.add('- **판례 인용**: $holding');
    }
    if (mutual.isNotEmpty) {
      final holding = _citeOnce(mutual.first, inlineCited);
      if (holding != null) {
        lines.add('- **판례 인용**: $holding');
        lines.add('  → 쌍방 폭행 정황 시 선제 공격·흉기 주도권으로 실질 가해자를 구분하였음.');
      }
    } else if (input.advancedAnalysis != null) {
      lines.add('- **분리 판단**: ${input.advancedAnalysis!.suspectVictimStatus}');
    }
    return lines;
  }

  static List<String> _buildPhysicalForce(
    SgpReportInput input,
    List<PrecedentRef> precedents,
    Set<String> inlineCited,
  ) {
    final t = input.timeline;
    final lines = <String>[];
    final level = t?.physicalThreatLevel;

    if (level != null) {
      final response = SgpPhysicalForceGuide.responseFor(level);
      lines.addAll([
        '- **평가 위해 수준**: ${level.displayName}',
        '- **법적 근거**: ${response.legalBasis}',
        '- **대응 요약**: ${response.summary}',
        '- **허용 장구**: ${response.allowedEquipment.join(', ')}',
        '- **허용 기술**: ${response.allowedTechniques.join(', ')}',
      ]);
      for (final req in response.proceduralRequirements) {
        lines.add('- **절차**: $req');
      }
    } else {
      lines.add('- 위해 수준 평가: (미기록)');
    }

    if (t != null) {
      final node = _findNode(t, 'physical_force');
      if (node != null) {
        for (final c in node.checkItems) {
          lines.add('- [${c.checked ? '✓' : ' '}] ${c.label}');
        }
      }
    }

    final selfDef = precedents.where((p) => p.id == 'SC_self_defense').toList();
    if (selfDef.isNotEmpty && (input.advancedAnalysis?.defenseActDetected ?? false)) {
      final holding = _citeOnce(selfDef.first, inlineCited);
      if (holding != null) {
        lines.add('- **판례 인용 (정당방위)**: $holding');
        lines.add(
          '  → 침해의 현재성·부당성·방어의사·상당성을 대조하여 물리력 행사 비례성을 검토함.',
        );
      }
    }
    return lines;
  }

  static List<String> _buildOfficerDefenseShield(SgpReportInput input) {
    final level = input.timeline?.physicalThreatLevel;
    if (level == null || level.stageNumber < 2) return const [];

    final forceTier = level.resistanceStage.defaultForceTier;
    final pack = SgpOfficerDefenseShieldAssembler.assemble(
      threatLevel: level,
      forceTier: forceTier,
      rawText: input.rawText,
      generatedAt: input.generatedAt,
    );
    return [
      '- **보호막**: ${SgpOfficerDefenseShieldAssembler.isLegalAidShieldActiveFromThreat(level) ? "법률 조력 보호막 활성(3단계↑)" : "방어막 탭 준비(2단계↑)"}',
      '- **타임라인**: ${pack.timelineEntries.map((e) => e.arrowLine).join(" ➔ ")}',
      '- **법리 팩**: 경직법 제11조의5 · 형법 제20조 · 공무집행방해 역고소',
      '- **출력**: 디지털 공무집행 무결성 보고서(CoC) · 법률비용보험 신청서 (원클릭 복사)',
      '',
      '### 맞대응 법리 요약',
      ...pack.legalDefenseMarkdown
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(18)
          .map((l) => l.startsWith('#') ? l : l),
    ];
  }

  static List<String> _buildEvidenceNotice(
    SgpReportInput input,
    List<PrecedentRef> precedents,
    Set<String> inlineCited,
  ) {
    final t = input.timeline;
    final lines = <String>[
      '- **법적 근거**: 경찰관 직무집행법 제10조의2',
    ];

    if (t != null) {
      final node = _findNode(t, 'evidence_notice');
      final noticeDone = _isCheckDone(t, 'evidence_notice', 'evidence_legal_notice');
      lines.add('- **채증 법적고지**: ${noticeDone ? '완료' : '미완료'}');
      if (node != null) {
        lines.add('- **고지 시한**: ${node.offsetLabel}');
        for (final c in node.checkItems) {
          lines.add('- [${c.checked ? '✓' : ' '}] ${c.label}');
        }
      }
    }

    final illegal = precedents.where((p) => p.id == 'SC_illegal_evidence').toList();
    final warrantless = precedents.where((p) => p.id == 'SC_warrantless_seizure').toList();
    if (illegal.isNotEmpty) {
      final holding = _citeOnce(illegal.first, inlineCited);
      if (holding != null) {
        lines.add('- **판례 인용 (위수증 방어)**: $holding');
        lines.add('  → 채증 전 고지·바디캠 가동으로 적법절차 및 증거능력을 확보함.');
      }
    }
    if (warrantless.isNotEmpty) {
      final holding = _citeOnce(warrantless.first, inlineCited);
      if (holding != null) lines.add('- **판례 인용**: $holding');
    }
    return lines;
  }

  static List<String> _buildCustodyHandover(SgpReportInput input) {
    final t = input.timeline;
    final lines = <String>[];
    if (t == null) {
      lines.add('- 신병 인계: (타임라인 데이터 없음)');
    } else {
      final node = _findNode(t, 'custody_handover_prep');
      lines.add('- **인계 준비 시한**: ${node?.offsetLabel ?? 'T-0 후 2시간 이내'}');
      if (node != null) {
        lines.add('- **마감 시각**: ${_fmtDateTime(node.deadline)}');
        for (final c in node.checkItems) {
          lines.add('- [${c.checked ? '✓' : ' '}] ${c.label}');
        }
      }
    }

    final med = input.medicalTransferSession;
    if (med != null) {
      final deadline = SgpMedicalCustodyTimeline.compute(session: med);
      lines.add('- **병원 이송 및 신병 확보 상황 보고**:');
      lines.add(
        '  ${SgpMedicalCustodyTimeline.buildSituationReportParagraph(session: med, deadline: deadline)}',
      );
    }
    return lines;
  }

  static List<String> _buildLegalAnalysis(
    SgpReportInput input,
    List<PrecedentRef> precedents,
    Set<String> inlineCited,
  ) {
    final adv = input.advancedAnalysis!;
    final lines = <String>[
      '- **가·피해자 종합**: ${adv.suspectVictimStatus}',
      '- **실질 공격 유발자**: ${adv.primaryAggressor}',
      '- **피해자 추정**: ${adv.primaryVictim}',
      '- **정당방위 성립 가능성**: ${(adv.selfDefenseLikelihood * 100).round()}%',
      '- **예상 공소유지 성공률**: ${adv.prosecutionSuccessRate.round()}%',
      '- **흉기 주도권**: ${adv.weaponDominanceHolder}',
    ];

    if (adv.preemptiveAttackDetected) {
      final p = precedents.where((e) => e.id == 'SC_preemptive_attack').toList();
      if (p.isNotEmpty) {
        final holding = _citeOnce(p.first, inlineCited);
        if (holding != null) lines.add('- **판례 인용 (선제 공격)**: $holding');
      }
    }

    final intox = precedents.where((e) => e.id == 'SC_intox_voluntary').toList();
    if (input.checklist.isIntoxicated && intox.isNotEmpty) {
      final holding = _citeOnce(intox.first, inlineCited);
      if (holding != null) {
        lines.add('- **판례 인용 (형법 제10조 3항)**: $holding');
        lines.add('  → 자의적 음주로 인한 심신미약 감경 주장 제한 가능성을 검토함.');
      }
    }

    if (adv.legalRisks.isNotEmpty) {
      lines.add('- **법리 리스크**:');
      for (final r in adv.legalRisks) {
        lines.add('  - $r');
      }
    }
    return lines;
  }

  /// KG-RAG — 검찰/법원 제출용 고도 정제 수사 보고서 단락.
  static List<String> _buildKgragSection(KgragReasoningResult kgrag) {
    final lines = <String>[
      '- **환각 방지 가드**: ${kgrag.hallucinationGuardPass ? "PASS (온톨로지·판례 교차 검증)" : "추가 확인 필요"}',
      '- **정당방위·긴급피난 추정**: ${(kgrag.selfDefenseProbability * 100).round()}% (${kgrag.confidenceLabel})',
      '- **현장 조치 지침**: ${kgrag.recommendedAction}',
    ];

    final branch = kgrag.ontologyShield.branchResult;
    if (branch != null) {
      lines.add(
        '- **집행 분기**: ${branch.isCriminal ? "형사과 수사" : "지자체 행정 이관"} — ${branch.rationale}',
      );
    }

    final med = kgrag.ontologyShield.complaintRoute?.type;
    if (med != null && med.isMedicalTransferGuide) {
      lines.add(
        '- **의료 이송 분기**: ${med.medTransferBranch ?? "MED-TRANSFER"} · '
        '신병확보(CUSTODY-MGMT) ${med.requiresGuard ? "2인 계호" : "행정 감독"}',
      );
    }

    if (kgrag.precedentHits.isNotEmpty) {
      lines.add('- **판례 핵심 요지 (벡터 매칭)**');
      for (final h in kgrag.precedentHits.take(3)) {
        lines.add(
          '  - [${h.court} ${h.caseNo}] (유사도 ${(h.similarity * 100).round()}%) ${h.holding}',
        );
      }
    }

    if (kgrag.ontologyShield.legalNodeIds.isNotEmpty) {
      lines.add(
        '- **온톨로지 가이드레일 노드**: ${kgrag.ontologyShield.legalNodeIds.join(", ")}',
      );
    }

    lines.add('');
    lines.add('> ${kgrag.promptContext.split('\n').take(6).join('\n> ')}');
    return lines;
  }

  /// 감찰 사전 리스크 — 직무범·신분범 저촉 위험 단락.
  static List<String> _buildAntiCorruptionSection(
    AntiCorruptionAssessment assessment,
  ) {
    final lines = <String>[
      if (assessment.hasCritical)
        '- **⚠ 치명 위험**: ${assessment.disciplineWarning}',
    ];
    for (final f in assessment.flags) {
      final tag = f.isCritical ? 'CRITICAL' : 'WARNING';
      lines.add('- **[$tag] ${f.title}**');
      lines.add('  - 형사 근거: ${f.legalBasis.join(", ")}');
      lines.add('  - 징계 근거: ${f.disciplineBasis.join(", ")}');
      lines.add('  - ${f.message}');
    }
    return lines;
  }

  static List<String> _buildQuantumSection(SgpQuantumLegalComparison q) {
    final lines = <String>[
      '- **사건 유형**: ${q.incidentType.displayLabel}',
      '- **요약**: ${q.summary}',
      '- **긴급도**: ${q.urgencyLevel.label}',
      '- **행동 지침**: ${q.actionGuidance}',
    ];
    for (final p in q.perspectives) {
      lines.add(
        '- **${p.recommended ? "★ " : ""}${p.law}**: ${p.attribute} (가중치 ${(p.weightScore * 100).round()}%)',
      );
    }
    final trendHoldings = _resolveTrendHoldings(q.appliedTrendIds);
    if (trendHoldings.isNotEmpty) {
      lines.add('- **반영된 최신 판례 경향**:');
      for (final h in trendHoldings) {
        lines.add('  - $h');
      }
    }
    return lines;
  }

  /// 트렌드 ID(영문 코드) → 한글 판례 요지. 미해석 ID는 표기하지 않는다.
  static List<String> _resolveTrendHoldings(List<String> trendIds) {
    if (trendIds.isEmpty) return const [];
    final byId = {
      for (final t in SgpCourtPrecedentsOta.instance.activeTrends) t.id: t,
    };
    return [
      for (final id in trendIds)
        if (byId[id] != null) byId[id]!.holding,
    ];
  }

  static List<String> _buildPrecedentBlock(List<PrecedentRef> precedents) {
    if (precedents.isEmpty) {
      return ['- 본문에 인용된 판례 외 추가 매칭 판례 없음 (수사관 판단 보완 필요)'];
    }
    return [
      for (final p in precedents) '- ${p.holding}',
    ];
  }

  static List<String> _buildProcedureChecklist(SgpReportInput input) {
    final t = input.timeline;
    if (t == null) return ['- 절차 타임라인 미시작'];

    final lines = <String>[];
    for (final node in t.nodes) {
      if (!kImmediatePhaseNodeIds.contains(node.id) && node.id != 't0') continue;
      final done = node.checkItems.every((c) => c.checked);
      lines.add('- **${node.title}**: ${done ? '완료' : '진행 중'}');
    }
    if (input.advancedAnalysis != null && input.advancedAnalysis!.proceduralAlerts.isNotEmpty) {
      lines.add('- **위수증 방어 알림**:');
      for (final a in input.advancedAnalysis!.proceduralAlerts) {
        lines.add('  - $a');
      }
    }
    return lines;
  }

  static List<String> _buildOfficerConfirmation(DateTime at) {
    return [
      '본 보고서는 SGP-Agent 온디바이스 AI가 현장 수집 데이터를 기반으로 '
          '${_fmtDateTime(at)}에 자동 생성한 **초안**입니다.',
      '**최종 체포 결정·공소 의견·증거 평가에 관한 모든 법적 책임은 출동 수사관 본인에게 있습니다.**',
      '',
      '| 구분 | 기재 |',
      '| --- | --- |',
      '| 작성 수사관 (성명·계급) | ____________________ |',
      '| 소속 (관서·팀) | ____________________ |',
      '| 확인 일시 | ____________________ |',
      '| 결재(팀장/과장) | ____________________ |',
      '',
      '- 체크: [ ] 판례 인용 취지 교열 완료',
      '- 체크: [ ] 디지털 증거 CoC·해시값 대조 완료',
      '- 체크: [ ] 외부 전송 채널(폴넷 등) 보안업무규정 준수',
    ];
  }

  static SgpTimeTableNode? _findNode(SgpProcedureTimeline t, String id) {
    for (final n in t.nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  static bool _isCheckDone(SgpProcedureTimeline t, String nodeId, String checkId) {
    final node = _findNode(t, nodeId);
    if (node == null) return false;
    return node.checkItems.any((c) => c.id == checkId && c.checked);
  }

  static String _fmtDateTime(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$m';
  }

  static String _fmtElapsed(Duration d) {
    if (d.inDays > 0) return '${d.inDays}일 ${d.inHours % 24}시간';
    if (d.inHours > 0) return '${d.inHours}시간 ${d.inMinutes % 60}분';
    return '${d.inMinutes}분';
  }

  /// 마크다운 → 폴넷 메신저용 플레인 텍스트 (가독성 우선).
  static String _markdownToPlain(String md) {
    return md
        .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^- \[✓\] ', multiLine: true), '✓ ')
        .replaceAll(RegExp(r'^- \[ \] ', multiLine: true), '☐ ')
        .replaceAll(RegExp(r'^- \[x\] ', multiLine: true, caseSensitive: false), '✓ ')
        .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
        .replaceAll(RegExp(r'\| --- \| --- \|'), '')
        .replaceAll(RegExp(r'\|\s*'), '  ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}