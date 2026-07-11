/// Sprint S5 — POST /v1/quantum-legal/resolve API DTO (서버·클라이언트 공용).
library;

import 'sgp_actor_session.dart';
import 'sgp_agent_core.dart';
import 'sgp_quantum_legal_engine.dart';

export 'sgp_actor_session.dart';

class QuantumLegalSituation {
  const QuantumLegalSituation({
    this.domain = 'criminal',
    required this.rawText,
    this.incidentType,
    this.checklist = const LawCheckList(),
  });

  final String domain;
  final String rawText;
  final String? incidentType;
  final LawCheckList checklist;

  factory QuantumLegalSituation.fromJson(Map<String, dynamic> json) {
    final cl = json['checklist'] as Map<String, dynamic>?;
    return QuantumLegalSituation(
      domain: json['domain'] as String? ?? 'criminal',
      rawText: json['raw_text'] as String? ?? '',
      incidentType: json['incident_type'] as String?,
      checklist: cl != null ? LawCheckList.fromJson(cl) : const LawCheckList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'raw_text': rawText,
        if (incidentType != null) 'incident_type': incidentType,
        'checklist': checklist.toJson(),
      };
}

class QuantumLegalResolveOptions {
  const QuantumLegalResolveOptions({
    this.includeManuals = true,
    this.strictHierarchy = true,
  });

  final bool includeManuals;
  final bool strictHierarchy;

  factory QuantumLegalResolveOptions.fromJson(Map<String, dynamic> json) {
    return QuantumLegalResolveOptions(
      includeManuals: json['include_manuals'] as bool? ?? true,
      strictHierarchy: json['strict_hierarchy'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'include_manuals': includeManuals,
        'strict_hierarchy': strictHierarchy,
      };
}

class QuantumLegalResolveRequest {
  const QuantumLegalResolveRequest({
    required this.actor,
    required this.situation,
    this.options = const QuantumLegalResolveOptions(),
  });

  final QuantumLegalActorContext actor;
  final QuantumLegalSituation situation;
  final QuantumLegalResolveOptions options;

  factory QuantumLegalResolveRequest.fromJson(Map<String, dynamic> json) {
    return QuantumLegalResolveRequest(
      actor: QuantumLegalActorContext.fromJson(
        json['actor'] as Map<String, dynamic>? ?? json['actor_a'] as Map<String, dynamic>? ?? {},
      ),
      situation: QuantumLegalSituation.fromJson(
        json['situation'] as Map<String, dynamic>? ?? {},
      ),
      options: QuantumLegalResolveOptions.fromJson(
        json['options'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'actor': actor.toJson(),
        'situation': situation.toJson(),
        'options': options.toJson(),
      };
}

class QuantumLegalResolveResponse {
  const QuantumLegalResolveResponse({
    required this.comparison,
    this.resolvedBy = 'on_device',
    this.schemaVersion = '1.0',
  });

  final SgpQuantumLegalComparison comparison;
  final String resolvedBy;
  final String schemaVersion;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'resolved_by': resolvedBy,
        ...comparison.toJson(),
        if (comparison.hierarchy != null)
          'hierarchy_chain': comparison.hierarchy!.chain
              .map(
                (n) => {
                  'level': n.level.value,
                  'node_id': n.id,
                  'title': n.title,
                },
              )
              .toList(),
        if (comparison.hierarchy != null)
          'conflicts': comparison.hierarchy!.conflicts
              .map(
                (c) => {
                  'lower_node_id': c.lowerNodeId,
                  'upper_node_id': c.upperNodeId,
                  'message': c.message,
                },
              )
              .toList(),
      };

  factory QuantumLegalResolveResponse.fromComparison(
    SgpQuantumLegalComparison comparison, {
    String resolvedBy = 'on_device',
  }) {
    return QuantumLegalResolveResponse(
      comparison: comparison,
      resolvedBy: resolvedBy,
    );
  }

  factory QuantumLegalResolveResponse.fromJson(Map<String, dynamic> json) {
    return QuantumLegalResolveResponse(
      comparison: SgpQuantumLegalComparison.fromJson(json),
      resolvedBy: json['resolved_by'] as String? ?? 'remote',
      schemaVersion: json['schema_version'] as String? ?? '1.0',
    );
  }
}

SgpQuantumLegalComparison executeQuantumLegalResolve(
  QuantumLegalResolveRequest request, {
  String? orgIdOverride,
}) {
  return SgpQuantumLegalEngine.analyze(
    rawText: request.situation.rawText,
    checklist: request.situation.checklist,
    orgId: request.options.includeManuals ? (orgIdOverride ?? request.actor.orgId) : null,
  );
}

bool authorizeResolveRequest({
  required QuantumLegalResolveRequest request,
  required String? bearerToken,
}) {
  return authorizeQuantumLegalRequest(
    actor: request.actor,
    bearerToken: bearerToken,
  );
}
