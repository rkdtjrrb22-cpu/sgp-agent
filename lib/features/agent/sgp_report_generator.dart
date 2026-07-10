/// 사법 무결성 초동조치 보고서 — 판례 인용 텍스트 합성 엔진.
library;

import 'sgp_agent_core.dart';
import 'sgp_physical_force_guide.dart';
import 'sgp_precedent_dictionary.dart';
import 'sgp_procedure_timeline.dart';
import 'sgp_quantum_legal_engine.dart';
import 'sgp_official_document_drafts.dart';

/// 보고서 생성에 필요한 현장 세션 데이터.
class SgpReportInput {
  const SgpReportInput({
    required this.rawText,
    required this.checklist,
    required this.generatedAt,
    this.advancedAnalysis,
    this.timeline,
    this.quantumComparison,
  });

  final String rawText;
  final LawCheckList checklist;
  final DateTime generatedAt;
  final SgpAdvancedAnalysis? advancedAnalysis;
  final SgpProcedureTimeline? timeline;
  final SgpQuantumLegalComparison? quantumComparison;

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

  final String markdown;
  final String plainText;
  final List<String> citedPrecedentIds;
  final DateTime generatedAt;
  final SgpOfficialDocuments? officialDocuments;
}

/// 대법원 판례 인용 초동조치 보고서 합성기 (오프라인·경량 템플릿).
class SgpReportGenerator {
  const SgpReportGenerator._();

  static SgpLegalReport generate(SgpReportInput input) {
    final precedents = _resolvePrecedents(input);
    final citedIds = precedents.map((p) => p.id).toList();
    final buf = StringBuffer();

    buf.writeln('# SGP-Agent 사법 무결성 초동조치 보고서');
    buf.writeln();
    _section(buf, '1. 개요', _buildOverview(input));
    _section(buf, '2. 가·피해자 분리 조치', _buildVictimSeparation(input, precedents));
    _section(buf, '3. 물리력 대응', _buildPhysicalForce(input, precedents));
    _section(buf, '4. 현장 채증 법적 고지', _buildEvidenceNotice(input, precedents));
    _section(buf, '5. 신병 인계·구금', _buildCustodyHandover(input));
    if (input.advancedAnalysis != null) {
      _section(buf, '6. 법리 분석 (SGP-Agent Pro)', _buildLegalAnalysis(input, precedents));
    }
    if (input.quantumComparison != null) {
      _section(buf, '7. 양자적 법률 비교', _buildQuantumSection(input.quantumComparison!));
      _section(buf, '8. 인용 대법원 판례 요지', _buildPrecedentBlock(precedents));
      _section(buf, '9. 절차 이행 현황', _buildProcedureChecklist(input));
      _section(buf, '10. 수사관 확인', _buildOfficerConfirmation(input.generatedAt));
    } else {
      _section(buf, '7. 인용 대법원 판례 요지', _buildPrecedentBlock(precedents));
      _section(buf, '8. 절차 이행 현황', _buildProcedureChecklist(input));
      _section(buf, '9. 수사관 확인', _buildOfficerConfirmation(input.generatedAt));
    }

    final officialDocs = SgpOfficialDocumentDrafts.generate(input);
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.writeln(officialDocs.crimeIncidentReport);
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.writeln(officialDocs.arrestWarrantDraft);

    final markdown = buf.toString().trim();
    return SgpLegalReport(
      markdown: markdown,
      plainText: _markdownToPlain(markdown),
      citedPrecedentIds: citedIds,
      generatedAt: input.generatedAt,
      officialDocuments: officialDocs,
    );
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
      '- **보고 유형**: 현장 초동조치·사법 무결성 기록',
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
    if (input.rawText.trim().isNotEmpty) {
      final excerpt = input.rawText.trim();
      final short = excerpt.length > 120 ? '${excerpt.substring(0, 120)}…' : excerpt;
      lines.add('- **현장 원문 요약**: $short');
    }
    return lines;
  }

