/// SGP-Agent 현장 UI — 다크 모드·양자적 법률 비교·무전 상태 표시.
library;

import 'package:flutter/material.dart';

import 'sgp_app_theme.dart';
import 'sgp_agent_stt.dart';
import 'sgp_legal_hierarchy.dart';
import 'sgp_legal_hierarchy_tree.dart';
import 'sgp_quantum_legal_engine.dart';

Color urgencyColor(SgpUrgencyLevel level) => switch (level) {
      SgpUrgencyLevel.safe => SgpFieldColors.safeGreen,
      SgpUrgencyLevel.caution => SgpFieldColors.cautionOrange,
      SgpUrgencyLevel.critical => SgpFieldColors.criticalRed,
    };

/// 블루투스·무전 오디오 연결 상태바.
class SgpBluetoothStatusBar extends StatelessWidget {
  const SgpBluetoothStatusBar({
    super.key,
    required this.sttEngine,
    required this.sttState,
    this.otaStatus,
  });

  final SgpSttEngine sttEngine;
  final SttSessionState sttState;
  final String? otaStatus;

  @override
  Widget build(BuildContext context) {
    final radioActive = sttEngine.bluetoothScoActive || sttEngine.usbAudioDetected;
    final listening = sttState == SttSessionState.listening;
    final whisperReady = sttEngine.whisperBound;
    final color = listening
        ? SgpFieldColors.accentBlue
        : whisperReady
            ? SgpFieldColors.navy
            : radioActive
                ? SgpFieldColors.safeGreen
                : SgpFieldColors.cautionOrange;

    final headline = listening
        ? '🎙 STT 수신 중 — ${sttEngine.activeInputLabel}'
        : whisperReady
            ? '🧠 Whisper 온디바이스 · ${sttEngine.activeInputLabel}'
            : radioActive
                ? '📡 Bluetooth/USB 무전 연동 · ${sttEngine.activeInputLabel}'
                : '📡 무전 오디오 대기 — SCO/USB 연결 확인';

    final whisperHint = sttEngine.whisperModelReady && !sttEngine.whisperNativeLoaded
        ? ' · JNI 로드 필요'
        : sttEngine.whisperModelReady && !sttEngine.whisperBound
            ? ' · 모델 배치됨'
            : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            listening
                ? Icons.mic
                : whisperReady
                    ? Icons.memory
                    : radioActive
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '${sttEngine.inputSourceLabel}$whisperHint',
                  style: const TextStyle(fontSize: 10, color: SgpFieldColors.textSecondary),
                ),
              ],
            ),
          ),
          if (otaStatus != null)
            Tooltip(
              message: otaStatus!,
              child: Icon(Icons.cloud_done, size: 16, color: SgpFieldColors.accentBlue),
            ),
        ],
      ),
    );
  }
}

/// S8 — 음성 인식 중 상단 인디케이터 ("현장 음성 분석 중…" 펄스 애니메이션).
class SgpSttAnalyzingBanner extends StatefulWidget {
  const SgpSttAnalyzingBanner({super.key});

  @override
  State<SgpSttAnalyzingBanner> createState() => _SgpSttAnalyzingBannerState();
}

class _SgpSttAnalyzingBannerState extends State<SgpSttAnalyzingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = 0.45 + 0.55 * _controller.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: SgpFieldColors.accentBlue.withValues(alpha: 0.10 + 0.08 * _controller.value),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: SgpFieldColors.accentBlue.withValues(alpha: pulse),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.graphic_eq,
                size: 20,
                color: SgpFieldColors.accentBlue.withValues(alpha: pulse),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '현장 음성 분석 중…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SgpFieldColors.accentBlue.withValues(alpha: 0.7 + 0.3 * _controller.value),
                  ),
                ),
              ),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SgpFieldColors.accentBlue.withValues(alpha: pulse),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 양자적 법률 비교 — 가로 대조 카드.
class SgpQuantumComparisonPanel extends StatelessWidget {
  const SgpQuantumComparisonPanel({
    super.key,
    required this.comparison,
    this.onPerspectiveTap,
    this.showPrecedentGuides = false,
  });

  final SgpQuantumLegalComparison comparison;
  final void Function(LegalPerspective perspective)? onPerspectiveTap;

  /// CoT 추론 후 각 카드 하단 [핵심 판례 가이드] 표시.
  final bool showPrecedentGuides;

  Set<String> get _demotedIds =>
      comparison.hierarchyGuidance?.demotedPerspectiveIds.toSet() ?? const {};

