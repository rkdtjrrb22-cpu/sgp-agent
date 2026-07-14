import 'sgp_civil_complaint_branch.dart';
import 'sgp_civil_complaint_data.dart';
import 'sgp_civil_non_intervention_filter.dart';

/// 원클릭 안내문 조립 결과.
class CivilGuidanceCard {
  const CivilGuidanceCard({
    required this.markdown,
    required this.plainText,
    required this.title,
  });

  final String markdown;
  final String plainText;
  final String title;
}

/// 선택적 RAG 판례 요지 (Flutter/KG 모듈 비의존).
class CivilGuidancePrecedentLine {
  const CivilGuidancePrecedentLine({
    required this.court,
    required this.caseNo,
    required this.holding,
  });

  final String court;
  final String caseNo;
  final String holding;
}

abstract final class SgpCivilGuidanceAssembler {
  /// 라우팅 결과 + (선택) 판례 요지 → 3단 포맷 안내문.
  static CivilGuidanceCard assemble({
    required CivilComplaintRouteResult route,
    required String rawText,
    List<CivilGuidancePrecedentLine> precedentLines = const [],
  }) {
    final type = route.type;
    final enforcement = rawText.trim().isEmpty
        ? null
        : route.inferEnforcement(rawText);
    final civilHit = SgpCivilNonInterventionFilter.evaluate(
      rawText,
      routedTypeId: type.id,
    );

    final agencies = <String>[];
    for (final j in type.jurisdictions) {
      final phone = j.phone != null ? ' (☎${j.phone})' : '';
      agencies.add(
        '- **${j.agencyName}**$phone'
        '${j.transfer ? " — 이관·연계" : ""}'
        '${j.scope != null ? " · ${j.scope}" : ""}',
      );
    }
    if (type.phone != null &&
        !type.jurisdictions.any((j) => j.phone == type.phone)) {
      agencies.add('- **대표 연락** ☎${type.phone}');
    }
    if (civilHit.matched || type.policeDispatchWarning) {
      if (!agencies.any((a) => a.contains('법률구조'))) {
        agencies.add('- **대한법률구조공단** (☎132) — 민사·임대차 상담');
      }
      if (type.id == 'CC-TYPE-NOISE' &&
          !agencies.any((a) => a.contains('소음') || a.contains('이웃'))) {
        agencies.add('- **층간소음 이웃사이센터·구청 환경과** — 소음 조정·행정지도');
      }
    }

    final legalJudgment = StringBuffer()
      ..writeln(type.adminGuideLv8.isNotEmpty
          ? type.adminGuideLv8
          : '현장 요지에 따른 관할·적용법 검토가 필요합니다.')
      ..writeln()
      ..writeln('- 인식 유형: **${type.title}** (${type.category})')
      ..writeln('- 매칭 키워드: ${route.matchedKeywords.join(", ")}')
      ..writeln('- 신뢰도: ${(route.confidence * 100).round()}%');
    if (enforcement != null) {
      legalJudgment.writeln(
        '- 집행 분기: **${SgpCivilComplaintBranchRouter.branchLabel(enforcement.branch)}** '
        '(${(enforcement.confidence * 100).round()}%)',
      );
      legalJudgment.writeln('- 근거: ${enforcement.rationale}');
    }
    if (precedentLines.isNotEmpty) {
      legalJudgment.writeln('- 판례·RAG 요지:');
      for (final h in precedentLines.take(2)) {
        legalJudgment.writeln(
          '  - [${h.court} ${h.caseNo}] ${h.holding}',
        );
      }
    }

    final policeLimit = StringBuffer();
    if (civilHit.matched) {
      policeLimit.writeln(civilHit.bannerBody);
    } else if (type.policeDispatchWarning) {
      policeLimit.writeln(
        '본 유형은 원칙적으로 **지자체·전문기관 소관**이며, '
        '경찰 강제력(과태료 부과·사유지 견인 강요 등) 행사가 제한됩니다. '
        '생명·신체 긴급 위험, 폭행·협박·손괴 등 형사 요건이 있을 때만 112·형사 병행.',
      );
    } else {
      policeLimit.writeln(
        '경찰 조치 가능: 사실 확인·피해자 보호·관련 법령에 따른 초동조치. '
        '최종 처분·공소 의견은 수사관 판단 및 관계 기관 권한에 따릅니다.',
      );
    }

    final buf = StringBuffer()
      ..writeln('# 종합 민원 안내문 — ${type.title}')
      ..writeln()
      ..writeln('> 현장 수사관이 민원인에게 안내·전송하기 위한 **온디바이스 초안**입니다.')
      ..writeln()
      ..writeln('## 1. 법리적 판단')
      ..writeln()
      ..writeln(legalJudgment.toString().trim())
      ..writeln()
      ..writeln('## 2. 경찰 조치 한계')
      ..writeln()
      ..writeln(policeLimit.toString().trim())
      ..writeln()
      ..writeln('## 3. 전문 구제 기관 연계')
      ..writeln();
    if (agencies.isEmpty) {
      buf.writeln('- (연계 기관 미등록 — 관서 민원실·110 안내)');
    } else {
      for (final a in agencies) {
        buf.writeln(a);
      }
    }
    if (type.requiredDocuments.isNotEmpty) {
      buf.writeln();
      buf.writeln('### 준비 서류(권고)');
      for (final d in type.requiredDocuments) {
        buf.writeln('- ${d.label}${d.required ? " (필수)" : ""}');
      }
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln('*SGP-Agent · INSP_KANG_SG_4066 · 온디바이스 · 외부 유출 주의*');

    final md = buf.toString().trim();
    return CivilGuidanceCard(
      title: type.title,
      markdown: md,
      plainText: _toPlain(md),
    );
  }

  static String _toPlain(String md) {
    return md
        .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
