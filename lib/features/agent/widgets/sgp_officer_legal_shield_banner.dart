/// 파란색 — 적극적 저항(3단계) 이상 시 「경찰관 법률 조력 보호막」상태만 간략 표시.
/// 구제서·법리 복사는 외근에서 제외 — 내근 방패 아이콘 다이얼로그에서만.
library;

import 'package:flutter/material.dart';

import '../sgp_officer_defense_shield_assembler.dart';
import '../sgp_physical_threat_level.dart';
import '../sgp_constitutional_force_engine.dart';

class SgpOfficerLegalShieldBanner extends StatelessWidget {
  const SgpOfficerLegalShieldBanner({
    super.key,
    this.resistanceStage,
    this.threatLevel,
  });

  final ResistanceStage? resistanceStage;
  final PhysicalThreatLevel? threatLevel;

  bool get _active {
    if (threatLevel != null) {
      return SgpOfficerDefenseShieldAssembler.isLegalAidShieldActiveFromThreat(
        threatLevel,
      );
    }
    if (resistanceStage != null) {
      return SgpOfficerDefenseShieldAssembler.isLegalAidShieldActive(
        resistanceStage!,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    const blue = Color(0xFF1565C0);
    final stageNo =
        resistanceStage?.stageNumber ?? threatLevel?.stageNumber ?? 3;
    final stageLabel =
        resistanceStage?.label ?? threatLevel?.resistanceStage.label ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: blue, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '법률 조력 보호막 ON · 저항 $stageNo단계($stageLabel) — '
              '사후 패키지는 내근「방패」에서',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: blue,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
