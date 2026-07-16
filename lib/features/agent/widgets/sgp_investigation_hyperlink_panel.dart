/// 내근 하이퍼링크 법리·판례 검증 패널 (수동 검토 1-P 감축).
library;

import 'package:flutter/material.dart';

import '../sgp_app_theme.dart';
import '../sgp_investigation_hyperlink_verifier.dart';

class SgpInvestigationHyperlinkPanel extends StatelessWidget {
  const SgpInvestigationHyperlinkPanel({
    super.key,
    required this.session,
    required this.onVerified,
  });

  final InvestigationHyperlinkSession session;
  final void Function(String nodeId) onVerified;

  @override
  Widget build(BuildContext context) {
    final reductionPct =
        (session.estimatedReviewTimeReduction * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '하이퍼링크 법리 검증 (내근 1-P 감축)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF90CAF9),
                  ),
                ),
              ),
              Text(
                '감축 ~$reductionPct%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: session.meetsSeventyPercentReduction
                      ? const Color(0xFF69F0AE)
                      : SgpAppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '검증 ${session.verifiedCount}/${session.total} · '
            '노드 클릭으로 팩트체크 완료 표시',
            style: const TextStyle(fontSize: 11, color: SgpAppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final node in session.nodes)
                ActionChip(
                  avatar: Icon(
                    session.isVerified(node.nodeId)
                        ? Icons.verified
                        : Icons.open_in_new,
                    size: 16,
                    color: session.isVerified(node.nodeId)
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFF64B5F6),
                  ),
                  label: Text(
                    node.label.length > 28
                        ? '${node.label.substring(0, 28)}…'
                        : node.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => onVerified(node.nodeId),
                  backgroundColor: session.isVerified(node.nodeId)
                      ? const Color(0xFF1B5E20).withValues(alpha: 0.45)
                      : const Color(0xFF1565C0).withValues(alpha: 0.35),
                  side: BorderSide(
                    color: session.isVerified(node.nodeId)
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFF42A5F5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