  static List<String> _buildVictimSeparation(
    SgpReportInput input,
    List<PrecedentRef> precedents,
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
      lines.add('- **판례 인용**: ${dv.first.holding}');
    }
    if (mutual.isNotEmpty) {
      lines.add('- **판례 인용**: ${mutual.first.holding}');
      lines.add('  → 쌍방 폭행 정황 시 선제 공격·흉기 주도권으로 실질 가해자를 구분하였음.');
    } else if (input.advancedAnalysis != null) {
      lines.add('- **분리 판단**: ${input.advancedAnalysis!.suspectVictimStatus}');
    }
    return lines;
  }

  static List<String> _buildPhysicalForce(
    SgpReportInput input,
    List<PrecedentRef> precedents,
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
      lines.add('- **판례 인용 (정당방위)**: ${selfDef.first.holding}');
      lines.add(
        '  → 침해의 현재성·부당성·방어의사·상당성을 대조하여 물리력 행사 비례성을 검토함.',
      );
    }
    return lines;
  }

  static List<String> _buildEvidenceNotice(
    SgpReportInput input,
    List<PrecedentRef> precedents,
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
      lines.add('- **판례 인용 (위수증 방어)**: ${illegal.first.holding}');
      lines.add('  → 채증 전 고지·바디캠 가동으로 적법절차 및 증거능력을 확보함.');
    }
    if (warrantless.isNotEmpty) {
      lines.add('- **판례 인용**: ${warrantless.first.holding}');
    }
    return lines;
  }

  static List<String> _buildCustodyHandover(SgpReportInput input) {
    final t = input.timeline;
    if (t == null) return ['- 신병 인계: (타임라인 데이터 없음)'];

    final node = _findNode(t, 'custody_handover_prep');
    final lines = <String>[
      '- **인계 준비 시한**: ${node?.offsetLabel ?? 'T-0 후 2시간 이내'}',
    ];
    if (node != null) {
      lines.add('- **마감 시각**: ${_fmtDateTime(node.deadline)}');
      for (final c in node.checkItems) {
        lines.add('- [${c.checked ? '✓' : ' '}] ${c.label}');
      }
    }
    return lines;
  }

  static List<String> _buildLegalAnalysis(
    SgpReportInput input,
    List<PrecedentRef> precedents,
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
        lines.add('- **판례 인용 (선제 공격)**: ${p.first.holding}');
      }
    }

    final intox = precedents.where((e) => e.id == 'SC_intox_voluntary').toList();
    if (input.checklist.isIntoxicated && intox.isNotEmpty) {
      lines.add('- **판례 인용 (형법 제10조 3항)**: ${intox.first.holding}');
      lines.add('  → 자의적 음주로 인한 심신미약 감경 주장 제한 가능성을 검토함.');
    }

    if (adv.legalRisks.isNotEmpty) {
      lines.add('- **법리 리스크**:');
      for (final r in adv.legalRisks) {
        lines.add('  - $r');
      }
    }
    return lines;
  }

  static List<String> _buildQuantumSection(SgpQuantumLegalComparison q) {
    final lines = <String>[
      '- **사건 유형**: ${q.incidentType.jsonKey}',
      '- **요약**: ${q.summary}',
      '- **긴급도**: ${q.urgencyLevel.label}',
      '- **행동 지침**: ${q.actionGuidance}',
    ];
    for (final p in q.perspectives) {
      lines.add(
        '- **${p.recommended ? "★ " : ""}${p.law}**: ${p.attribute} (점수 ${(p.weightScore * 100).round()}%)',
      );
    }
    if (q.appliedTrendIds.isNotEmpty) {
      lines.add('- **적용 트렌드**: ${q.appliedTrendIds.join(", ")}');
    }
    return lines;
  }

  static List<String> _buildPrecedentBlock(List<PrecedentRef> precedents) {
    if (precedents.isEmpty) {
      return ['- 현장 텍스트·체크리스트 기준 매칭 판례 없음 (수사관 판단 보완 필요)'];
    }
    return [
      for (final p in precedents) '- **[${p.id}]** ${p.holding}',
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
          '${_fmtDateTime(at)}에 자동 생성한 초안입니다.',
      '**최종 체포 결정·공소 의견·증거 평가에 관한 모든 법적 책임은 출동 수사관 본인에게 있습니다.**',
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

  /// 마크다운 → 폴넷 메신저용 플레인 텍스트.
  static String _markdownToPlain(String md) {
    return md
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^- \[✓\] ', multiLine: true), '✓ ')
        .replaceAll(RegExp(r'^- \[ \] ', multiLine: true), '☐ ')
        .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
        .trim();
  }
}