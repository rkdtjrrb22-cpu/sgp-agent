/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Digital Evidence CoC Traffic Light Banner
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 디지털 증거 전용 신호등 배너 (체포/유치 신호등과 분리).
library;

import 'package:flutter/material.dart';

import '../../agent/sgp_app_theme.dart';
import '../sgp_evidence_coc_engine.dart';

class SgpEvidenceCoCTrafficBanner extends StatelessWidget {
  const SgpEvidenceCoCTrafficBanner({
    super.key,
    required this.session,
    this.onAdvanceStep,
    this.onOpenGuide,
  });

  final EvidenceCoCSession session;
  final VoidCallback? onAdvanceStep;
  final VoidCallback? onOpenGuide;

  Color get _color {
    switch (session.trafficLight) {
      case EvidenceCoCTrafficLight.green:
        return SgpFieldColors.safeGreen;
      case EvidenceCoCTrafficLight.yellow:
        return SgpFieldColors.cautionOrange;
      case EvidenceCoCTrafficLight.red:
        return SgpFieldColors.criticalRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = session.nextRequiredStep;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _color,
          width: session.trafficLight == EvidenceCoCTrafficLight.red ? 2.5 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '디지털 증거 CoC · ${session.trafficLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: _color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${session.completedCount}/4',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CoCStepStrip(session: session),
          if (session.blindSpots.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              SgpEvidenceCoCEngine.supplementaryInvestigationWarning(session),
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: session.trafficLight == EvidenceCoCTrafficLight.red
                    ? SgpFieldColors.criticalRed
                    : SgpFieldColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              session.blindSpots.first.actionGuide,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: SgpFieldColors.textSecondary,
              ),
            ),
          ] else if (next != null) ...[
            const SizedBox(height: 10),
            Text(
              '다음 단계  ${next.label}',
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: SgpFieldColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onAdvanceStep != null && next != null)
                FilledButton.tonal(
                  onPressed: onAdvanceStep,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    '단계 완료 · ${next.shortLabel}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (onOpenGuide != null)
                TextButton(
                  onPressed: onOpenGuide,
                  child: const Text('조치 가이드', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoCStepStrip extends StatelessWidget {
  const _CoCStepStrip({required this.session});

  final EvidenceCoCSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < EvidenceCoCStep.values.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: (session.steps[EvidenceCoCStep.values[i - 1]]?.completed ??
                        false)
                    ? SgpFieldColors.safeGreen.withValues(alpha: 0.7)
                    : SgpFieldColors.border,
              ),
            ),
          _StepChip(
            index: i + 1,
            label: EvidenceCoCStep.values[i].shortLabel,
            done: session.steps[EvidenceCoCStep.values[i]]?.completed ?? false,
            current: session.nextRequiredStep == EvidenceCoCStep.values[i],
          ),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.label,
    required this.done,
    required this.current,
  });

  final int index;
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? SgpFieldColors.safeGreen
        : current
            ? SgpFieldColors.cautionOrange
            : SgpFieldColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done || current ? color.withValues(alpha: 0.18) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: current ? 2 : 1.2),
          ),
          child: Text(
            done ? '✓' : '$index',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 52,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
