/// SGP-Agent 현장 UI — 다크 모드·양자적 법률 비교·무전 상태 표시.
library;

import 'package:flutter/material.dart';

import 'sgp_app_theme.dart';
import 'sgp_agent_stt.dart';
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
    final color = listening
        ? SgpFieldColors.accentBlue
        : radioActive
            ? SgpFieldColors.safeGreen
            : SgpFieldColors.cautionOrange;

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
            radioActive ? Icons.bluetooth_connected : Icons.bluetooth_searching,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  radioActive
                      ? '📡 Bluetooth 무전기 연동 활성화 완료'
                      : '📡 무전 오디오 대기 — 블루투스 SCO/USB 연결 확인',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  sttEngine.inputSourceLabel,
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

class _PerspectiveCard extends StatelessWidget {
  const _PerspectiveCard({
    required this.perspective,
    required this.urgency,
    this.showPrecedentGuide = false,
    this.onTap,
  });

  final LegalPerspective perspective;
  final SgpUrgencyLevel urgency;
  final bool showPrecedentGuide;
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

/// 실시간 행동 지침 바.
class SgpActionGuidanceBar extends StatelessWidget {
  const SgpActionGuidanceBar({
    super.key,
    required this.guidance,
    required this.urgency,
  });

  final String guidance;
  final SgpUrgencyLevel urgency;

  @override
  Widget build(BuildContext context) {
    final color = urgencyColor(urgency);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
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
