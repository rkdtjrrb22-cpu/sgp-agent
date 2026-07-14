/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Dokjik Assault Defense Shield Expansion Panel
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sgp_app_theme.dart';
import '../sgp_constitutional_force_engine.dart';
import '../sgp_officer_defense_shield_assembler.dart';
import '../sgp_physical_threat_level.dart';

/// 물리력 집행 기록 시 하단 — 독직폭행 피소 대비 방어막 확장 탭.
class SgpDokjikDefenseShieldPanel extends StatelessWidget {
  const SgpDokjikDefenseShieldPanel({
    super.key,
    required this.threatLevel,
    required this.forceTier,
    this.rawText = '',
    this.isExcessive = false,
    this.initiallyExpanded = true,
    this.compact = false,
  });

  final PhysicalThreatLevel threatLevel;
  final PoliceForceTier forceTier;
  final String rawText;
  final bool isExcessive;
  final bool initiallyExpanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pack = SgpOfficerDefenseShieldAssembler.assemble(
      threatLevel: threatLevel,
      forceTier: forceTier,
      rawText: rawText,
      isExcessive: isExcessive,
    );
    final accent = const Color(0xFF0D47A1);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: 0,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            0,
            compact ? 10 : 12,
            12,
          ),
          leading: Icon(Icons.shield, color: accent, size: compact ? 20 : 22),
          title: Text(
            '독직폭행 피소 대비 방어막 가이드',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          subtitle: Text(
            pack.timelineEntries.map((e) => e.arrowLine).join(' ➔ '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: SgpFieldColors.fieldGuideBody,
            ),
          ),
          children: [
            _sectionPreview(
              title: '맞대응 법리',
              body: pack.legalDefenseMarkdown,
              compact: compact,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _CopyChip(
                  label: '법리 복사',
                  markdown: pack.legalDefenseMarkdown,
                ),
                _CopyChip(
                  label: '무결성 CoC',
                  markdown: pack.integrityReportMarkdown,
                ),
                _CopyChip(
                  label: '보험 신청서',
                  markdown: pack.insuranceApplicationMarkdown,
                ),
                _CopyChip(
                  label: '통합 복사',
                  markdown: pack.combinedMarkdown,
                  emphasize: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '마크다운 초안 — 공유·편철·인쇄용으로 붙여넣기. '
              '(PDF는 관서 출력기로 마크다운/한글 변환)',
              style: TextStyle(
                fontSize: 9,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionPreview({
    required String title,
    required String body,
    required bool compact,
  }) {
    final preview = body.split('\n').take(compact ? 8 : 12).join('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            preview,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              height: 1.4,
              color: SgpFieldColors.fieldGuideNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  const _CopyChip({
    required this.label,
    required this.markdown,
    this.emphasize = false,
  });

  final String label;
  final String markdown;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        Icons.copy,
        size: 14,
        color: emphasize ? Colors.white : Colors.indigo.shade800,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: emphasize ? Colors.white : Colors.indigo.shade900,
        ),
      ),
      backgroundColor:
          emphasize ? const Color(0xFF1565C0) : Colors.indigo.shade50,
      side: BorderSide(
        color: emphasize ? const Color(0xFF1565C0) : Colors.indigo.shade200,
      ),
      onPressed: () async {
        await Clipboard.setData(
          ClipboardData(
            text: OfficerDefenseShieldPack.stripMarkdown(markdown),
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label — 클립보드에 복사되었습니다.')),
          );
        }
      },
    );
  }
}
