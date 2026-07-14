/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Digital Evidence Chain of Custody (evidenceCoC)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052 (Asynchronous Context Flush Mechanism)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 디지털 증거 Chain of Custody — 4단계 강제 시퀀스 + SHA-256 + 맹점 감지.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 디지털 증거 무결성 신호등 (체포/유치용 신호등과 분리).
enum EvidenceCoCTrafficLight {
  green,
  yellow,
  red,
}

/// CoC 4단계.
enum EvidenceCoCStep {
  /// ① 소유자·소지자·보관자 명확화
  possessorClarified,

  /// ② 선별 압수 (범죄사실 연관성)
  selectiveSeizure,

  /// ③ SHA-256 해시 현장 추출·확인서
  hashExtracted,

  /// ④ 참여권 보장 고지
  participationNotified,
}

extension EvidenceCoCStepLabel on EvidenceCoCStep {
  String get label {
    switch (this) {
      case EvidenceCoCStep.possessorClarified:
        return '① 소유자·소지자·보관자 명확화';
      case EvidenceCoCStep.selectiveSeizure:
        return '② 선별 압수(연관성) 준수';
      case EvidenceCoCStep.hashExtracted:
        return '③ 해시값 현장 추출·확인서';
      case EvidenceCoCStep.participationNotified:
        return '④ 피압수자 참여권 고지';
    }
  }

  /// UI 스트립·버튼용 짧은 라벨.
  String get shortLabel {
    switch (this) {
      case EvidenceCoCStep.possessorClarified:
        return '소유자';
      case EvidenceCoCStep.selectiveSeizure:
        return '선별';
      case EvidenceCoCStep.hashExtracted:
        return '해시';
      case EvidenceCoCStep.participationNotified:
        return '참여권';
    }
  }

  int get order => index;
}

/// 단일 CoC 단계 기록.
class EvidenceCoCStepRecord {
  const EvidenceCoCStepRecord({
    required this.step,
    required this.completed,
    this.completedAt,
    this.note,
    this.hashValue,
  });

  final EvidenceCoCStep step;
  final bool completed;
  final DateTime? completedAt;
  final String? note;
  final String? hashValue;

  Map<String, dynamic> toJson() => {
        'step': step.name,
        'completed': completed,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (note != null) 'note': note,
        if (hashValue != null) 'hashValue': hashValue,
      };

  factory EvidenceCoCStepRecord.fromJson(Map<String, dynamic> json) {
    final stepName = json['step'] as String? ?? '';
    final step = EvidenceCoCStep.values.firstWhere(
      (s) => s.name == stepName,
      orElse: () => EvidenceCoCStep.possessorClarified,
    );
    return EvidenceCoCStepRecord(
      step: step,
      completed: json['completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      note: json['note'] as String?,
      hashValue: json['hashValue'] as String?,
    );
  }
}

/// 디지털 맹점(보완수사·위수증 위험 지표).
enum EvidenceBlindSpot {
  participationNotNotified,
  hashMissing,
  nonRelatedSeizureRisk,
  selectiveSeizureViolation,
  fullDumpDetected,
  inventoryDelayed,
}

extension EvidenceBlindSpotGuide on EvidenceBlindSpot {
  String get label {
    switch (this) {
      case EvidenceBlindSpot.participationNotNotified:
        return '피압수자 참여권 미고지';
      case EvidenceBlindSpot.hashMissing:
        return '해시값 미추출';
      case EvidenceBlindSpot.nonRelatedSeizureRisk:
        return '범죄사실 비연관 정보 압수 위험';
      case EvidenceBlindSpot.selectiveSeizureViolation:
        return '선별 압수 원칙 위반 징후';
      case EvidenceBlindSpot.fullDumpDetected:
        return '일괄 복사(Full Dump) 징후';
      case EvidenceBlindSpot.inventoryDelayed:
        return '압수 목록 지연 교부 위험';
    }
  }

