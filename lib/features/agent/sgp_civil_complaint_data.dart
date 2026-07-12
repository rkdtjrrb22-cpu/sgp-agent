/// S7-D — 경찰청 통계 기반 종합 민원해결 온톨로지 데이터 모델 (Flutter 비의존).
library;

/// 민원 유형별 해결 경로·행정지도 LV8 정의.
class CivilComplaintType {
  const CivilComplaintType({
    required this.id,
    required this.parentId,
    required this.category,
    required this.title,
    required this.keywords,
    this.intentPatterns = const [],
    this.jurisdictions = const [],
    this.requiredDocuments = const [],
    this.adminGuideLv8 = '',
    this.policeDispatchWarning = false,
    this.switchToGoldenTimeProfile = false,
    this.mapUrl,
    this.formUrl,
    this.phone,
    this.medTransferBranch,
    this.freezesTimeline = false,
    this.requiresGuard = false,
    this.custodyGuideLv7 = '',
  });

  final String id;
  final String parentId;
  final String category;
  final String title;
  final List<String> keywords;
  final List<String> intentPatterns;
  final List<CivilComplaintJurisdiction> jurisdictions;
  final List<CivilComplaintDocument> requiredDocuments;
  final String adminGuideLv8;
  final bool policeDispatchWarning;
  final bool switchToGoldenTimeProfile;
  final String? mapUrl;
  final String? formUrl;
  final String? phone;
  final String? medTransferBranch;
  final bool freezesTimeline;
  final bool requiresGuard;
  final String custodyGuideLv7;

  bool get isMedicalTransferGuide =>
      medTransferBranch != null && medTransferBranch!.isNotEmpty;

  factory CivilComplaintType.fromJson(Map<String, dynamic> json) {
    return CivilComplaintType(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      category: json['category'] as String? ?? '',
      title: json['title'] as String,
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      intentPatterns: (json['intent_patterns'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      jurisdictions: (json['jurisdictions'] as List<dynamic>? ?? [])
          .map((e) => CivilComplaintJurisdiction.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiredDocuments: (json['required_documents'] as List<dynamic>? ?? [])
          .map((e) => CivilComplaintDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      adminGuideLv8: json['admin_guide_lv8'] as String? ?? '',
      policeDispatchWarning: json['police_dispatch_warning'] as bool? ?? false,
      switchToGoldenTimeProfile:
          json['switch_to_golden_time_profile'] as bool? ?? false,
      mapUrl: json['map_url'] as String?,
      formUrl: json['form_url'] as String?,
      phone: json['phone'] as String?,
      medTransferBranch: json['med_transfer_branch'] as String?,
      freezesTimeline: json['freezes_timeline'] as bool? ?? false,
      requiresGuard: json['requires_guard'] as bool? ?? false,
      custodyGuideLv7: json['custody_guide_lv7'] as String? ?? '',
    );
  }
}

class CivilComplaintJurisdiction {
  const CivilComplaintJurisdiction({
    required this.agencyId,
    required this.agencyName,
    this.scope,
    this.phone,
    this.transfer = false,
  });

  final String agencyId;
  final String agencyName;
  final String? scope;
  final String? phone;
  final bool transfer;

  factory CivilComplaintJurisdiction.fromJson(Map<String, dynamic> json) {
    return CivilComplaintJurisdiction(
      agencyId: json['agency_id'] as String,
      agencyName: json['agency_name'] as String,
      scope: json['scope'] as String?,
      phone: json['phone'] as String?,
      transfer: json['transfer'] as bool? ?? false,
    );
  }
}

class CivilComplaintDocument {
  const CivilComplaintDocument({
    required this.docType,
    required this.label,
    this.required = true,
  });

  final String docType;
  final String label;
  final bool required;

  factory CivilComplaintDocument.fromJson(Map<String, dynamic> json) {
    return CivilComplaintDocument(
      docType: json['doc_type'] as String,
      label: json['label'] as String,
      required: json['required'] as bool? ?? true,
    );
  }
}

class CivilComplaintNodePack {
  const CivilComplaintNodePack({
    required this.title,
    required this.rootId,
    required this.types,
  });

  final String title;
  final String rootId;
  final List<CivilComplaintType> types;

  factory CivilComplaintNodePack.fromJson(Map<String, dynamic> json) {
    final list = json['complaint_types'] as List<dynamic>? ?? [];
    return CivilComplaintNodePack(
      title: json['title'] as String? ?? '종합 민원해결',
      rootId: json['root_id'] as String? ?? 'CC-ROOT-POLICE-COMPLAINT',
      types: list
          .map((e) => CivilComplaintType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 자연어 라우팅 결과.
class CivilComplaintRouteResult {
  const CivilComplaintRouteResult({
    required this.type,
    required this.matchedKeywords,
    required this.confidence,
    this.ontologyTripleCount = 0,
  });

  final CivilComplaintType type;
  final List<String> matchedKeywords;
  final double confidence;
  final int ontologyTripleCount;

  bool get isHighConfidence => confidence >= 0.45;
}
