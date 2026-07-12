/// S7-A — 5단계 물리력 시연 Mock 프리셋 (Flutter 비의존).
library;

class SgpDemoForceScenario {
  const SgpDemoForceScenario({
    required this.id,
    required this.stage,
    required this.resistanceLabel,
    required this.radioText,
    required this.expectedForceTier,
    required this.expectedExcessive,
  });

  final String id;
  final int stage;
  final String resistanceLabel;
  final String radioText;
  final int expectedForceTier;
  final bool expectedExcessive;

  factory SgpDemoForceScenario.fromJson(Map<String, dynamic> json) {
    return SgpDemoForceScenario(
      id: json['id'] as String? ?? 'force_demo',
      stage: json['stage'] as int? ?? 1,
      resistanceLabel: json['resistance_label'] as String? ?? '',
      radioText: json['radio_text'] as String? ?? '',
      expectedForceTier: json['expected_force_tier'] as int? ?? 1,
      expectedExcessive: json['expected_excessive'] as bool? ?? false,
    );
  }
}

class SgpDemoForceScenarioPack {
  const SgpDemoForceScenarioPack({
    required this.title,
    required this.scenarios,
  });

  final String title;
  final List<SgpDemoForceScenario> scenarios;

  factory SgpDemoForceScenarioPack.fromJson(Map<String, dynamic> json) {
    final list = json['scenarios'] as List<dynamic>? ?? [];
    return SgpDemoForceScenarioPack(
      title: json['title'] as String? ?? '물리력 시연',
      scenarios: list
          .map((e) => SgpDemoForceScenario.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
