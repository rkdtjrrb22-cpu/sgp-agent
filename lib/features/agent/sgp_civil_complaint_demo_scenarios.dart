/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Civil Complaint Demo Scenarios (8-Pack)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 종합 민원 시연 — 실전 8대 시나리오.
library;

class CivilComplaintDemoScenario {
  const CivilComplaintDemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.radioText,
    this.expectedTypeId,
    this.civilNonInterventionHint = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String radioText;
  final String? expectedTypeId;
  final bool civilNonInterventionHint;
}

abstract final class SgpCivilComplaintDemoScenarios {
  static const List<CivilComplaintDemoScenario> all = [
    CivilComplaintDemoScenario(
      id: 'license',
      title: '1. 면허증 분실',
      subtitle: '도로교통 행정 · 재발급 안내',
      radioText: '면허증 잃어버렸는데 어디서 만들어요?',
      expectedTypeId: 'CC-TYPE-LICENSE-REISSUE',
    ),
    CivilComplaintDemoScenario(
      id: 'noise',
      title: '2. 층간소음',
      subtitle: '지자체·소음조정 이관',
      radioText: '윗집 층간소음이 너무 심해서 경찰 좀 불러주세요',
      expectedTypeId: 'CC-TYPE-NOISE',
    ),
    CivilComplaintDemoScenario(
      id: 'cyber',
      title: '3. 사이버 사기',
      subtitle: '보이스피싱 · 형사 접수',
      radioText: '보이스피싱으로 돈 이체당했어요 신고하려고요',
      expectedTypeId: 'CC-TYPE-CYBER-FRAUD',
    ),
    CivilComplaintDemoScenario(
      id: 'missing',
      title: '4. 실종 신고',
      subtitle: '골든타임 프로필',
      radioText: '가출한 아들 찾으러 왔습니다 실종 신고',
      expectedTypeId: 'CC-TYPE-MISSING-PERSON',
    ),
    CivilComplaintDemoScenario(
      id: 'lost',
      title: '5. 유실물',
      subtitle: 'Lost112 · 생활안전',
      radioText: '지갑 분실했는데 Lost112 어디서 찾나요',
      expectedTypeId: 'CC-TYPE-LOST-FOUND',
    ),
    CivilComplaintDemoScenario(
      id: 'private_parking',
      title: '6. 사유지 무단주차 분쟁',
      subtitle: '도로교통법 vs 재물손괴',
      radioText:
          '우리집 사유지에 무단주차해서 막아놨더니 주인이 와서 경찰 불러 달라네요. '
          '도로교통법으로 딱지 뗄 건지, 재물손괴인지 헷갈립니다',
      expectedTypeId: 'CC-TYPE-PRIVATE-PARKING',
    ),
    CivilComplaintDemoScenario(
      id: 'lease_debt',
      title: '7. 임대차·채무 관계',
      subtitle: '단순 민사 · 불개입',
      radioText: '세입자가 보증금을 안 돌려주고 돈을 안 갚는다며 경찰이 받아내 달래요',
      expectedTypeId: 'CC-TYPE-CIVIL-DISPUTE',
      civilNonInterventionHint: true,
    ),
    CivilComplaintDemoScenario(
      id: 'dating_stalking',
      title: '8. 데이트폭력·스토킹 잠정조치',
      subtitle: '스토킹처벌법 · 잠정조치',
      radioText:
          '헤어진 전 애인이 미행하고 연락 강요해서 스토킹 신고하고 '
          '잠정조치로 접근금지 신청하려고요 데이트폭력도 있었던 사건입니다',
      expectedTypeId: 'CC-TYPE-DATING-STALKING',
    ),
  ];
}