  @override
  Widget build(BuildContext context) {
    final cards = comparison.perspectives.take(2).toList();
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.balance, color: urgencyColor(comparison.urgencyLevel), size: 18),
            const SizedBox(width: 6),
            const Text(
              '⚖️ 양자적 법률 비교',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SgpFieldColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (comparison.hasLegalConflict)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SgpFieldColors.cautionOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '경합',
                  style: TextStyle(fontSize: 10, color: SgpFieldColors.cautionOrange),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comparison.summary,
          style: const TextStyle(fontSize: 11, color: SgpFieldColors.textSecondary, height: 1.35),
        ),
        if (comparison.hierarchy != null && !comparison.hierarchy!.isEmpty) ...[
          const SizedBox(height: 8),
          SgpLegalHierarchyViewPanel(resolution: comparison.hierarchy!),
        ],
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _PerspectiveCard(
                  perspective: cards[i],
                  urgency: comparison.urgencyLevel,
                  showPrecedentGuide: showPrecedentGuides,
                  demotedByHierarchy: _demotedIds.contains(cards[i].id),
                  onTap: onPerspectiveTap != null ? () => onPerspectiveTap!(cards[i]) : null,
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Sprint S1 — LV 1→8 준거법 체인 (가로 칩).
class SgpLegalHierarchyChainBar extends StatelessWidget {
  const SgpLegalHierarchyChainBar({
    super.key,
    required this.resolution,
    this.compact = false,
  });

  final SgpHierarchyResolution resolution;

  /// true면 헤더·충돌 문구 생략 (ViewPanel에서 사용).
  final bool compact;

  static Color _levelColor(LegalHierarchyLevel level) => switch (level) {
        LegalHierarchyLevel.constitution => const Color(0xFF818CF8),
        LegalHierarchyLevel.law => SgpFieldColors.navy,
        LegalHierarchyLevel.presidentialDecree => const Color(0xFF38BDF8),
        LegalHierarchyLevel.ministerialRule => const Color(0xFF22D3EE),
        LegalHierarchyLevel.localOrdinance => const Color(0xFF34D399),
        LegalHierarchyLevel.administrativeRule => const Color(0xFFA3E635),
        LegalHierarchyLevel.internalRegulation => SgpFieldColors.cautionOrange,
        LegalHierarchyLevel.manual => SgpFieldColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final chain = resolution.chain;
    if (chain.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 14, color: SgpFieldColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                resolution.primaryLawTitle != null
                    ? '위계 · ${resolution.primaryLawTitle}'
                    : '법적 위계 (Top-Down)',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: SgpFieldColors.textSecondary,
                ),
              ),
              if (resolution.hasUpperLawWarnings) ...[
                const SizedBox(width: 6),
                Icon(Icons.warning_amber_rounded, size: 14, color: SgpFieldColors.cautionOrange),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < chain.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.chevron_right, size: 14, color: SgpFieldColors.border),
                  ),
                _HierarchyChip(node: chain[i]),
              ],
            ],
          ),
        ),
        if (!compact && resolution.conflicts.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final c in resolution.conflicts.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '⚠️ ${c.message}',
                style: TextStyle(
                  fontSize: 9,
                  color: SgpFieldColors.cautionOrange.withValues(alpha: 0.95),
                  height: 1.3,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _HierarchyChip extends StatelessWidget {
  const _HierarchyChip({required this.node});

  final LegalHierarchyNode node;

  @override
  Widget build(BuildContext context) {
    final color = SgpLegalHierarchyChainBar._levelColor(node.level);
    final title = node.title.length > 12 ? '${node.title.substring(0, 12)}…' : node.title;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        'LV${node.level.value} $title',
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Sprint S3 — 체인(가로) ↔ 트리(아코디언) 전환.
class SgpLegalHierarchyViewPanel extends StatefulWidget {
  const SgpLegalHierarchyViewPanel({super.key, required this.resolution});

  final SgpHierarchyResolution resolution;

  @override
  State<SgpLegalHierarchyViewPanel> createState() => _SgpLegalHierarchyViewPanelState();
}

class _SgpLegalHierarchyViewPanelState extends State<SgpLegalHierarchyViewPanel> {
  bool _showTree = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 14, color: SgpFieldColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.resolution.primaryLawTitle != null
                    ? '법적 위계 · ${widget.resolution.primaryLawTitle}'
                    : '법적 위계 (Top-Down)',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: SgpFieldColors.textSecondary,
                ),
              ),
            ),
            if (widget.resolution.hasUpperLawWarnings)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded, size: 14, color: SgpFieldColors.cautionOrange),
              ),
            _HierarchyViewToggle(
              showTree: _showTree,
              onChanged: (v) => setState(() => _showTree = v),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _showTree
              ? SgpLegalHierarchyTreeWidget(
                  key: const ValueKey('tree'),
                  resolution: widget.resolution,
                )
              : SgpLegalHierarchyChainBar(
                  key: const ValueKey('chain'),
                  resolution: widget.resolution,
                  compact: true,
                ),
        ),
      ],
    );
  }
}

class _HierarchyViewToggle extends StatelessWidget {
  const _HierarchyViewToggle({required this.showTree, required this.onChanged});