  String get actionGuide {
    switch (this) {
      case EvidenceBlindSpot.participationNotNotified:
        return '즉시 참여권·입회권 고지 후 시각·장소·고지자를 기록하십시오. '
            '(대법원: 디지털 증거 압수 시 참여권 보장)';
      case EvidenceBlindSpot.hashMissing:
        return '원본과 동일한 바이트열에서 SHA-256을 현장에서 추출하고 '
            '확인서를 교부하십시오. 해시 미확보 시 위수증 배제 위험이 큽니다.';
      case EvidenceBlindSpot.nonRelatedSeizureRisk:
        return '범죄사실과 무관한 개인정보·메신저·갤러리 일괄 반출을 중단하고 '
            '영장·동의 범위 내 선별만 진행하십시오.';
      case EvidenceBlindSpot.selectiveSeizureViolation:
        return '연관성 없는 폴더/기간을 제외하고 재선별하십시오. '
            '하급심 무죄·파기 요인으로 「선별 압수 위반」이 다수입니다.';
      case EvidenceBlindSpot.fullDumpDetected:
        return '전체 복제(Full Dump) 징후 — 즉시 중단. '
            '대상·기간·파일 유형을 한정한 선별 이미징으로 전환하십시오.';
      case EvidenceBlindSpot.inventoryDelayed:
        return '압수목록을 현장에서 즉시 작성·교부하고, 지연 사유를 문서로 남기십시오.';
    }
  }
}

/// CoC 세션 스냅샷 — UI 신호등·JSON 타임라인.
class EvidenceCoCSession {
  EvidenceCoCSession({
    DateTime? startedAt,
    Map<EvidenceCoCStep, EvidenceCoCStepRecord>? steps,
    this.mediaLabel,
    this.deviceType,
    List<EvidenceBlindSpot>? blindSpots,
  })  : startedAt = startedAt ?? DateTime.now(),
        steps = steps ??
            {
              for (final s in EvidenceCoCStep.values)
                s: EvidenceCoCStepRecord(step: s, completed: false),
            },
        blindSpots = blindSpots ?? [];

  final DateTime startedAt;
  final Map<EvidenceCoCStep, EvidenceCoCStepRecord> steps;
  final String? mediaLabel;
  final String? deviceType;
  final List<EvidenceBlindSpot> blindSpots;

  int get completedCount =>
      steps.values.where((r) => r.completed).length;

  bool get isFullyCompliant =>
      completedCount == EvidenceCoCStep.values.length && blindSpots.isEmpty;

  EvidenceCoCStep? get nextRequiredStep {
    for (final s in EvidenceCoCStep.values) {
      if (!(steps[s]?.completed ?? false)) return s;
    }
    return null;
  }

  EvidenceCoCTrafficLight get trafficLight {
    if (blindSpots.contains(EvidenceBlindSpot.fullDumpDetected) ||
        blindSpots.contains(EvidenceBlindSpot.nonRelatedSeizureRisk) ||
        blindSpots.contains(EvidenceBlindSpot.hashMissing) &&
            completedCount >= 2) {
      return EvidenceCoCTrafficLight.red;
    }
    if (blindSpots.isNotEmpty || completedCount < EvidenceCoCStep.values.length) {
      if (completedCount == 0 && blindSpots.isEmpty) {
        return EvidenceCoCTrafficLight.yellow;
      }
      if (blindSpots.any((b) =>
          b == EvidenceBlindSpot.participationNotNotified ||
          b == EvidenceBlindSpot.selectiveSeizureViolation ||
          b == EvidenceBlindSpot.hashMissing)) {
        return EvidenceCoCTrafficLight.red;
      }
      return EvidenceCoCTrafficLight.yellow;
    }
    return EvidenceCoCTrafficLight.green;
  }

  String get trafficLabel {
    switch (trafficLight) {
      case EvidenceCoCTrafficLight.green:
        return '통과 · 해시·참여·선별 완료';
      case EvidenceCoCTrafficLight.yellow:
        return '주의 · 디지털 절차 진행 중';
      case EvidenceCoCTrafficLight.red:
        return '위험 · 위수증·보완수사 가능성';
    }
  }

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'mediaLabel': mediaLabel,
        'deviceType': deviceType,
        'trafficLight': trafficLight.name,
        'completedCount': completedCount,
        'steps': steps.values.map((r) => r.toJson()).toList(),
        'blindSpots': blindSpots.map((b) => b.name).toList(),
      };
}

/// 온디바이스 CoC 엔진 (폐쇄망 전제).
abstract final class SgpEvidenceCoCEngine {
  /// 현장 추출용 SHA-256 (확인서 기재용).
  static String computeSha256Hex(String payload) {
    final digest = sha256.convert(utf8.encode(payload));
    return digest.toString();
  }

