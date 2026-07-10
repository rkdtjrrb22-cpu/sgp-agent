import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:sgp_agent/features/agent/sgp_procedure_timeline.dart';

void main() {
  group('calculateProcedureDeadlines', () {
    test('T-0 기준 24/45/48시간·10일 시한', () {
      final t0 = DateTime(2026, 7, 10, 13, 23);
      final d = calculateProcedureDeadlines(
        t0: t0,
        arrestType: ArrestType.currentOffender,
      );

      expect(d.notifyFamilyBy, t0.add(const Duration(hours: 24)));
      expect(d.warrantApplicationBy, t0.add(const Duration(hours: 45)));
      expect(d.prosecutorCourtFilingBy, t0.add(const Duration(hours: 48)));
      expect(d.policeTransferBy, t0.add(const Duration(days: 10)));
    });
  });

  group('buildProcedureTimeline', () {
    test('현행범 체포 노드 구성', () {
      final t0 = DateTime(2026, 7, 10, 13, 23);
      final timeline = buildProcedureTimeline(
        arrestType: ArrestType.currentOffender,
        t0: t0,
      );

      expect(timeline.nodes.first.id, 't0');
      expect(timeline.nodes.first.status, TimelineNodeStatus.completed);
      expect(timeline.nodes.any((n) => n.id == 'victim_separation'), isTrue);
      expect(timeline.nodes.any((n) => n.id == 'physical_force'), isTrue);
      expect(timeline.nodes.any((n) => n.id == 'evidence_notice'), isTrue);
      expect(timeline.nodes.any((n) => n.id == 'custody_handover_prep'), isTrue);
      expect(timeline.nodes.any((n) => n.id == 'legal_report'), isTrue);
      final evidenceNode = timeline.nodes.firstWhere((n) => n.id == 'evidence_notice');
      expect(
        evidenceNode.checkItems.any((c) => c.id == 'evidence_legal_notice'),
        isTrue,
      );
      expect(timeline.nodes.any((n) => n.id == 'warrant_45h'), isTrue);
      expect(timeline.nodes.any((n) => n.id == 'transfer_10d'), isTrue);
    });

    test('긴급체포 석방 시 30일 통지 노드', () {
      final timeline = buildProcedureTimeline(
        arrestType: ArrestType.emergency,
        t0: DateTime.now(),
        isDetained: false,
        releasedWithoutWarrant: true,
      );
      expect(timeline.nodes.any((n) => n.id == 'release_notify_30d'), isTrue);
    });
  });

  group('detectArrestType', () {
    test('도주 체크 시 현행범 추정', () {
      expect(
        detectArrestType(
          rawText: '피의자 도주 후 검거',
          checklist: const LawCheckList(isFleeing: true),
        ),
        ArrestType.currentOffender,
      );
    });

    test('영장 키워드', () {
      expect(
        detectArrestType(
          rawText: '영장에 의한 체포 실행',
          checklist: const LawCheckList(),
        ),
        ArrestType.warrant,
      );
    });
  });

  group('formatRemainingDuration', () {
    test('남은 시간 포맷', () {
      expect(
        formatRemainingDuration(const Duration(hours: 33, minutes: 15)),
        contains('33시간'),
      );
    });
  });
}
