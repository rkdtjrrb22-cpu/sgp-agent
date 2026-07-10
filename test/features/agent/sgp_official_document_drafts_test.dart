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
    expect(report.plainText, contains('범죄 발생 보고서'));
  });
}
