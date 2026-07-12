/// PhysicalThreatLevel ↔ ResistanceStage 브리지.
library;

import 'sgp_constitutional_force_engine.dart';

/// 피의자 위해(저항) 수준 — 경찰청 5단계 표준.
enum PhysicalThreatLevel {
  compliance,
  passiveResistance,
  activeResistance,
  violentAttack,
  lethalAttack,
}

extension PhysicalThreatLevelBridge on PhysicalThreatLevel {
  int get stageNumber => index + 1;

  ResistanceStage get resistanceStage => switch (this) {
        PhysicalThreatLevel.compliance => ResistanceStage.compliance,
        PhysicalThreatLevel.passiveResistance => ResistanceStage.passiveResistance,
        PhysicalThreatLevel.activeResistance => ResistanceStage.activeResistance,
        PhysicalThreatLevel.violentAttack => ResistanceStage.violentResistance,
        PhysicalThreatLevel.lethalAttack => ResistanceStage.lethalResistance,
      };

  static PhysicalThreatLevel? fromResistanceStage(ResistanceStage stage) =>
      switch (stage) {
        ResistanceStage.compliance => PhysicalThreatLevel.compliance,
        ResistanceStage.passiveResistance => PhysicalThreatLevel.passiveResistance,
        ResistanceStage.activeResistance => PhysicalThreatLevel.activeResistance,
        ResistanceStage.violentResistance => PhysicalThreatLevel.violentAttack,
        ResistanceStage.lethalResistance => PhysicalThreatLevel.lethalAttack,
      };
}

extension ResistanceStageBridge on ResistanceStage {
  PhysicalThreatLevel get physicalThreatLevel =>
      PhysicalThreatLevelBridge.fromResistanceStage(this)!;

  PoliceForceTier get defaultForceTier => switch (stageNumber) {
        1 => PoliceForceTier.verbalControl,
        2 => PoliceForceTier.contactControl,
        3 => PoliceForceTier.lowRiskForce,
        4 => PoliceForceTier.mediumRiskForce,
        _ => PoliceForceTier.highRiskForce,
      };
}
