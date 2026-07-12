/// S7-D — 종합 민원 가이드 UI (고대비·액션 버튼).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sgp_app_theme.dart';
import 'sgp_civil_complaint_data.dart';

/// 종합 민원해결 — 부서 안내·행정지도·기관 연결 패널.
class SgpCivilComplaintGuidePanel extends StatelessWidget {
  const SgpCivilComplaintGuidePanel({
    super.key,
    required this.route,
    this.onDismiss,
  });

  final CivilComplaintRouteResult route;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final type = route.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: type.policeDispatchWarning
            ? SgpFieldColors.cautionOrange.withValues(alpha: 0.12)
            : SgpFieldColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: type.policeDispatchWarning
              ? SgpFieldColors.cautionOrange
              : SgpFieldColors.accentBlue.withValues(alpha: 0.5),
          width: type.policeDispatchWarning ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                type.policeDispatchWarning
                    ? Icons.transfer_within_a_station
                    : Icons.support_agent,
                color: type.policeDispatchWarning
                    ? SgpFieldColors.cautionOrange
                    : SgpFieldColors.accentBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '종합 민원 가이드 — ${type.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SgpFieldColors.fieldGuideNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SgpFieldColors.fieldGuideNavy,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  tooltip: '민원 가이드 닫기',
                ),
            ],
          ),
          if (route.matchedKeywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '인식 키워드: ${route.matchedKeywords.join(', ')} '
              '(신뢰도 ${(route.confidence * 100).round()}%)',
              style: const TextStyle(
                fontSize: 10,
                color: SgpFieldColors.fieldGuideBody,
              ),
            ),
          ],
          if (type.policeDispatchWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SgpFieldColors.cautionOrange),
              ),
              child: const Text(
                '해당 사안은 민사·행정 소관으로 경찰 강제력 행사가 제한됩니다. '
                '아래 이관 기관을 안내하세요.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: SgpFieldColors.fieldGuideNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (type.switchToGoldenTimeProfile) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SgpFieldColors.criticalRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SgpFieldColors.criticalRed),
              ),
              child: const Text(
                'S7-C 골든타임: 실종·가출 프로필(최근 사진·특징·마지막 목격) 즉시 작성',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: SgpFieldColors.fieldGuideNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '해결 경로',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: SgpFieldColors.fieldGuideNavy,
            ),
          ),
          const SizedBox(height: 4),
          ...type.jurisdictions.map(_buildJurisdictionRow),
          if (type.requiredDocuments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '필요 서류',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: SgpFieldColors.fieldGuideNavy,
              ),
            ),
            const SizedBox(height: 4),
            ...type.requiredDocuments.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${d.required ? '•' : '○'} ${d.label}',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: SgpFieldColors.fieldGuideBody,
                  ),
                ),
              ),
            ),
          ],
          if (type.adminGuideLv8.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type.adminGuideLv8,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: SgpFieldColors.fieldGuideNavy,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (type.mapUrl != null)
                _ActionChip(
                  icon: Icons.map_outlined,
                  label: '지도 보기',
                  onTap: () => _openUrl(context, type.mapUrl!),
                ),
              if (type.formUrl != null)
                _ActionChip(
                  icon: Icons.description_outlined,
                  label: '서식 받기',
                  onTap: () => _openUrl(context, type.formUrl!),
                ),
              if (type.phone != null)
                _ActionChip(
                  icon: Icons.phone_in_talk_outlined,
                  label: '기관 전화 (${type.phone})',
                  onTap: () => _dialPhone(context, type.phone!),
                ),
            ],
          ),
          if (route.ontologyTripleCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '온톨로지 연결: ${route.ontologyTripleCount}건 (has_jurisdiction · requires_document)',
              style: const TextStyle(
                fontSize: 9,
                color: SgpFieldColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJurisdictionRow(CivilComplaintJurisdiction j) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            j.transfer ? Icons.subdirectory_arrow_right : Icons.arrow_forward,
            size: 14,
            color: j.transfer
                ? SgpFieldColors.cautionOrange
                : SgpFieldColors.accentBlue,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              j.transfer ? '[기관 이관] ${j.agencyName}' : j.agencyName,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: SgpFieldColors.fieldGuideBody,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('링크 복사됨 — 브라우저에 붙여넣기: $url')),
      );
    }
  }

  Future<void> _dialPhone(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await Clipboard.setData(ClipboardData(text: digits));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전화번호 복사됨: $digits (통화 앱에서 붙여넣기)')),
      );
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: SgpFieldColors.fieldGuideNavy),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: SgpFieldColors.fieldGuideNavy,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: SgpFieldColors.border),
      onPressed: onTap,
    );
  }
}

/// 종합 민원 가이드 전용 스크롤 래퍼 (S7-B 가독성 스펙).
class SgpCivilComplaintGuideScreen extends StatelessWidget {
  const SgpCivilComplaintGuideScreen({
    super.key,
    required this.route,
  });

  final CivilComplaintRouteResult route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgpFieldColors.background,
      appBar: AppBar(
        title: const Text('종합 민원 가이드'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SgpCivilComplaintGuidePanel(route: route),
      ),
    );
  }
}
