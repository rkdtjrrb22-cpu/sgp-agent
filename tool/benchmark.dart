/// 오프라인 벤치마크 실행: dart run tool/benchmark.dart
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';

Future<void> main() async {
  final engine = SgpAgentEngine();

  print('=== SGP-Agent 오프라인 벤치마크 (스텁 sLLM) ===');
  print('모델 Lazy Loading...');
  await engine.loadModel();
  print('모델 적재 완료: ${engine.isLoaded}');

  for (final name in ['주취폭행', '스토킹']) {
    final result = await engine.runBenchmark(name);
    print(result);
  }

  engine.dispose();
  print('dispose 완료 — RAM 해제: ${!engine.isLoaded}');
}