  /// 텍스트 징후 스캔 — Full Dump / 비연관 / 해시·참여 맹점.
  static List<EvidenceBlindSpot> scanBlindSpots(String rawText) {
    final lower = rawText.toLowerCase();
    final spots = <EvidenceBlindSpot>{};

    final fullDumpHints = [
      '통째로',
      '전체복사',
      '전체 복사',
      '전부 복제',
      '풀덤프',
      'full dump',
      '일괄 복제',
      '일괄복사',
      '스마트폰 통째',
      '백업 전체',
    ];
    for (final h in fullDumpHints) {
      if (rawText.contains(h) || lower.contains(h)) {
        spots.add(EvidenceBlindSpot.fullDumpDetected);
        spots.add(EvidenceBlindSpot.selectiveSeizureViolation);
        spots.add(EvidenceBlindSpot.nonRelatedSeizureRisk);
        break;
      }
    }

    final unrelatedHints = ['갤러리 전부', '카톡 전체', '메신저 전부', '무관', '사적 대화'];
    for (final h in unrelatedHints) {
      if (rawText.contains(h)) {
        spots.add(EvidenceBlindSpot.nonRelatedSeizureRisk);
        break;
      }
    }

    final digitalContext = rawText.contains('스마트폰') ||
        rawText.contains('휴대폰') ||
        rawText.contains('블랙박스') ||
        rawText.contains('CCTV') ||
        lower.contains('usb') ||
        rawText.contains('임의제출') ||
        rawText.contains('압수');

    if (digitalContext) {
      if (!rawText.contains('해시') &&
          !lower.contains('sha-256') &&
          !lower.contains('sha256')) {
        spots.add(EvidenceBlindSpot.hashMissing);
      }
      if (!rawText.contains('참여권') &&
          !rawText.contains('입회') &&
          !rawText.contains('입회인')) {
        spots.add(EvidenceBlindSpot.participationNotNotified);
      }
      if (rawText.contains('목록') &&
          (rawText.contains('나중에') || rawText.contains('지연'))) {
        spots.add(EvidenceBlindSpot.inventoryDelayed);
      }
    }

    return spots.toList(growable: false);
  }

  /// 빈 CoC 세션을 만들고 텍스트 맹점을 주입.
  static EvidenceCoCSession createSession({
    required String rawText,
    String? mediaLabel,
    String? deviceType,
  }) {
    final spots = scanBlindSpots(rawText);
    return EvidenceCoCSession(
      mediaLabel: mediaLabel,
      deviceType: deviceType ?? _inferDevice(rawText),
      blindSpots: List.of(spots),
    );
  }

  static String? _inferDevice(String text) {
    if (text.contains('블랙박스')) return '블랙박스';
    if (text.contains('스마트폰') || text.contains('휴대폰')) return '스마트폰';
    if (text.contains('CCTV') || text.contains('폐쇄회로')) return 'CCTV';
    return null;
  }

  /// 단계는 직전 단계가 완료되어야만 활성화.
  static EvidenceCoCSession completeStep(
    EvidenceCoCSession session,
    EvidenceCoCStep step, {
    String? note,
    String? hashSourcePayload,
  }) {
    final next = session.nextRequiredStep;
    if (next != step) {
      throw StateError(
        'CoC 강제 시퀀스 위반: 다음 단계는 ${next?.label ?? "없음"}, '
        '요청=${step.label}',
      );
    }

    String? hashValue;
    if (step == EvidenceCoCStep.hashExtracted) {
      final source = hashSourcePayload ??
          '${session.deviceType ?? "device"}|${session.startedAt.toIso8601String()}';
      hashValue = computeSha256Hex(source);
    }

    final updated = Map<EvidenceCoCStep, EvidenceCoCStepRecord>.from(session.steps);
    updated[step] = EvidenceCoCStepRecord(
      step: step,
      completed: true,
      completedAt: DateTime.now(),
      note: note,
      hashValue: hashValue,
    );

    final spots = List<EvidenceBlindSpot>.from(session.blindSpots);
    if (step == EvidenceCoCStep.hashExtracted) {
      spots.remove(EvidenceBlindSpot.hashMissing);
    }
    if (step == EvidenceCoCStep.participationNotified) {
      spots.remove(EvidenceBlindSpot.participationNotNotified);
    }
    if (step == EvidenceCoCStep.selectiveSeizure) {
      spots.remove(EvidenceBlindSpot.selectiveSeizureViolation);
      spots.remove(EvidenceBlindSpot.fullDumpDetected);
      spots.remove(EvidenceBlindSpot.nonRelatedSeizureRisk);
    }

    return EvidenceCoCSession(
      startedAt: session.startedAt,
      steps: updated,
      mediaLabel: session.mediaLabel,
      deviceType: session.deviceType,
      blindSpots: spots,
    );
  }

  /// 보완수사 예방 배너에 쓸 요약.
  static String supplementaryInvestigationWarning(EvidenceCoCSession session) {
    if (session.blindSpots.isEmpty) {
      return '디지털 증거 맹점 없음 — 보완수사·위수증 위험 지표 미검출';
    }
    final lines = session.blindSpots.map((b) => '· ${b.label}').join('\n');
    return '【보완수사 예방 경고 — 공소불가 위험】\n$lines';
  }
}
