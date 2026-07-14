/// 형사소송법 신체구속 실시간 사법 타임테이블 — 모델·계산·UI.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sgp_agent_core.dart';
import 'sgp_physical_force_guide.dart';
import 'sgp_constitutional_force_engine.dart';
import 'sgp_app_theme.dart';

// ---------------------------------------------------------------------------
// 체포 방식 · 노드 상태
// ---------------------------------------------------------------------------

/// 체포 방식 (형소법 기준).
enum ArrestType {
  /// 현행범 체포 (제211조 등).
  currentOffender,

  /// 긴급체포 (제200조의2).
  emergency,

  /// 영장에 의한 체포.
  warrant,
}

extension ArrestTypeLabel on ArrestType {
  String get displayName => switch (this) {
        ArrestType.currentOffender => '현행범 체포',
        ArrestType.emergency => '긴급체포',
        ArrestType.warrant => '영장체포',
      };

  String get legalBasis => switch (this) {
        ArrestType.currentOffender => '형소법 제211조 (현행범인 체포)',
        ArrestType.emergency => '형소법 제200조의2 (긴급체포)',
        ArrestType.warrant => '형소법 제215조 (영장에 의한 체포)',
      };
}

/// 타임라인 노드 진행 상태.
enum TimelineNodeStatus {
  completed,
  inProgress,
  pending,
  critical,
  expired,
}

extension TimelineNodeStatusColors on TimelineNodeStatus {
  Color get accent {
    switch (this) {
      case TimelineNodeStatus.completed:
        return Colors.green.shade700;
      case TimelineNodeStatus.inProgress:
        return Colors.orange.shade800;
      case TimelineNodeStatus.pending:
        return Colors.blue.shade700;
      case TimelineNodeStatus.critical:
        return Colors.red.shade700;
      case TimelineNodeStatus.expired:
        return Colors.grey.shade800;
    }
  }

  String get signalLabel => switch (this) {
        TimelineNodeStatus.completed => '완료',
        TimelineNodeStatus.inProgress => '진행',
        TimelineNodeStatus.pending => '대기',
        TimelineNodeStatus.critical => '위험',
        TimelineNodeStatus.expired => '초과',
      };
}

/// T-0 직후 즉시 이행 노드 ID.
const Set<String> kImmediatePhaseNodeIds = {
  'victim_separation',
  'physical_force',
  'evidence_notice',
  'custody_handover_prep',
  'legal_report',
};

/// 초동조치 보고서 생성 노드 ID.
const String kLegalReportNodeId = 'legal_report';

/// 체크리스트 항목.
class SgpTimelineCheckItem {
  const SgpTimelineCheckItem({
    required this.id,
    required this.label,
    this.checked = false,
  });

  final String id;
  final String label;
  final bool checked;

  SgpTimelineCheckItem copyWith({bool? checked}) {
    return SgpTimelineCheckItem(
      id: id,
      label: label,
      checked: checked ?? this.checked,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'checked': checked};

  factory SgpTimelineCheckItem.fromJson(Map<String, dynamic> json) {
    return SgpTimelineCheckItem(
      id: json['id'] as String,
      label: json['label'] as String,
      checked: json['checked'] as bool? ?? false,
    );
  }
}

/// 절차 단계 노드.
class SgpTimeTableNode {
  const SgpTimeTableNode({
    required this.id,
    required this.title,
    required this.legalReference,
    required this.deadline,
    required this.offsetLabel,
    required this.actionGuide,
    required this.checkItems,
    this.status = TimelineNodeStatus.pending,
    this.isAbsoluteDeadline = false,
  });

  final String id;
  final String title;
  final String legalReference;
  final DateTime deadline;
  final String offsetLabel;
  final String actionGuide;
  final List<SgpTimelineCheckItem> checkItems;
  final TimelineNodeStatus status;

  /// 경찰 구속 송치 등 절대 시한 강조.
  final bool isAbsoluteDeadline;

  Duration remainingFrom(DateTime now) => deadline.difference(now);

