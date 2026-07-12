/// 현장 시연 Mock 시나리오 데이터 (Flutter 비의존).
library;

class SgpDemoFieldScenario {
  const SgpDemoFieldScenario({
    required this.id,
    required this.title,
    required this.radioText,
    required this.checklist,
    required this.expected,
    this.verificationSteps = const [],
    this.timelineHint,
  });

  final String id;
  final String title;
  final String radioText;
  final SgpDemoChecklist checklist;
  final SgpDemoExpectedOutcome expected;
  final List<String> verificationSteps;
  final SgpDemoTimelineHint? timelineHint;

  factory SgpDemoFieldScenario.fromJson(Map<String, dynamic> json) {
    final cl = json['checklist'] as Map<String, dynamic>? ?? {};
    final exp = json['expected'] as Map<String, dynamic>? ?? {};
    final hint = json['timeline_hint'] as Map<String, dynamic>?;
    return SgpDemoFieldScenario(
      id: json['id'] as String? ?? 'demo',
      title: json['title'] as String? ?? '현장 시연',
      radioText: json['radio_text'] as String? ?? '',
      checklist: SgpDemoChecklist.fromJson(cl),
      expected: SgpDemoExpectedOutcome.fromJson(exp),
      verificationSteps: (json['verification_steps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      timelineHint:
          hint != null ? SgpDemoTimelineHint.fromJson(hint) : null,
    );
  }

  SgpDemoVerificationResult verifyAnalysisSnapshot({
    required String incidentTypeJsonKey,
    required List<String> hierarchyChainTitles,
    required String urgencyLevelName,
  }) {
    final issues = <String>[];

    if (incidentTypeJsonKey != expected.incidentType) {
      issues.add(
        'incident_type: expected ${expected.incidentType}, got $incidentTypeJsonKey',
      );
    }

    if (expected.hasHierarchyChain) {
      if (hierarchyChainTitles.isEmpty) {
        issues.add('hierarchy_chain: empty');
      } else {
        for (final title in expected.hierarchyTitlesContains) {
          if (!hierarchyChainTitles.any((t) => t.contains(title))) {
            issues.add('hierarchy_chain: missing $title');
          }
        }
      }
    }

    if (expected.urgencyLevel != null &&
        urgencyLevelName != expected.urgencyLevel) {
      issues.add(
        'urgency: expected ${expected.urgencyLevel}, got $urgencyLevelName',
      );
    }

    return SgpDemoVerificationResult(
      ok: issues.isEmpty,
      issues: issues,
      scenarioId: id,
    );
  }

  bool matchesArrestSuggestion(String rawText) {
    final detected = detectDemoArrestTypeName(rawText, checklist);
    if (expected.arrestType == null) return true;
    return detected == expected.arrestType;
  }
}

class SgpDemoChecklist {
  const SgpDemoChecklist({
    this.isWeaponUsed = false,
    this.isDomesticViolence = false,
    this.isIntoxicated = false,
    this.isFleeing = false,
    this.isSeizureConstraintReviewed = false,
  });

  final bool isWeaponUsed;
  final bool isDomesticViolence;
  final bool isIntoxicated;
  final bool isFleeing;
  final bool isSeizureConstraintReviewed;

  factory SgpDemoChecklist.fromJson(Map<String, dynamic> json) {
    return SgpDemoChecklist(
      isWeaponUsed: json['isWeaponUsed'] as bool? ?? false,
      isDomesticViolence: json['isDomesticViolence'] as bool? ?? false,
      isIntoxicated: json['isIntoxicated'] as bool? ?? false,
      isFleeing: json['isFleeing'] as bool? ?? false,
      isSeizureConstraintReviewed:
          json['isSeizureConstraintReviewed'] as bool? ?? false,
    );
  }
}

class SgpDemoExpectedOutcome {
  const SgpDemoExpectedOutcome({
    this.incidentType = 'mutual_combat',
    this.localGovCode = '11',
    this.arrestType = 'currentOffender',
    this.hierarchyTitlesContains = const ['형법', '형사소송법'],
    this.ontologyTripleCountMin = 100,
    this.urgencyLevel = 'caution',
    this.hasHierarchyChain = true,
  });

  final String incidentType;
  final String localGovCode;
  final String? arrestType;
  final List<String> hierarchyTitlesContains;
  final int ontologyTripleCountMin;
  final String? urgencyLevel;
  final bool hasHierarchyChain;

  factory SgpDemoExpectedOutcome.fromJson(Map<String, dynamic> json) {
    return SgpDemoExpectedOutcome(
      incidentType: json['incident_type'] as String? ?? 'mutual_combat',
      localGovCode: json['local_gov_code'] as String? ?? '11',
      arrestType: normalizeDemoArrestType(json['arrest_type'] as String?),
      hierarchyTitlesContains:
          (json['hierarchy_titles_contains'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      ontologyTripleCountMin: json['ontology_triple_count_min'] as int? ?? 100,
      urgencyLevel: json['urgency_level'] as String?,
      hasHierarchyChain: json['has_hierarchy_chain'] as bool? ?? true,
    );
  }
}

class SgpDemoTimelineHint {
  const SgpDemoTimelineHint({
    required this.arrestType,
    this.firstDeadlineHours = 24,
    this.labels = const [],
  });

  final String arrestType;
  final int firstDeadlineHours;
  final List<String> labels;

  factory SgpDemoTimelineHint.fromJson(Map<String, dynamic> json) {
    return SgpDemoTimelineHint(
      arrestType:
          normalizeDemoArrestType(json['arrest_type'] as String?) ?? 'currentOffender',
      firstDeadlineHours: json['first_deadline_hours'] as int? ?? 24,
      labels: (json['labels'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SgpDemoVerificationResult {
  const SgpDemoVerificationResult({
    required this.ok,
    required this.issues,
    required this.scenarioId,
  });

  final bool ok;
  final List<String> issues;
  final String scenarioId;
}

String? normalizeDemoArrestType(String? value) {
  if (value == null || value.isEmpty) return null;
  switch (value) {
    case 'current_offender':
    case 'currentOffender':
      return 'currentOffender';
    case 'emergency':
      return 'emergency';
    case 'warrant':
      return 'warrant';
    default:
      return value;
  }
}

String? detectDemoArrestTypeName(String rawText, SgpDemoChecklist checklist) {
  if (RegExp(r'(영장.*체포|체포.*영장|영장체포)').hasMatch(rawText)) {
    return 'warrant';
  }
  if (RegExp(r'(긴급체포|제200조의2|200조의2)').hasMatch(rawText)) {
    return 'emergency';
  }
  if (checklist.isFleeing ||
      RegExp(r'(현행범|도주.*체포|체포.*도주|현장.*체포)').hasMatch(rawText)) {
    return 'currentOffender';
  }
  if (RegExp(r'(체포|검거|연행)').hasMatch(rawText)) {
    return 'currentOffender';
  }
  return null;
}
