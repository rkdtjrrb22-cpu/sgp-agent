/// S8-UI — 종합 민원 가이드 (고대비·글래스모피즘·엄지존).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sgp_app_theme.dart';
import '../sgp_civil_complaint_data.dart';

/// 스크롤 가능한 가이드 본문 (글래스 카드).
class SgpCivilComplaintGuidePanel extends StatelessWidget {
  const SgpCivilComplaintGuidePanel({
    super.key,
    required this.route,
    this.onDismiss,
    this.embedded = true,
  });

  final CivilComplaintRouteResult route;
  final VoidCallback? onDismiss;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final type = route.type;

    return _SgpGlassGuideCard(
      accentGradient: type.policeDispatchWarning
          ? const [SgpCivilGuideColors.dispatchWarningText, Color(0xFFFF8A65)]
          : const [SgpCivilGuideColors.neonCyan, SgpCivilGuideColors.emerald],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, type),
          if (route.matchedKeywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildKeywords(route),
          ],
          if (type.policeDispatchWarning) ...[
            const SizedBox(height: 10),
            _buildDispatchWarning(),
          ],
          if (type.switchToGoldenTimeProfile) ...[
            const SizedBox(height: 10),
            _buildGoldenTimeAlert(),
          ],
          const SizedBox(height: 14),
          _sectionTitle('해결 경로'),
          const SizedBox(height: 6),
          ...type.jurisdictions.map(_buildJurisdictionRow),
          if (type.requiredDocuments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionTitle('필요 서류'),
            const SizedBox(height: 6),
            ...type.requiredDocuments.map(_buildDocumentRow),
          ],
          if (type.adminGuideLv8.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionTitle('행정 지도 (LV8)'),
            const SizedBox(height: 6),
            _buildAdminGuide(type.adminGuideLv8),
          ],
          if (embedded) ...[
            const SizedBox(height: 16),
            SgpCivilComplaintThumbActions(type: type),
          ],
          if (route.ontologyTripleCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '온톨로지 ${route.ontologyTripleCount}건 · has_jurisdiction · requires_document',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: SgpCivilGuideColors.neonCyan.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CivilComplaintType type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SgpCivilGuideColors.neonCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            type.policeDispatchWarning
                ? Icons.transfer_within_a_station
                : Icons.support_agent,
            color: type.policeDispatchWarning
                ? SgpCivilGuideColors.dispatchWarningText
                : SgpCivilGuideColors.neonCyan,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '종합 민원 가이드',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.emerald,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                type.category,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.neonCyan,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                type.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.pureWhite,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (onDismiss != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: SgpCivilGuideColors.pureWhite,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeywords(CivilComplaintRouteResult route) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('인식 키워드'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final kw in route.matchedKeywords)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: SgpCivilGuideColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SgpCivilGuideColors.emerald.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  kw,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SgpCivilGuideColors.pureWhite,
                  ),
                ),
              ),
            Text(
              '${(route.confidence * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SgpCivilGuideColors.neonCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDispatchWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgpCivilGuideColors.dispatchWarningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgpCivilGuideColors.dispatchWarningText),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: SgpCivilGuideColors.dispatchWarningText, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '해당 사안은 민사·행정 소관으로 경찰 강제력 행사가 제한됩니다. '
              '아래 이관 기관을 안내하세요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SgpCivilGuideColors.dispatchWarningText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldenTimeAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgpCivilGuideColors.goldenTimeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgpCivilGuideColors.goldenTimeText),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_outlined, color: SgpCivilGuideColors.goldenTimeText, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'S7-C 골든타임: 실종·가출 프로필(최근 사진·특징·마지막 목격) 즉시 작성',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SgpCivilGuideColors.goldenTimeText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SgpCivilGuideColors.neonCyan,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildJurisdictionRow(CivilComplaintJurisdiction j) {
    final iconColor =
        j.transfer ? SgpCivilGuideColors.dispatchWarningText : SgpCivilGuideColors.emerald;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            j.transfer ? Icons.subdirectory_arrow_right : Icons.arrow_forward_rounded,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              j.transfer ? '[기관 이관] ${j.agencyName}' : j.agencyName,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SgpCivilGuideColors.pureWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(CivilComplaintDocument d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            d.required ? Icons.fiber_manual_record : Icons.circle_outlined,
            size: d.required ? 10 : 14,
            color: SgpCivilGuideColors.emerald,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d.label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SgpCivilGuideColors.pureWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminGuide(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SgpCivilGuideColors.neonCyan.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: SgpCivilGuideColors.pureWhite,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 하단 30% 엄지존 — 기관 전화·지도·서식 복사.
class SgpCivilComplaintThumbActions extends StatelessWidget {
  const SgpCivilComplaintThumbActions({
    super.key,
    required this.type,
  });

  final CivilComplaintType type;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (type.phone != null)
        _ThumbActionCard(
          icon: Icons.phone_in_talk_rounded,
          label: '기관 전화',
          subtitle: type.phone!,
          primary: true,
          onTap: () => _dialPhone(context, type.phone!),
        ),
      if (type.mapUrl != null)
        _ThumbActionCard(
          icon: Icons.map_rounded,
          label: '지도 보기',
          subtitle: '링크 복사',
          onTap: () => _copyLink(context, type.mapUrl!, '지도 링크'),
        ),
      if (type.formUrl != null)
        _ThumbActionCard(
          icon: Icons.content_copy_rounded,
          label: '서식 복사',
          subtitle: 'URL 클립보드',
          onTap: () => _copyLink(context, type.formUrl!, '서식 URL'),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '현장 액션 (엄지존)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SgpCivilGuideColors.neonCyan,
          ),
        ),
        const SizedBox(height: 8),
        ...actions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: action,
          ),
        ),
      ],
    );
  }

  static Future<void> _copyLink(
    BuildContext context,
    String url,
    String label,
  ) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 복사됨')),
      );
    }
  }

  static Future<void> _dialPhone(BuildContext context, String phone) async {
    HapticFeedback.mediumImpact();
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await Clipboard.setData(ClipboardData(text: digits));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전화번호 복사됨: $digits')),
      );
    }
  }
}

class _ThumbActionCard extends StatelessWidget {
  const _ThumbActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final glowColor = primary
        ? SgpCivilGuideColors.neonCyan
        : SgpCivilGuideColors.emerald;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: primary
                ? SgpCivilGuideColors.neonCyan.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: glowColor.withValues(alpha: primary ? 0.85 : 0.45),
              width: primary ? 1.5 : 1,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 26, color: glowColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SgpCivilGuideColors.pureWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SgpCivilGuideColors.pureWhite.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: glowColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SgpGlassGuideCard extends StatelessWidget {
  const _SgpGlassGuideCard({
    required this.child,
    required this.accentGradient,
  });

  final Widget child;
  final List<Color> accentGradient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: accentGradient.map((c) => c.withValues(alpha: 0.55)).toList(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: SgpCivilGuideColors.glassFill,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