  SgpTimeTableNode copyWith({
    TimelineNodeStatus? status,
    List<SgpTimelineCheckItem>? checkItems,
  }) {
    return SgpTimeTableNode(
      id: id,
      title: title,
      legalReference: legalReference,
      deadline: deadline,
      offsetLabel: offsetLabel,
      actionGuide: actionGuide,
      checkItems: checkItems ?? this.checkItems,
      status: status ?? this.status,
      isAbsoluteDeadline: isAbsoluteDeadline,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'legalReference': legalReference,
        'deadline': deadline.toIso8601String(),
        'offsetLabel': offsetLabel,
        'actionGuide': actionGuide,
        'checkItems': checkItems.map((c) => c.toJson()).toList(),
        'status': status.name,
        'isAbsoluteDeadline': isAbsoluteDeadline,
      };
}

/// 활성 타임테이블 세션.
class SgpProcedureTimeline {
  const SgpProcedureTimeline({
    required this.arrestType,
    required this.t0,
    required this.nodes,
    this.isDetained = true,
    this.releasedWithoutWarrant = false,
    this.physicalThreatLevel,
  });

  final ArrestType arrestType;
  final DateTime t0;
  final List<SgpTimeTableNode> nodes;
  final bool isDetained;
  final bool releasedWithoutWarrant;
  final PhysicalThreatLevel? physicalThreatLevel;

  Duration elapsedFrom(DateTime now) => now.difference(t0);

  SgpProcedureTimeline refresh(DateTime now) {
    var assignActive = true;
    final updated = <SgpTimeTableNode>[];
    for (final node in nodes) {
      final refreshed = kImmediatePhaseNodeIds.contains(node.id)
          ? _refreshImmediateNode(node, now)
          : _refreshNode(node, now, assignActive: assignActive);
      updated.add(refreshed);
      if (!kImmediatePhaseNodeIds.contains(node.id) &&
          refreshed.status != TimelineNodeStatus.completed) {
        assignActive = false;
      }
    }
    return copyWith(nodes: updated);
  }

  SgpTimeTableNode _refreshImmediateNode(SgpTimeTableNode node, DateTime now) {
    if (node.checkItems.every((c) => c.checked)) {
      return node.copyWith(status: TimelineNodeStatus.completed);
    }
    final remaining = node.remainingFrom(now);
    if (remaining.isNegative) {
      return node.copyWith(status: TimelineNodeStatus.expired);
    }
    if (remaining <= const Duration(minutes: 10)) {
      return node.copyWith(status: TimelineNodeStatus.critical);
    }
    return node.copyWith(status: TimelineNodeStatus.inProgress);
  }

  SgpTimeTableNode _refreshNode(SgpTimeTableNode node, DateTime now, {required bool assignActive}) {
    if (node.id == 't0') {
      return node.copyWith(status: TimelineNodeStatus.completed);
    }
    if (node.checkItems.every((c) => c.checked)) {
      return node.copyWith(status: TimelineNodeStatus.completed);
    }
    final remaining = node.remainingFrom(now);
    if (remaining.isNegative) {
      return node.copyWith(status: TimelineNodeStatus.expired);
    }
    if (remaining <= const Duration(hours: 3)) {
      return node.copyWith(status: TimelineNodeStatus.critical);
    }
    if (assignActive || remaining <= const Duration(hours: 12)) {
      return node.copyWith(status: TimelineNodeStatus.inProgress);
    }
    return node.copyWith(status: TimelineNodeStatus.pending);
  }

  bool get hasCriticalDeadline {
    return nodes.any((n) => n.status == TimelineNodeStatus.critical);
  }

  SgpProcedureTimeline copyWith({
    List<SgpTimeTableNode>? nodes,
    bool? isDetained,
    bool? releasedWithoutWarrant,
    PhysicalThreatLevel? physicalThreatLevel,
  }) {
    return SgpProcedureTimeline(
      arrestType: arrestType,
      t0: t0,
      nodes: nodes ?? this.nodes,
      isDetained: isDetained ?? this.isDetained,
      releasedWithoutWarrant: releasedWithoutWarrant ?? this.releasedWithoutWarrant,
      physicalThreatLevel: physicalThreatLevel ?? this.physicalThreatLevel,
    );
  }

