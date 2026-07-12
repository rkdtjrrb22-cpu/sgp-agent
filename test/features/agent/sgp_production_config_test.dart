import 'package:sgp_agent/features/agent/sgp_production_config.dart';
import 'package:test/test.dart';

void main() {
  group('SgpProductionConfig', () {
    test('offline stub defaults for field demo', () {
      expect(kUseProductionStub, isTrue);
      expect(kLawSyncRequireLiveKey, isFalse);
    });
  });
}
