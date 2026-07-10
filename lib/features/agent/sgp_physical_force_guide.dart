/// 체포 초기 단계 — 단계적 물리력 대응 가이드 엔진·UI.
library;

import 'package:flutter/material.dart';

/// 피의자 위해(저항) 수준.
enum PhysicalThreatLevel {
  passiveResistance,
  activeResistance,
  violentAttack,
  lethalAttack,
}

extension PhysicalThreatLevelLabel on PhysicalThreatLevel {
  String get displayName => switch (this) {
        PhysicalThreatLevel.passiveResistance => '소극적 저항',
        PhysicalThreatLevel.activeResistance => '적극적 저항',
        PhysicalThreatLevel.violentAttack => '폭력적 공격',
        PhysicalThreatLevel.lethalAttack => '치명적 공격',
      };

  String get description => switch (this) {
        PhysicalThreatLevel.passiveResistance => '손을 뒤로 숨김·몸을 돌림·말로만 거부',
        PhysicalThreatLevel.activeResistance => '밀침·발로 차기·도주 시도·장애물 던지기',
        PhysicalThreatLevel.violentAttack => '폭행·위협·흉기 휘두름·경찰관 공격',
        PhysicalThreatLevel.lethalAttack => '흉기·총기 등 생명 위협 수단 사용',
      };

  Color get accentColor => switch (this) {
        PhysicalThreatLevel.passiveResistance => Colors.blue.shade700,
        PhysicalThreatLevel.activeResistance => Colors.orange.shade800,
        PhysicalThreatLevel.violentAttack => Colors.red.shade700,
        PhysicalThreatLevel.lethalAttack => Colors.purple.shade900,
      };
}

/// 수준별 허용 대응 매핑 결과.
class PhysicalForceResponse {
  const PhysicalForceResponse({
    required this.level,
    required this.allowedEquipment,
    required this.allowedTechniques,
    required this.proceduralRequirements,
    required this.summary,
    required this.legalBasis,
  });

  final PhysicalThreatLevel level;
  final List<String> allowedEquipment;
  final List<String> allowedTechniques;
  final List<String> proceduralRequirements;
  final String summary;
  final String legalBasis;
}

/// 경찰 물리력 행사 기준 매핑 엔진.
class SgpPhysicalForceGuide {
  const SgpPhysicalForceGuide._();

  static PhysicalForceResponse responseFor(PhysicalThreatLevel level) {
    return switch (level) {
      PhysicalThreatLevel.passiveResistance => const PhysicalForceResponse(
            level: PhysicalThreatLevel.passiveResistance,
            legalBasis: '경찰관 직무집행법 제8조 (최소한의 물리력)',
            summary: '유도·구속 위주 — 과잉 물리력 금지',
            allowedEquipment: ['구속끈(수갑)', '확장봉(휴대만, 타격 자제)'],
            allowedTechniques: ['팔·어깨 유도', '체중 이용 압박(관절 손상 금지)', '2인 협력 구속'],
            proceduralRequirements: [
              '미란다 원칙 고지 유지',
              '체포 경위·저항 정도 문언화 기록',
              '바디캠·현장 녹화 가동 확인',
            ],
          ),
      PhysicalThreatLevel.activeResistance => const PhysicalForceResponse(
            level: PhysicalThreatLevel.activeResistance,
            legalBasis: '경찰관 직무집행법 제8조·제10조 (정당한 물리력)',
            summary: '관절 조작·2인 이상 대응 — 비례원칙 준수',
            allowedEquipment: ['구속끈', '확장봉(관절·사지 타격 제한)', '방패(현장 보유 시)'],
            allowedTechniques: [
              '관절 조작·압박점 통제',
              '2인 이상 동시 제압',
              '지면 안착 후 구속',
            ],
            proceduralRequirements: [
              '신체 접촉 구간 영상 채증',
              '부상 여부 확인·응급조치',
              '저항 중단 시 즉시 물리력 중단',
            ],
          ),
      PhysicalThreatLevel.violentAttack => const PhysicalForceResponse(
            level: PhysicalThreatLevel.violentAttack,
            legalBasis: '경찰관 직무집행법 제10조·형법 제21조 (정당방위)',
            summary: '테이저건·경찰봉 사용 가능 — 미란다 고지 준비',
            allowedEquipment: [
              '경찰봉(타격 부위 제한: 사지·관절)',
              '테이저건(사용 전 경고 고지)',
              'OC스프레이',
              '구속끈',
            ],
            allowedTechniques: [
              '비살상 부위 타격으로 위협 무력화',
              '테이저건 1회 사격 후 재평가',
              '흉기 격퇴·확보 우선',
            ],
            proceduralRequirements: [
              '【필수】 미란다 원칙 고지 준비·낭독',
              '채증 법적 고지 후 녹화 개시',
              '테이저·봉 사용 시각·사유 별도 기록',
              '상급자·112 상황실 즉시 보고',
            ],
          ),
      PhysicalThreatLevel.lethalAttack => const PhysicalForceResponse(
            level: PhysicalThreatLevel.lethalAttack,
            legalBasis: '형법 제21조·제22조 (정당방위·긴급피난)',
            summary: '생명 보호 최우선 — 총기 사용은 최후 수단',
            allowedEquipment: [
              '경찰봉·테이저건',
              '총기(생명 위협·대체 수단 불가 시만)',
              '방탄장비(현장 투입 시)',
            ],
            allowedTechniques: [
              '흉기·총기 격퇴·무장 해제',
              '거리 확보·엄폐 후 대응',
              '동시 다발 타격 자제 — 생명 최소침해',
            ],
            proceduralRequirements: [
              '【긴급】 112·상급자 실시간 보고',
              '총기 사용 시 사후 서면 보고 준비',
              '목격자·바디캠 다채널 채증',
              '피의자·경찰관 부상 응급처치',
            ],
          ),
    };
  }

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
  });

  final PhysicalThreatLevel? selectedLevel;
  final ValueChanged<PhysicalThreatLevel> onLevelChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final response =
        selectedLevel != null ? SgpPhysicalForceGuide.responseFor(selectedLevel!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '피의자 위해 수준 평가',
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
        if (response != null) ...[
          const SizedBox(height: 8),
          _ResponsePanel(response: response, compact: compact),
        ],
      ],
    );
  }
}

class _ResponsePanel extends StatelessWidget {
  const _ResponsePanel({required this.response, required this.compact});

  final PhysicalForceResponse response;
  final bool compact;

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
            response.legalBasis,
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