  SgpProcedureTimeline toggleCheck(String nodeId, String checkId, bool value) {
    final updated = nodes.map((node) {
      if (node.id != nodeId) return node;
      return node.copyWith(
        checkItems: node.checkItems
            .map((c) => c.id == checkId ? c.copyWith(checked: value) : c)
            .toList(),
      );
    }).toList();
    return copyWith(nodes: updated).refresh(DateTime.now());
  }
}

// ---------------------------------------------------------------------------
// AI·체크리스트 기반 체포 방식 추정
// ---------------------------------------------------------------------------

ArrestType? detectArrestType({
  required String rawText,
  required LawCheckList checklist,
}) {
  if (RegExp(r'(영장.*체포|체포.*영장|영장체포)').hasMatch(rawText)) {
    return ArrestType.warrant;
  }
  if (RegExp(r'(긴급체포|제200조의2|200조의2)').hasMatch(rawText)) {
    return ArrestType.emergency;
  }
  if (checklist.isFleeing ||
      RegExp(r'(현행범|도주.*체포|체포.*도주|현장.*체포)').hasMatch(rawText)) {
    return ArrestType.currentOffender;
  }
  if (RegExp(r'(체포|검거|연행)').hasMatch(rawText)) {
    return ArrestType.currentOffender;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 형소법 시한 계산
// ---------------------------------------------------------------------------

/// T-0 기준 마감 시각 계산.
ProcedureDeadlines calculateProcedureDeadlines({
  required DateTime t0,
  required ArrestType arrestType,
}) {
  return ProcedureDeadlines(
    t0: t0,
    notifyFamilyBy: t0.add(const Duration(hours: 24)),
    warrantApplicationBy: t0.add(const Duration(hours: 45)),
    prosecutorCourtFilingBy: t0.add(const Duration(hours: 48)),
    policeTransferBy: t0.add(const Duration(days: 10)),
    postReleaseCourtNotifyBy: t0.add(const Duration(days: 30)),
    arrestType: arrestType,
  );
}

class ProcedureDeadlines {
  const ProcedureDeadlines({
    required this.t0,
    required this.notifyFamilyBy,
    required this.warrantApplicationBy,
    required this.prosecutorCourtFilingBy,
    required this.policeTransferBy,
    required this.postReleaseCourtNotifyBy,
    required this.arrestType,
  });

  final DateTime t0;
  final DateTime notifyFamilyBy;
  final DateTime warrantApplicationBy;
  final DateTime prosecutorCourtFilingBy;
  final DateTime policeTransferBy;
  final DateTime postReleaseCourtNotifyBy;
  final ArrestType arrestType;
}

/// 체포 확정 시 타임라인 노드 생성.
SgpProcedureTimeline buildProcedureTimeline({
  required ArrestType arrestType,
  required DateTime t0,
  bool isDetained = true,
  bool releasedWithoutWarrant = false,
}) {
  final d = calculateProcedureDeadlines(t0: t0, arrestType: arrestType);
  final nodes = <SgpTimeTableNode>[
    SgpTimeTableNode(
      id: 't0',
      title: '${arrestType.displayName} 완료',
      legalReference: arrestType.legalBasis,
      deadline: d.t0,
      offsetLabel: 'T-0 (${_fmtClock(d.t0)})',
      actionGuide: '미란다 원칙 고지 및 체포 적법성 요건 문언화',
      status: TimelineNodeStatus.completed,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'miranda',
          label: '미란다 원칙 고지서 확인·서명 접수 여부',
        ),
        SgpTimelineCheckItem(
          id: 'arrest_record',
          label: '체포 경위·시각·장소 기록 완료',
        ),
        SgpTimelineCheckItem(
          id: 'weapon_log',
          label: '흉기·위험물 압수 시 위수증 방지 채증',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'victim_separation',
      title: '가·피해자 즉시 분리',
      legalReference: '가정폭력처벌법·수사 실무 (교차 진술 방지)',
      deadline: d.t0.add(const Duration(minutes: 30)),
      offsetLabel: 'T-0 직후 (30분 이내)',
      actionGuide: '피해자·가해자 물리적 분리 — 동시 조사·대질 신문 금지',
      status: TimelineNodeStatus.inProgress,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'separate_room',
          label: '별실·별 차량 분리 완료',
        ),
        SgpTimelineCheckItem(
          id: 'victim_safety',
          label: '피해자 안전·응급조치 확인',
        ),
        SgpTimelineCheckItem(
          id: 'cross_contamination',
          label: '교차 진술 오염 방지 조치',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'physical_force',
      title: '단계적 물리력 대응 가이드',
      legalReference: '경찰관 직무집행법 제8조·제10조 (비례원칙)',
      deadline: d.t0.add(const Duration(minutes: 30)),
      offsetLabel: 'T-0 직후 (위해 수준 평가)',
      actionGuide: '피의자 위해 수준 선택 → 허용 장구·기술·절차 요건 확인',
      status: TimelineNodeStatus.inProgress,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'threat_assessed',
          label: '피의자 위해 수준 평가·기록 완료',
        ),
        SgpTimelineCheckItem(
          id: 'force_proportionality',
          label: '비례원칙 준수 대응 실행 확인',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'evidence_notice',
      title: '현장 채증 법적 고지',
      legalReference: '경찰관 직무집행법 제10조의2',
      deadline: d.t0.add(const Duration(minutes: 15)),
      offsetLabel: 'T-0 직후 (채증 전 필수)',
      actionGuide: '「채증 시작」 버튼 → 법적 고지 스크립트 낭독 후 녹화 개시',
      status: TimelineNodeStatus.inProgress,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'evidence_legal_notice',
          label: '채증 법적고지 완료',
        ),
        SgpTimelineCheckItem(
          id: 'recording_started',
          label: '영상·음성 녹화 개시 시각 기록',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'custody_handover_prep',
      title: '신병 인계·구금 준비',
      legalReference: '형사절차법·경찰 수용 실무',
      deadline: d.t0.add(const Duration(hours: 2)),
      offsetLabel: 'T-0 후 2시간 이내',
      actionGuide: '구금장 이송·신병 인계 전 건강검진·소지품 목록·인계 서명',
      status: TimelineNodeStatus.inProgress,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'health_check',
          label: '피의자 건강상태·외상 확인 기록',
        ),
        SgpTimelineCheckItem(
          id: 'belongings_list',
          label: '소지품 목록 작성·인계',
        ),
        SgpTimelineCheckItem(
          id: 'custody_signature',
          label: '신병 인계 서명·시각 기록',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'legal_report',
      title: '사법 무결성 초동조치 보고서',
      legalReference: '경찰 수사기록 작성 규정·형사절차 준수',
      deadline: d.t0.add(const Duration(hours: 3)),
      offsetLabel: 'T-0 초동조치 완료',
      actionGuide: '현장 수집 데이터 기반 대법원 판례 인용 보고서 생성·송부',
      status: TimelineNodeStatus.inProgress,
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'report_generated',
          label: '초동조치 보고서 생성·송부 완료',
        ),
      ],
    ),
    SgpTimeTableNode(
      id: 'notify_24h',
      title: '피의자 체포 통지서 발송',
      legalReference: '형소법 제212조 (체포 통지)',
      deadline: d.notifyFamilyBy,
      offsetLabel: 'T+24 (${_fmtClock(d.notifyFamilyBy)}까지)',
      actionGuide: '피의자가 지정한 가족 등에게 체포 사유·일시 서면 통지',
      checkItems: const [
        SgpTimelineCheckItem(
          id: 'family_notice',
          label: '체포통지서 전송 여부 (가족·지정인 통지)',
        ),
        SgpTimelineCheckItem(
          id: 'notice_proof',
          label: '통지 시각·수령인·방법 기록 보존',
        ),
      ],
    ),
  ];

  if (arrestType == ArrestType.currentOffender || arrestType == ArrestType.emergency) {
    nodes.addAll([
      SgpTimeTableNode(
        id: 'warrant_45h',
        title: '구속영장 신청 마감 (검사 송부)',
        legalReference: '형소법 제200조의2·제213조의2',
        deadline: d.warrantApplicationBy,
        offsetLabel: 'T+45 (${_fmtClock(d.warrantApplicationBy)}까지)',
        actionGuide: '영장 신청서·범죄사실·구속사유(도주·증거인멸) 소명자료 취합',
        checkItems: const [
          SgpTimelineCheckItem(
            id: 'warrant_draft',
            label: '구속영장 신청서 작성 완료',
          ),
          SgpTimelineCheckItem(
            id: 'detention_reason',
            label: '구속 필요 사유(도주·증거인멸) 소명서 작성',
          ),
          SgpTimelineCheckItem(
            id: 'evidence_pack',
            label: '범죄사실·증거 목록 검사 송부',
          ),
        ],
      ),
      SgpTimeTableNode(
        id: 'court_48h',
        title: '검사 법원 영장 청구 시한 (참고)',
        legalReference: '형소법 제213조의2 (48시간 이내 청구)',
        deadline: d.prosecutorCourtFilingBy,
        offsetLabel: 'T+48 (${_fmtClock(d.prosecutorCourtFilingBy)}까지)',
        actionGuide: '검사가 법원에 구속영장 청구 완료 여부 수사관 확인',
        checkItems: const [
          SgpTimelineCheckItem(
            id: 'prosecutor_confirm',
            label: '검사 영장 청구 완료 여부 확인',
          ),
        ],
      ),
    ]);
  }

  if (isDetained) {
    nodes.add(
      SgpTimeTableNode(
        id: 'transfer_10d',
        title: '검찰 구속 송치 마감',
        legalReference: '형소법 제202조 (경찰 구속 10일)',
        deadline: d.policeTransferBy,
        offsetLabel: 'T+10일 (${_fmtDate(d.policeTransferBy)}까지)',
        actionGuide: '구속 피의자 검찰 인도·송치 — 연장 불가 절대 시한',
        isAbsoluteDeadline: true,
        checkItems: const [
          SgpTimelineCheckItem(
            id: 'transfer_docs',
            label: '송치 서류·수사기록 정본 완비',
          ),
          SgpTimelineCheckItem(
            id: 'custody_log',
            label: '구속 기간·조사 일지 대조 완료',
          ),
        ],
      ),
    );
  }

  if (releasedWithoutWarrant &&
      (arrestType == ArrestType.emergency || arrestType == ArrestType.currentOffender)) {
    nodes.add(
      SgpTimeTableNode(
        id: 'release_notify_30d',
        title: '긴급체포 후 석방 사후 통지',
        legalReference: '형소법 제200조의4',
        deadline: d.postReleaseCourtNotifyBy,
        offsetLabel: 'T+30일 (${_fmtDate(d.postReleaseCourtNotifyBy)}까지)',
        actionGuide: '영장 미청구 석방 시 법원에 서면 통지',
        checkItems: const [
          SgpTimelineCheckItem(
            id: 'court_written',
            label: '법원 서면 통지서 발송 완료',
          ),
        ],
      ),
    );
  }

  return SgpProcedureTimeline(
    arrestType: arrestType,
    t0: t0,
    nodes: nodes,
    isDetained: isDetained,
    releasedWithoutWarrant: releasedWithoutWarrant,
  ).refresh(DateTime.now());
}

String _fmtClock(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _fmtDate(DateTime dt) {
  return '${dt.month}/${dt.day} ${_fmtClock(dt)}';
}

String formatRemainingDuration(Duration d) {
  if (d.isNegative) {
    final over = d.abs();
    return '초과 ${over.inHours}시간 ${over.inMinutes % 60}분';
  }
  if (d.inDays > 0) {
    return '${d.inDays}일 ${d.inHours % 24}시간 ${d.inMinutes % 60}분';
  }
  return '${d.inHours}시간 ${d.inMinutes % 60}분 ${d.inSeconds % 60}초';
}

// ---------------------------------------------------------------------------
// UI — 실시간 타임라인 위젯
// ---------------------------------------------------------------------------

/// 하단 고정형 사법 절차 타임라인 (Ticker 실시간 카운트다운).
class SgpTimelineWidget extends StatefulWidget {
  const SgpTimelineWidget({
    super.key,
    required this.timeline,
    required this.onCheckChanged,
    this.onDismiss,
    this.maxHeight = 320,
    this.embeddedInParentScroll = false,
    this.physicalThreatLevel,
    this.onThreatLevelChanged,
    this.forceAssessment,
    this.onStartEvidenceNotice,
    this.onGenerateReport,
    this.forceGuideRawText = '',
    this.forceExecutionLogged = false,
    this.onForceExecutionLogged,
  });

  final SgpProcedureTimeline timeline;
  final void Function(String nodeId, String checkId, bool value) onCheckChanged;
  final VoidCallback? onDismiss;
  final double maxHeight;
  /// 부모 [SingleChildScrollView] 안에 넣을 때 내부 스크롤·높이 제한 해제.
  final bool embeddedInParentScroll;
  final PhysicalThreatLevel? physicalThreatLevel;
  final ValueChanged<PhysicalThreatLevel>? onThreatLevelChanged;
  final ConstitutionalForceAssessment? forceAssessment;
  final Future<void> Function()? onStartEvidenceNotice;
  final Future<void> Function()? onGenerateReport;
  final String forceGuideRawText;
  final bool forceExecutionLogged;
  final ValueChanged<String>? onForceExecutionLogged;

  @override
  State<SgpTimelineWidget> createState() => _SgpTimelineWidgetState();
}

class _SgpTimelineWidgetState extends State<SgpTimelineWidget> {
  Timer? _countdownTimer;
  late DateTime _now;
  bool _criticalAlertFired = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final refreshed = widget.timeline.refresh(now);
      if (refreshed.hasCriticalDeadline && !_criticalAlertFired) {
        _criticalAlertFired = true;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      if (!refreshed.hasCriticalDeadline) {
        _criticalAlertFired = false;
      }
      setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = widget.timeline.refresh(_now);
    final elapsed = timeline.elapsedFrom(_now);

    return Material(
      elevation: 8,
      color: Colors.grey.shade50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(timeline, elapsed),
          if (widget.embeddedInParentScroll)
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              primary: false,
              itemCount: timeline.nodes.length,
              itemBuilder: (context, index) {
                final node = timeline.nodes[index];
                final isLast = index == timeline.nodes.length - 1;
                return _TimelineNodeTile(
                  node: node,
                  now: _now,
                  showConnector: !isLast,
                  onCheckChanged: widget.onCheckChanged,
                  physicalThreatLevel: widget.physicalThreatLevel,
                  onThreatLevelChanged: widget.onThreatLevelChanged,
                  forceAssessment: widget.forceAssessment,
                  onStartEvidenceNotice: widget.onStartEvidenceNotice,
                  onGenerateReport: widget.onGenerateReport,
                  forceGuideRawText: widget.forceGuideRawText,
                  forceExecutionLogged: widget.forceExecutionLogged,
                  onForceExecutionLogged: widget.onForceExecutionLogged,
                );
              },
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                primary: false,
                itemCount: timeline.nodes.length,
                itemBuilder: (context, index) {
                  final node = timeline.nodes[index];
                  final isLast = index == timeline.nodes.length - 1;
                  return _TimelineNodeTile(
                    node: node,
                    now: _now,
                    showConnector: !isLast,
                    onCheckChanged: widget.onCheckChanged,
                    physicalThreatLevel: widget.physicalThreatLevel,
                    onThreatLevelChanged: widget.onThreatLevelChanged,
                    forceAssessment: widget.forceAssessment,
                    onStartEvidenceNotice: widget.onStartEvidenceNotice,
                    onGenerateReport: widget.onGenerateReport,
                    forceGuideRawText: widget.forceGuideRawText,
                    forceExecutionLogged: widget.forceExecutionLogged,
                    onForceExecutionLogged: widget.onForceExecutionLogged,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(SgpProcedureTimeline timeline, Duration elapsed) {
    final hours = elapsed.inHours;
    final statusColor = timeline.hasCriticalDeadline
        ? Colors.red.shade700
        : elapsed.inHours >= 12
            ? Colors.orange.shade800
            : Colors.green.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: statusColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SGP-Agent 사법 절차 타임라인',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SgpFieldColors.fieldGuideNavy,
                  ),
                ),
                Text(
                  '${timeline.arrestType.displayName} 후 ${hours}시간 경과',
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (widget.onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onDismiss,
              tooltip: '타임라인 닫기',
            ),
        ],
      ),
    );
  }
}

class _TimelineNodeTile extends StatelessWidget {
  const _TimelineNodeTile({
    required this.node,
    required this.now,
    required this.showConnector,
    required this.onCheckChanged,
    this.physicalThreatLevel,
    this.onThreatLevelChanged,
    this.forceAssessment,
    this.onStartEvidenceNotice,
    this.onGenerateReport,
    this.forceGuideRawText = '',
    this.forceExecutionLogged = false,
    this.onForceExecutionLogged,
  });

  final SgpTimeTableNode node;
  final DateTime now;
  final bool showConnector;
  final void Function(String nodeId, String checkId, bool value) onCheckChanged;
  final PhysicalThreatLevel? physicalThreatLevel;
  final ValueChanged<PhysicalThreatLevel>? onThreatLevelChanged;
  final ConstitutionalForceAssessment? forceAssessment;
  final Future<void> Function()? onStartEvidenceNotice;
  final Future<void> Function()? onGenerateReport;
  final String forceGuideRawText;
  final bool forceExecutionLogged;
  final ValueChanged<String>? onForceExecutionLogged;

  @override
  Widget build(BuildContext context) {
    final color = node.status.accent;
    final remaining = node.remainingFrom(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey.shade300,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: node.isAbsoluteDeadline ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            node.status.signalLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            node.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: SgpFieldColors.fieldGuideNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      node.offsetLabel,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                    if (node.id != 't0')
                      Text(
                        '남은 시간: ${formatRemainingDuration(remaining)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: node.status == TimelineNodeStatus.critical
                              ? Colors.red.shade700
                              : kImmediatePhaseNodeIds.contains(node.id)
                                  ? Colors.orange.shade800
                                  : Colors.black87,
                          fontWeight: node.status == TimelineNodeStatus.critical ||
                                  kImmediatePhaseNodeIds.contains(node.id)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    Text(
                      node.legalReference,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '💡 ${node.actionGuide}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: SgpFieldColors.fieldGuideNavy,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (node.id == 'physical_force' && onThreatLevelChanged != null) ...[
                      const SizedBox(height: 8),
                      SgpPhysicalForceGuideWidget(
                        selectedLevel: physicalThreatLevel,
                        onLevelChanged: (level) {
                          onThreatLevelChanged!(level);
                          onCheckChanged(node.id, 'threat_assessed', true);
                        },
                        compact: true,
                        assessment: forceAssessment,
                        rawText: forceGuideRawText,
                        forceExecutionLogged: forceExecutionLogged,
                        onForceExecutionLogged: onForceExecutionLogged,
                      ),
                    ],
                    if (node.id == 'evidence_notice' && onStartEvidenceNotice != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => onStartEvidenceNotice!(),
                          icon: const Icon(Icons.videocam, size: 18),
                          label: const Text('채증 시작 — 법적 고지'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SgpAppTheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                    if (node.id == kLegalReportNodeId && onGenerateReport != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => onGenerateReport!(),
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('판례 인용 보고서 생성 및 복사'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                    ...node.checkItems.map(
                      (item) => CheckboxListTile(
                        value: item.checked,
                        onChanged: (v) => onCheckChanged(node.id, item.id, v ?? false),
                        title: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SgpFieldColors.fieldGuideBody,
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
      ],
    );
  }
}

/// 체포 확정 다이얼로그.
Future<SgpProcedureTimeline?> showArrestConfirmDialog(
  BuildContext context, {
  required ArrestType suggestedType,
  DateTime? t0,
}) async {
  var selected = suggestedType;
  var detained = true;
  var released = false;
  final arrestTime = t0 ?? DateTime.now();

  return showDialog<SgpProcedureTimeline>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('체포 확정 — T-0 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '체포 시각: ${_fmtDate(arrestTime)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...ArrestType.values.map(
                (t) => RadioListTile<ArrestType>(
                  title: Text(t.displayName, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(t.legalBasis, style: const TextStyle(fontSize: 10)),
                  value: t,
                  groupValue: selected,
                  onChanged: (v) => setLocal(() => selected = v!),
                  dense: true,
                ),
              ),
              SwitchListTile(
                title: const Text('경찰 구속 중', style: TextStyle(fontSize: 13)),
                subtitle: const Text('형소법 제202조 10일 송치 시한 적용'),
                value: detained,
                onChanged: (v) => setLocal(() => detained = v),
              ),
              if (selected == ArrestType.emergency || selected == ArrestType.currentOffender)
                SwitchListTile(
                  title: const Text('영장 없이 석방 예정'),
                  subtitle: const Text('제200조의4 30일 사후 통지 노드 추가'),
                  value: released,
                  onChanged: (v) => setLocal(() => released = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                ctx,
                buildProcedureTimeline(
                  arrestType: selected,
                  t0: arrestTime,
                  isDetained: detained,
                  releasedWithoutWarrant: released,
                ),
              );
            },
            child: const Text('체포 확정 — 타임라인 시작'),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> procedureTimelineToJson(SgpProcedureTimeline timeline) => {
      'arrestType': timeline.arrestType.name,
      't0': timeline.t0.toIso8601String(),
      'isDetained': timeline.isDetained,
      'releasedWithoutWarrant': timeline.releasedWithoutWarrant,
      'physicalThreatLevel': timeline.physicalThreatLevel?.name,
      'nodes': timeline.nodes.map((n) => n.toJson()).toList(),
    };

SgpProcedureTimeline? procedureTimelineFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  final arrestName = json['arrestType'] as String? ?? ArrestType.currentOffender.name;
  final arrestType = ArrestType.values.byName(arrestName);
  final t0 = DateTime.tryParse(json['t0'] as String? ?? '') ?? DateTime.now();
  final nodesJson = json['nodes'] as List<dynamic>? ?? [];
  final nodes = nodesJson.map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final checks = (m['checkItems'] as List<dynamic>? ?? [])
        .map((c) => SgpTimelineCheckItem.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
    return SgpTimeTableNode(
      id: m['id'] as String,
      title: m['title'] as String,
      legalReference: m['legalReference'] as String,
      deadline: DateTime.parse(m['deadline'] as String),
      offsetLabel: m['offsetLabel'] as String,
      actionGuide: m['actionGuide'] as String,
      checkItems: checks,
      status: TimelineNodeStatus.values.byName(m['status'] as String? ?? 'pending'),
      isAbsoluteDeadline: m['isAbsoluteDeadline'] as bool? ?? false,
    );
  }).toList();

  return SgpProcedureTimeline(
    arrestType: arrestType,
    t0: t0,
    nodes: nodes,
    isDetained: json['isDetained'] as bool? ?? true,
    releasedWithoutWarrant: json['releasedWithoutWarrant'] as bool? ?? false,
    physicalThreatLevel:
        SgpPhysicalForceGuide.fromJson(json['physicalThreatLevel'] as String?),
  ).refresh(DateTime.now());
}
