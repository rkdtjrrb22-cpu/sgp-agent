import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:sgp_agent/features/agent/sgp_official_document_drafts.dart';
import 'package:sgp_agent/features/agent/sgp_report_generator.dart';

void main() {
  test('범죄 발생보고서·체포서 예시 생성', () {
    final input = SgpReportInput(
      rawText: '진돗개가 목줄 없이 행인을 물어 교상. 견주 현장 확인. 피해자 112 신고.',
      checklist: const LawCheckList(isFleeing: true),
      generatedAt: DateTime(2026, 7, 10, 14, 30),
      advancedAnalysis: runAdvancedAnalysis(
        rawText: '진돗개가 목줄 없이 행인을 물어 교상.',
        checklist: const LawCheckList(),
        ruleResult: const RuleMatchResult(
          triggeredFilters: [],
          suggestedChecklist: LawCheckList(),
        ),
      ),
    );

    final docs = SgpOfficialDocumentDrafts.generate(input);
    expect(docs.crimeIncidentReport, contains('범죄 발생 보고서'));
    expect(docs.crimeIncidentReport, contains('판례 참고'));
    expect(docs.arrestWarrantDraft, contains('현행범'));
    expect(docs.arrestWarrantDraft, contains('형사소송법'));

    final report = SgpReportGenerator.generate(input);
    expect(report.officialDocuments, isNotNull);
    // 초동조치 본문(plainText)과 공식 서류는 분리 — 탭 간 중복 방지.
    expect(report.plainText, isNot(contains('범죄 발생 보고서')));
    expect(report.combinedPlainText, contains('범죄 발생 보고서'));
    expect(report.combinedPlainText, contains('체포'));
  });

  test('보고서 본문 — 판례 중복 인용·영문 코드 미노출', () {
    final input = SgpReportInput(
      rawText: '피의자가 먼저 시비를 걸고 칼을 휘두르며 술에 취해 도주하였다.',
      checklist: const LawCheckList(
        isWeaponUsed: true,
        isIntoxicated: true,
        isFleeing: true,
      ),
      generatedAt: DateTime(2026, 7, 11, 21, 0),
      advancedAnalysis: runAdvancedAnalysis(
        rawText: '피의자가 먼저 시비를 걸고 칼을 휘두르며 술에 취해 도주하였다.',
        checklist: const LawCheckList(isWeaponUsed: true, isIntoxicated: true),
        ruleResult: const RuleMatchResult(
          triggeredFilters: [],
          suggestedChecklist: LawCheckList(),
        ),
      ),
    );

    final report = SgpReportGenerator.generate(input);

    // 판례 ID(SC_*) 영문 코드가 본문에 노출되지 않는다.
    expect(report.markdown, isNot(contains('SC_')));
    expect(report.markdown, isNot(contains('[SC')));

    // 같은 판례 요지가 본문에 2회 이상 반복되지 않는다.
    final holdings = RegExp(r'판례 인용[^:]*: (.+)$', multiLine: true)
        .allMatches(report.markdown)
        .map((m) => m.group(1)!.trim())
        .toList();
    expect(holdings.toSet().length, holdings.length,
        reason: '본문 내 판례 인용이 중복되면 안 됨');
  });
}
