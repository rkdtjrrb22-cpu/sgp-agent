import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/main.dart';

void main() {
  testWidgets('SGP-Agent home renders liability panel', (tester) async {
    await tester.pumpWidget(const SgpAgentApp());
    await tester.pump();

    expect(find.text('SGP-Agent'), findsOneWidget);
    expect(find.textContaining('출동 수사관 본인의 주체적인 판단'), findsOneWidget);
    expect(find.text('자기판단 선택 및 서류 확정'), findsOneWidget);
  });
}
