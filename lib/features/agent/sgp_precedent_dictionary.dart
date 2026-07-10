/// 경량 판례 JSON 딕셔너리 — 온디바이스 참조.
library;

import 'dart:convert';

/// 판례 참조 레코드 (JSON ↔ Dart).
class PrecedentRef {
  const PrecedentRef({
    required this.id,
    required this.holding,
    required this.factorBoost,
    required this.factorPenalty,
    this.triggers = const [],
  });

  final String id;
  final String holding;
  final double factorBoost;
  final double factorPenalty;
  final List<String> triggers;

  factory PrecedentRef.fromJson(Map<String, dynamic> json) {
    return PrecedentRef(
      id: json['id'] as String,
      holding: json['holding'] as String,
      factorBoost: (json['factorBoost'] as num).toDouble(),
      factorPenalty: (json['factorPenalty'] as num).toDouble(),
      triggers: (json['triggers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'holding': holding,
        'factorBoost': factorBoost,
        'factorPenalty': factorPenalty,
        'triggers': triggers,
      };
}

/// 에셋 미로드 시 폴백 (assets/data/precedent_dictionary.json 동일).
const String kEmbeddedPrecedentJson = '''
[
  {"id":"SC_self_defense","holding":"정당방위: 침해의 현재성·부당성·방어의사·상당성 동시 검토 (대법원)","factorBoost":8,"factorPenalty":12,"triggers":["막으려","방어","정당"]},
  {"id":"SC_mutual_combat","holding":"쌍방 폭행: 선제 공격·흉기 주도권·피해 규모로 실질 가해자 구분 (대법원)","factorBoost":5,"factorPenalty":18,"triggers":["쌍방","서로"]},
  {"id":"SC_dv_victim","holding":"가정폭력: 반복·관계성·신고 의사로 피해자 보호 우선 (대법원)","factorBoost":10,"factorPenalty":6,"triggers":["신고","112"]},
  {"id":"SC_intox_voluntary","holding":"자의적 음주: 형법 제10조3항 — 심신미약 감경 주장 제한 (대법원)","factorBoost":6,"factorPenalty":14,"triggers":["술","취해"]},
  {"id":"SC_illegal_evidence","holding":"위수증: 영장주의·적법절차 위반 시 증거능력 배제 위험 (대법원)","factorBoost":0,"factorPenalty":25,"triggers":["압수","체포"]},
  {"id":"SC_preemptive_attack","holding":"선제 공격: 먼저 시비·도발·밀친 자가 실질 공격 유발자 (대법원)","factorBoost":12,"factorPenalty":8,"triggers":["선제","먼저","시비"]},
  {"id":"SC_weapon_dominance","holding":"흉기 주도권: 소지·꺼냄·휘두름 주도권이 공격자 판단의 결정적 요소 (대법원)","factorBoost":14,"factorPenalty":10,"triggers":["들고","휘두르","꺼내"]},
  {"id":"SC_warrantless_seizure","holding":"형소법 제216조: 영장 없는 압수·수색은 예외 요건 엄격 해석 (대법원)","factorBoost":0,"factorPenalty":20,"triggers":["압수","휴대폰"]}
]
''';

List<PrecedentRef>? _cachedPrecedents;

/// JSON 문자열 → 판례 목록.
List<PrecedentRef> parsePrecedentDictionary(String jsonSource) {
  final list = jsonDecode(jsonSource) as List<dynamic>;
  return list
      .map((e) => PrecedentRef.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 온디바이스 판례 딕셔너리 (싱글턴 캐시).
List<PrecedentRef> getPrecedentDictionary() {
  return _cachedPrecedents ??= parsePrecedentDictionary(kEmbeddedPrecedentJson);
}

/// Flutter 에셋 로드 후 캐시 갱신 (앱 기동 시 1회 호출).
void setPrecedentDictionaryFromJson(String jsonSource) {
  _cachedPrecedents = parsePrecedentDictionary(jsonSource);
}

/// 텍스트·체크리스트에 매칭되는 판례 ID.
List<PrecedentRef> matchPrecedents({
  required String text,
  required bool isDomesticViolence,
  required bool isIntoxicated,
  required bool isWeaponUsed,
}) {
  final dict = getPrecedentDictionary();
  final matched = <PrecedentRef>[];

  for (final p in dict) {
    if (p.triggers.isEmpty) continue;
    final hit = p.triggers.any((t) => text.contains(t));
    if (hit) matched.add(p);
  }

  if (isDomesticViolence) {
    for (final p in dict) {
      if (p.id == 'SC_dv_victim' && !matched.contains(p)) matched.add(p);
    }
  }
  if (isIntoxicated) {
    for (final p in dict) {
      if (p.id == 'SC_intox_voluntary' && !matched.contains(p)) matched.add(p);
    }
  }
  if (isWeaponUsed) {
    for (final p in dict) {
      if (p.id == 'SC_weapon_dominance' && !matched.contains(p)) matched.add(p);
    }
  }

  return matched;
}