  final bool showTree;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SgpFieldColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SgpFieldColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HierarchyToggleChip(
            label: '체인',
            icon: Icons.linear_scale,
            selected: !showTree,
            onTap: () => onChanged(false),
          ),
          _HierarchyToggleChip(
            label: '트리',
            icon: Icons.account_tree,
            selected: showTree,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _HierarchyToggleChip extends StatelessWidget {
  const _HierarchyToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SgpFieldColors.navy : SgpFieldColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PerspectiveCard extends StatelessWidget {
  const _PerspectiveCard({
    required this.perspective,
    required this.urgency,
    this.showPrecedentGuide = false,
    this.demotedByHierarchy = false,
    this.onTap,
  });

  final LegalPerspective perspective;
  final SgpUrgencyLevel urgency;
  final bool showPrecedentGuide;
  final bool demotedByHierarchy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = perspective.recommended
        ? SgpFieldColors.safeGreen
        : urgencyColor(urgency);

    return Material(
      color: SgpFieldColors.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: perspective.recommended ? accent : SgpFieldColors.border,
              width: perspective.recommended ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    perspective.kind == 'special'
                        ? '특별법'
                        : perspective.kind == 'civil'
                            ? '민사'
                            : '형법',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  if (demotedByHierarchy) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: SgpFieldColors.textSecondary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '참고용',
                        style: TextStyle(fontSize: 8, color: SgpFieldColors.textSecondary.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                perspective.law,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: SgpFieldColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                perspective.attribute,
                style: const TextStyle(fontSize: 10, color: SgpFieldColors.textSecondary, height: 1.35),
              ),
              if (perspective.recommended) ...[
                const SizedBox(height: 6),
                Text(
                  '★ 권장 경로',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent),
                ),
              ],
              if (perspective.condition != null) ...[
                const SizedBox(height: 4),
                Text(
                  perspective.condition!,
                  style: const TextStyle(fontSize: 9, color: SgpFieldColors.accentBlue, height: 1.3),
                ),
              ],
              if (showPrecedentGuide &&
                  perspective.precedentGuide != null &&
                  perspective.precedentGuide!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SgpFieldColors.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SgpFieldColors.accentBlue.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 핵심 판례 가이드',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: SgpFieldColors.accentBlue,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        perspective.precedentGuide!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: SgpFieldColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 실시간 행동 지침 바 (S2 — 상위법 경고·Cross-Filter 배지).
class SgpActionGuidanceBar extends StatelessWidget {
  const SgpActionGuidanceBar({
    super.key,
    required this.guidance,
    required this.urgency,
    this.hierarchyGuidance,
  });

  final String guidance;
  final SgpUrgencyLevel urgency;
  final SgpHierarchyResolvedGuidance? hierarchyGuidance;

  @override
  Widget build(BuildContext context) {
    final color = urgencyColor(urgency);
    final hg = hierarchyGuidance;
    final showUpperLaw = hg?.hasUpperLawWarnings ?? false;
    final showCrossFilter = hg?.hasCrossFilterEffect ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: showUpperLaw ? SgpFieldColors.cautionOrange : color,
          width: showUpperLaw ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showUpperLaw || showCrossFilter)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (showUpperLaw)
                    _GuidanceBadge(
                      label: '상위법 경고',
                      icon: Icons.warning_amber_rounded,
                      color: SgpFieldColors.cautionOrange,
                    ),
                  if (showCrossFilter)
                    _GuidanceBadge(
                      label: 'Cross-Filter',
                      icon: Icons.filter_alt_outlined,
                      color: SgpFieldColors.navy,
                    ),
                  if (hg?.requiresManualReview ?? false)
                    _GuidanceBadge(
                      label: '수기 확인',
                      icon: Icons.edit_note,
                      color: SgpFieldColors.textSecondary,
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ 실시간 행동 지침: $guidance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (hg != null && hg.upperLawNotices.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final notice in hg.upperLawNotices.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  notice,
                  style: TextStyle(
                    fontSize: 11,
                    color: SgpFieldColors.cautionOrange.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GuidanceBadge extends StatelessWidget {
  const _GuidanceBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// 오작동 방지 자기판단 + 보고서 생성 하단 패널.
class SgpLifecycleFooter extends StatelessWidget {
  const SgpLifecycleFooter({
    super.key,
    required this.selfJudgmentAccepted,
    required this.onSelfJudgmentChanged,
    required this.canGenerateReport,
    required this.onGenerateReport,
  });

  final bool selfJudgmentAccepted;
  final ValueChanged<bool> onSelfJudgmentChanged;
  final bool canGenerateReport;
  final VoidCallback? onGenerateReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgpFieldColors.surface,
        border: Border(top: BorderSide(color: SgpFieldColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: selfJudgmentAccepted,
            onChanged: (v) => onSelfJudgmentChanged(v ?? false),
            title: const Text(
              '위 고지를 확인했으며, 본인 자기판단으로 확정합니다.',
              style: TextStyle(fontSize: 12, color: SgpFieldColors.textPrimary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: SgpFieldColors.navy,
            checkColor: SgpFieldColors.textOnAccent,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canGenerateReport && selfJudgmentAccepted ? onGenerateReport : null,
            icon: const Icon(Icons.article_outlined),
            label: const Text('판례 인용 초동조치 보고서 자동 생성'),
            style: FilledButton.styleFrom(
              backgroundColor: SgpFieldColors.navy,
              disabledBackgroundColor: SgpFieldColors.surfaceHigh,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 다크 모드 카드 래퍼.
class SgpFieldCard extends StatelessWidget {
  const SgpFieldCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SgpAppTheme.cardDecoration(),
      child: child,
    );
  }
}
