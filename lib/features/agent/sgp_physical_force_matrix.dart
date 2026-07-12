/// 5단계 물리력 응답 매트릭스 (Flutter 비의존).
library;

import 'sgp_constitutional_force_engine.dart';
import 'sgp_physical_threat_level.dart';

class PhysicalForceResponse {
  const PhysicalForceResponse({
    required this.level,
    required this.allowedEquipment,
    required this.allowedTechniques,
    required this.proceduralRequirements,
    required this.summary,
    required this.legalBasis,
    required this.recommendedForceTier,
  });

  final PhysicalThreatLevel level;
  final List<String> allowedEquipment;
  final List<String> allowedTechniques;
  final List<String> proceduralRequirements;
  final String summary;
  final String legalBasis;
  final PoliceForceTier recommendedForceTier;
}

abstract final class SgpPhysicalForceMatrix {
  static PhysicalForceResponse responseFor(PhysicalThreatLevel level) {
    final tier = level.resistanceStage.defaultForceTier;
    return switch (level) {
      PhysicalThreatLevel.compliance => PhysicalForceResponse(
            level: level,
            recommendedForceTier: tier,
            legalBasis: '헌법 제37조 · 경찰관 직무집행법 제8조 (최소침해성)',
            summary: '언어적 통제(지시·통고) — 물리력 개시 금지',
            allowedEquipment: const [],
            allowedTechniques: const ['구두 지시·신분 확인 요청', '상황 설명·협조 요청'],
            proceduralRequirements: const [
              '신분·체포 사유 구두 통지',
              '바디캠 가동 확인',
            ],
          ),
      PhysicalThreatLevel.passiveResistance => PhysicalForceResponse(
            level: level,
            recommendedForceTier: tier,
            legalBasis: '경찰관 직무집행법 제8조 (최소한의 물리력)',
            summary: '접촉성 통제 — 유도·구속, 과잉 물리력 금지',
            allowedEquipment: const ['구속끈(수갑)', '확장봉(휴대만, 타격 자제)'],
            allowedTechniques: const [
              '팔·어깨 유도',
              '체중 이용 압박(관절 손상 금지)',
              '2인 협력 구속',
            ],
            proceduralRequirements: const [
              '미란다 원칙 고지 유지',
              '체포 경위·저항 정도 문언화 기록',
              '바디캠·현장 녹화 가동 확인',
            ],
          ),
      PhysicalThreatLevel.activeResistance => PhysicalForceResponse(
            level: level,
            recommendedForceTier: tier,
            legalBasis: '경찰관 직무집행법 제8조·제10조 (정당한 물리력)',
            summary: '저위험 물리력 — 관절 조작·분사기, 비례원칙 준수',
            allowedEquipment: const ['구속끈', 'OC스프레이', '확장봉(관절·사지 타격 제한)'],
            allowedTechniques: const [
              '관절 조작·압박점 통제',
              '2인 이상 동시 제압',
              '지면 안착 후 구속',
            ],
            proceduralRequirements: const [
              '신체 접촉 구간 영상 채증',
              '부상 여부 확인·응급조치',
              '저항 중단 시 즉시 물리력 중단',
            ],
          ),
      PhysicalThreatLevel.violentAttack => PhysicalForceResponse(
            level: level,
            recommendedForceTier: tier,
            legalBasis: '경찰관 직무집행법 제10조·형법 제21조 (정당방위)',
            summary: '중위험 물리력 — 테이저·경찰봉, 미란다 고지 준비',
            allowedEquipment: const [
              '경찰봉(타격 부위 제한: 사지·관절)',
              '테이저건(사용 전 경고 고지)',
              'OC스프레이',
              '구속끈',
            ],
            allowedTechniques: const [
              '비살상 부위 타격으로 위협 무력화',
              '테이저건 1회 사격 후 재평가',
              '흉기 격퇴·확보 우선',
            ],
            proceduralRequirements: const [
              '【필수】 미란다 원칙 고지 준비·낭독',
              '채증 법적 고지 후 녹화 개시',
              '테이저·봉 사용 시각·사유 별도 기록',
              '상급자·112 상황실 즉시 보고',
            ],
          ),
      PhysicalThreatLevel.lethalAttack => PhysicalForceResponse(
            level: level,
            recommendedForceTier: tier,
            legalBasis: '헌법 제37조 제2항 · 형법 제21조·제22조 (정당방위·긴급피난)',
            summary: '고위험 물리력 — 총기는 최후 수단',
            allowedEquipment: const [
              '경찰봉·테이저건',
              '총기(생명 위협·대체 수단 불가 시만)',
              '방탄장비(현장 투입 시)',
            ],
            allowedTechniques: const [
              '흉기·총기 격퇴·무장 해제',
              '거리 확보·엄폐 후 대응',
              '동시 다발 타격 자제 — 생명 최소침해',
            ],
            proceduralRequirements: const [
              '【긴급】 112·상급자 실시간 보고',
              '총기 사용 시 사후 서면 보고 준비',
              '목격자·바디캠 다채널 채증',
              '피의자·경찰관 부상 응급처치',
            ],
          ),
    };
  }
}
