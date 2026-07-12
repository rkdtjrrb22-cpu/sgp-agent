/// S9 — 종합민원·반려견 시비 [지자체 이관] vs [형사 수사] 분기 추론.
library;

import 'sgp_civil_complaint_data.dart';

/// 집행·관할 분기.
enum CivilComplaintEnforcementBranch {
  /// 지자체 환경과·동물보호과·주민센터 행정 이관.
  localGovTransfer,

  /// 경찰 형사과 수사 착수.
  criminalInvestigation,
}

/// 분기 추론 결과.
class CivilComplaintBranchResult {
  const CivilComplaintBranchResult({
    required this.branch,
    required this.rationale,
    required this.legalNodeIds,
    required this.confidence,
  });

  final CivilComplaintEnforcementBranch branch;
  final String rationale;
  final List<String> legalNodeIds;
  final double confidence;

  bool get isCriminal => branch == CivilComplaintEnforcementBranch.criminalInvestigation;
}

abstract final class SgpCivilComplaintBranchRouter {
  static final _injuryKw = RegExp(r'(물림|물어|교상|상해|출혈|봉합|병원|치료|피해)');
  static final _violenceKw = RegExp(r'(폭행|구타|협박|흉기|살인|위협|싸움|맞았)');
  static final _adminPetKw = RegExp(r'(목줄|입마개|줄\s*안|미착용|방치|배변|짖|소음\s*만)');
  static final _noiseOnlyKw = RegExp(r'(층간|소음|쿵쾅|시끄|음악)');

  /// 유형 + 현장 텍스트로 이관 vs 형사 분기.
  static CivilComplaintBranchResult infer({
    required CivilComplaintType type,
    required String rawText,
  }) {
    final text = rawText.trim();
    final nodes = <String>[];
    var branch = _defaultBranch(type);
    var rationale = type.adminGuideLv8;
    var confidence = 0.55;

    switch (type.id) {
      case 'CC-TYPE-PET-BITE':
        branch = CivilComplaintEnforcementBranch.criminalInvestigation;
        nodes.addAll([
          'KR-RULE-ANIMAL-ART16',
          'KR-CRIM-266-NEGLIGENCE',
          'KR-CRIM-257-BODILY',
          'ORG-POLICE-CRIMINAL-INVEST',
        ]);
        rationale =
            '개 물림·교상 등 신체 피해 — 형사과 수사 착수. '
            '동물보호법 제16조 위반·과실치상(형법 제266조) 병행 검토.';
        confidence = _injuryKw.hasMatch(text) ? 0.92 : 0.75;
        break;

      case 'CC-TYPE-PET-LEASH':
        if (_injuryKw.hasMatch(text) || _violenceKw.hasMatch(text)) {
          branch = CivilComplaintEnforcementBranch.criminalInvestigation;
          nodes.addAll([
            'KR-RULE-ANIMAL-ART16',
            'KR-CRIM-266-NEGLIGENCE',
            'ORG-POLICE-CRIMINAL-INVEST',
          ]);
          rationale = '목줄·관리 위반 + 신체·폭력 정황 — 형사과 우선 수사.';
          confidence = 0.88;
        } else {
          branch = CivilComplaintEnforcementBranch.localGovTransfer;
          nodes.addAll([
            'KR-RULE-ANIMAL-ART16',
            'AGENCY-LOCAL-ENV-ANIMAL',
          ]);
          rationale =
              '목줄·입마개 미착용 등 행정 위반 — 지자체 환경과·동물보호과 이관. '
              '동물보호법 제16조 행정지도.';
          confidence = _adminPetKw.hasMatch(text) ? 0.9 : 0.7;
        }
        break;

      case 'CC-TYPE-NOISE':
      case 'CC-TYPE-ILLEGAL-PARKING':
      case 'CC-TYPE-STREET-VENDOR':
      case 'CC-TYPE-CIVIL-DISPUTE':
        if (_violenceKw.hasMatch(text)) {
          branch = CivilComplaintEnforcementBranch.criminalInvestigation;
          nodes.add('ORG-POLICE-CRIMINAL-INVEST');
          rationale = '행정 민원이나 폭력·상해 정황 동반 — 형사과 수사 병행.';
          confidence = 0.85;
        } else {
          branch = CivilComplaintEnforcementBranch.localGovTransfer;
          nodes.add('AGENCY-LOCAL-GOV');
          rationale = type.adminGuideLv8.isNotEmpty
              ? type.adminGuideLv8
              : '지자체·주민센터 행정 소관 — 경찰 이관 안내.';
          confidence = _noiseOnlyKw.hasMatch(text) ? 0.88 : 0.72;
        }
        break;

      case 'CC-TYPE-COMPLAINT-INTAKE':
      case 'CC-TYPE-CYBER-FRAUD':
        branch = CivilComplaintEnforcementBranch.criminalInvestigation;
        nodes.add('ORG-POLICE-CRIMINAL-INVEST');
        rationale = '고소·고발·형사 피해 신고 — 수사과 접수·형사과 착수.';
        confidence = 0.8;
        break;

      default:
        nodes.addAll(_nodesForDefault(type, branch));
    }

    return CivilComplaintBranchResult(
      branch: branch,
      rationale: rationale,
      legalNodeIds: nodes,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  static CivilComplaintEnforcementBranch _defaultBranch(CivilComplaintType type) {
    if (type.policeDispatchWarning) {
      return CivilComplaintEnforcementBranch.localGovTransfer;
    }
    if (type.category.contains('수사') || type.category.contains('형사')) {
      return CivilComplaintEnforcementBranch.criminalInvestigation;
    }
    return CivilComplaintEnforcementBranch.localGovTransfer;
  }

  static List<String> _nodesForDefault(
    CivilComplaintType type,
    CivilComplaintEnforcementBranch branch,
  ) {
    if (branch == CivilComplaintEnforcementBranch.criminalInvestigation) {
      return const ['ORG-POLICE-CRIMINAL-INVEST'];
    }
    return const ['AGENCY-LOCAL-GOV'];
  }

  static String branchLabel(CivilComplaintEnforcementBranch branch) =>
      switch (branch) {
        CivilComplaintEnforcementBranch.localGovTransfer =>
          '지자체 환경과·동물보호과 이관',
        CivilComplaintEnforcementBranch.criminalInvestigation =>
          '형사과 수사 착수',
      };
}

/// 라우팅 결과 + 현장 텍스트 → 집행 분기.
extension CivilComplaintRouteEnforcement on CivilComplaintRouteResult {
  CivilComplaintBranchResult inferEnforcement(String rawText) =>
      SgpCivilComplaintBranchRouter.infer(type: type, rawText: rawText);
}
