/// 헌법 비례성 · 5단계 물리력 상시 인디케이터 UI.
library;

import 'package:flutter/material.dart';

import 'sgp_app_theme.dart';
import 'sgp_constitutional_force_engine.dart';

/// 화면 최상단 — 저항 단계·비례성 적합도·헌법 배지.
class SgpConstitutionalForceIndicator extends StatelessWidget {
  const SgpConstitutionalForceIndicator({
    super.key,
    required this.assessment,
    this.selectedForceTier,
    this.onForceTierChanged,
    this.flashExcessive = false,
  });

  final ConstitutionalForceAssessment? assessment;
  final PoliceForceTier? selectedForceTier;
  final ValueChanged<PoliceForceTier>? onForceTierChanged;
  final bool flashExcessive;

  @override
  Widget build(BuildContext context) {
    if (assessment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SgpFieldColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SgpFieldColors.border),
        ),
        child: Text(
          '5단계 물리력 · 헌법 비례성 — 무전 입력 또는 저항 단계 평가 시 활성화',
          style: TextStyle(fontSize: 11, color: SgpFieldColors.textSecondary),
        ),
      );
    }

    final a = assessment!;
    final excessive = a.isExcessive;
    final color = excessive
        ? SgpFieldColors.criticalRed
        : a.resistanceStage.stageNumber >= 3
            ? SgpFieldColors.cautionOrange
            : SgpFieldColors.safeGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: flashExcessive && excessive
            ? SgpFieldColors.criticalRed.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: excessive ? SgpFieldColors.criticalRed : color.withValues(alpha: 0.55),
          width: excessive ? 2.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                excessive ? Icons.warning_amber_rounded : Icons.balance,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '저항 ${a.resistanceStage.stageNumber}단계: ${a.resistanceStage.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              _BadgeChip(label: a.badgeLabel, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '대응 ${a.forceTier.stageNumber}단계: ${a.forceTier.label} · '
            '비례성 ${(a.proportionalityScore * 100).round()}%',
            style: const TextStyle(fontSize: 10, color: SgpFieldColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            a.warningMessage,
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              fontWeight: excessive ? FontWeight.bold : FontWeight.normal,
              color: excessive ? SgpFieldColors.criticalRed : SgpFieldColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${a.principle.title} · ${a.constitutionalBasis}',
            style: TextStyle(fontSize: 9, color: SgpFieldColors.textSecondary, height: 1.3),
          ),
          if (a.ontologyTripleCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '온톨로지 SPO: ${a.ontologyTripleCount} triples (${a.ontologySource})',
              style: TextStyle(fontSize: 9, color: SgpFieldColors.textSecondary),
            ),
          ],
          if (excessive) ...[
            const SizedBox(height: 6),
            Text(
              'IsExcessive=true — 헌법(LV1) 과잉금지 원칙 최우선',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: SgpFieldColors.criticalRed,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (onForceTierChanged != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: PoliceForceTier.values.map((tier) {
                final selected = (selectedForceTier ?? a.forceTier) == tier;
                return ChoiceChip(
                  label: Text('${tier.stageNumber}단계', style: const TextStyle(fontSize: 10)),
                  selected: selected,
                  onSelected: (_) => onForceTierChanged!(tier),
                  selectedColor: color.withValues(alpha: 0.25),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// 5단계·과잉 물리력 전체화면 경고.
Future<void> showConstitutionalForceAlertDialog(
  BuildContext context, {
  required ConstitutionalForceAssessment assessment,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !assessment.isExcessive,
    builder: (ctx) => AlertDialog(
      backgroundColor: assessment.isExcessive ? Colors.red.shade50 : null,
      title: Row(
        children: [
          Icon(
            Icons.gavel,
            color: assessment.isExcessive ? Colors.red.shade900 : Colors.orange.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              assessment.badgeLabel,
              style: TextStyle(
                color: assessment.isExcessive ? Colors.red.shade900 : null,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              assessment.warningMessage,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              assessment.constitutionalBasis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
            ),
            if (assessment.isExcessive) ...[
              const SizedBox(height: 12),
              Text(
                'IsExcessive = true',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('확인 — 수사관 주체적 판단 유지'),
        ),
      ],
    ),
  );
}
