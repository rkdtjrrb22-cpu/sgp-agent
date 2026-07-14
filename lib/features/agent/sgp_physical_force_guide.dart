/// 체포 초기 단계 — 5단계 물리력 대응 가이드 UI.
library;

import 'package:flutter/material.dart';

import 'sgp_constitutional_force_engine.dart';
import 'sgp_physical_force_matrix.dart';
import 'sgp_physical_threat_level.dart';

export 'sgp_physical_force_matrix.dart';
export 'sgp_physical_threat_level.dart';

extension PhysicalThreatLevelLabel on PhysicalThreatLevel {
  String get displayName => switch (this) {
        PhysicalThreatLevel.compliance => '1단계: 순응·협조',
        PhysicalThreatLevel.passiveResistance => '2단계: 소극적 저항',
        PhysicalThreatLevel.activeResistance => '3단계: 적극적 저항',
        PhysicalThreatLevel.violentAttack => '4단계: 폭력적 저항',
        PhysicalThreatLevel.lethalAttack => '5단계: 치명적 저항',
      };

  String get description => switch (this) {
        PhysicalThreatLevel.compliance => '지시에 순응·협조 — 언어적 통제로 충분',
        PhysicalThreatLevel.passiveResistance => '손을 뒤로 숨김·몸을 돌림·말로만 거부',
        PhysicalThreatLevel.activeResistance => '밀침·발로 차기·도주 시도·장애물 던지기',
        PhysicalThreatLevel.violentAttack => '폭행·위협·흉기 휘두름·경찰관 공격',
        PhysicalThreatLevel.lethalAttack => '흉기·총기 등 생명 위협 수단 사용',
      };

  Color get accentColor => switch (this) {
        PhysicalThreatLevel.compliance => Colors.green.shade700,
        PhysicalThreatLevel.passiveResistance => Colors.blue.shade700,
        PhysicalThreatLevel.activeResistance => Colors.orange.shade800,
        PhysicalThreatLevel.violentAttack => Colors.red.shade700,
        PhysicalThreatLevel.lethalAttack => Colors.purple.shade900,
      };
}

/// 경찰 물리력 행사 기준 매핑 (UI 위임).
class SgpPhysicalForceGuide {
  const SgpPhysicalForceGuide._();

  static PhysicalForceResponse responseFor(PhysicalThreatLevel level) =>
      SgpPhysicalForceMatrix.responseFor(level);

  static PhysicalThreatLevel? fromJson(String? name) {
    if (name == null) return null;
    try {
      return PhysicalThreatLevel.values.byName(name);
    } catch (_) {
      return null;
    }
  }
}

/// 타임라인·현장 패널용 컴팩트 가이드 UI.
class SgpPhysicalForceGuideWidget extends StatelessWidget {
  const SgpPhysicalForceGuideWidget({
    super.key,
    required this.selectedLevel,
    required this.onLevelChanged,
    this.compact = false,
    this.assessment,
    this.rawText = '',
    this.forceExecutionLogged = false,
    this.onForceExecutionLogged,
  });

  final PhysicalThreatLevel? selectedLevel;
  final ValueChanged<PhysicalThreatLevel> onLevelChanged;
  final bool compact;
  final ConstitutionalForceAssessment? assessment;
  final String rawText;
  final bool forceExecutionLogged;
  final ValueChanged<String>? onForceExecutionLogged;

  @override
  Widget build(BuildContext context) {
    final response =
        selectedLevel != null ? SgpPhysicalForceGuide.responseFor(selectedLevel!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '피의자 저항 단계 평가 (5단계)',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        ...PhysicalThreatLevel.values.map((level) {
          final color = level.accentColor;
          final selected = selectedLevel == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: selected ? color.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onLevelChanged(level),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? color : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: selected ? color : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              level.displayName,
                              style: TextStyle(
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.bold,
                                color: selected ? color : Colors.black87,
                              ),
                            ),
                            if (!compact)
                              Text(
                                level.description,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (assessment?.isExcessive == true) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade400),
            ),
            child: Text(
              'IsExcessive=true — ${assessment!.warningMessage}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
        if (response != null) ...[
          const SizedBox(height: 8),
          _ResponsePanel(
            response: response,
            compact: compact,
            onForceExecutionLogged: onForceExecutionLogged,
            forceExecutionLogged: forceExecutionLogged,
          ),
        ],
      ],
    );
  }
}

class _ResponsePanel extends StatelessWidget {
  const _ResponsePanel({
    required this.response,
    required this.compact,
    this.onForceExecutionLogged,
    this.forceExecutionLogged = false,
  });

  final PhysicalForceResponse response;
  final bool compact;
  final ValueChanged<String>? onForceExecutionLogged;
  final bool forceExecutionLogged;

  @override
  Widget build(BuildContext context) {
    final color = response.level.accentColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  response.summary,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${response.legalBasis} · 권고 ${response.recommendedForceTier.label}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          _bulletSection('허용 장구', response.allowedEquipment, Icons.build_circle_outlined, color),
          const SizedBox(height: 6),
          _bulletSection('허용 기술', response.allowedTechniques, Icons.pan_tool_alt_outlined, color),
          const SizedBox(height: 6),
          _bulletSection(
            '절차 요건',
            response.proceduralRequirements,
            Icons.fact_check_outlined,
            color,
            highlight: true,
          ),
          if (onForceExecutionLogged != null &&
              response.level.stageNumber >= 2) ...[
            const SizedBox(height: 8),
            Text(
              forceExecutionLogged
                  ? '물리력 집행 기록됨 (사후 패키지 → 내근 방패)'
                  : '물리력 집행 기록',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: Text(
                    '제압 기록',
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onForceExecutionLogged!('물리력 제압'),
                ),
                if (response.level.stageNumber >= 4)
                  ActionChip(
                    label: Text(
                      '테이저 발사',
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onForceExecutionLogged!('테이저건 발사'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bulletSection(
    String title,
    List<String> items,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 10, color: color)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
                      color: highlight ? Colors.red.shade900 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
