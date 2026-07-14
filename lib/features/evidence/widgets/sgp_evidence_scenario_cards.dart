/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Evidence Scenario Result Cards
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 범죄사실 초안·무결성 체크리스트 Card 레이아웃.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agent/sgp_app_theme.dart';
import '../sgp_evidence_scenario_pipeline.dart';

class SgpEvidenceScenarioCards extends StatelessWidget {
  const SgpEvidenceScenarioCards({
    super.key,
    required this.result,
    this.onCopyReport,
  });

  final EvidenceScenarioPipelineResult result;
  final VoidCallback? onCopyReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < result.crimeFacts.length; i++) ...[
          Card(
            color: SgpFieldColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: SgpFieldColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SgpAppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SgpAppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.crimeFacts[i].title,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: SgpFieldColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.crimeFacts[i].statutoryBasis,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: SgpAppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.crimeFacts[i].narrative,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: SgpFieldColors.textSecondary,
                    ),
                  ),
                  if (result.crimeFacts[i].checkItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...result.crimeFacts[i].checkItems.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '·',
                              style: TextStyle(
                                fontSize: 12,
                                color: SgpFieldColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: SgpFieldColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Card(
          color: SgpFieldColors.surfaceHigh,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SgpFieldColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '디지털 증거수집 무결성 체크리스트',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: SgpFieldColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...result.integrityChecklist.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      line,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: SgpFieldColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (onCopyReport != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onCopyReport,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text(
                        '압수·수색 결과보고 복사',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> copyEvidenceMarkdown(String markdown) async {
  await Clipboard.setData(ClipboardData(text: markdown));
}
