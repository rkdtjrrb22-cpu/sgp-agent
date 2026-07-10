import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_procedure_timeline.dart';

void main() {
  testWidgets('SgpTimelineWidget renders without layout error', (tester) async {
    final timeline = buildProcedureTimeline(
      arrestType: ArrestType.currentOffender,
      t0: DateTime(2026, 7, 10, 13, 23),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SgpTimelineWidget(
            timeline: timeline,
            onCheckChanged: (_, __, ___) {},
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('SGP-Agent 사법 절차 타임라인'), findsOneWidget);
    expect(find.textContaining('현행범 체포'), findsWidgets);
  });
}
