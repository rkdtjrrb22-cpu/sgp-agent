/// 법령 준수 방어 모듈 — 통비법·정통법·전파법·보안업무규정 대응.
///
/// [설계 원칙 — 저촉 방지 근거]
///
/// 1. 통신비밀보호법 (통비법)
///    - 본 앱의 STT는 수사관이 버튼을 눌러 시작하는 명시적 조작 방식이며,
///      백그라운드 상시 감청·자동 녹음을 하지 않는다.
///    - 녹음 대상은 수사관 본인이 당사자로 참여하는 현장 대화·무전이며,
///      제3자 간 통신의 청취·녹음(감청)에 해당하지 않도록
///      최초 사용 시 준수 고지를 표시한다 ([showSttComplianceNotice]).
///    - 채증 시 경찰관 직무집행법 제10조의2에 따른 사전 고지 스크립트를 제공한다.
///
/// 2. 정보통신망법 (정통법)
///    - 수사자료(무전 원문·조서·분석 결과)는 단말 내부 저장소에만 기록하며
///      어떤 서버로도 전송하지 않는다 (온디바이스 원칙).
///    - 네트워크 사용은 판례 트렌드 수신(다운로드 단방향)뿐이며,
///      공식 배포 채널 승인 전까지 원격 OTA는 기본 비활성이다
///      ([kEnableRemoteOta] = false).
///
/// 3. 전파법
///    - 본 앱은 무선 설비를 직접 운용·송신·복조하지 않는다.
///    - Bluetooth SCO·USB 오디오는 전파인증을 받은 상용 기기의
///      표준 오디오 입력 경로만 사용하며, 주파수 수신·감청 기능이 없다.
///
/// 4. 보안업무규정
///    - 외부 공유(Share) 전 수사자료 반출 확인 대화상자를 강제한다.
///    - 승인된 업무 채널 사용 책임을 전송자에게 고지한다.
library;

import 'package:flutter/material.dart';

/// 원격 OTA 판례 패치 활성 여부.
///
/// 공식 배포 채널(경찰청 승인 서버) 확정 전까지 false 유지 —
/// 비공식 저장소 패치 수신은 보안업무규정·공급망 위험이 있다.
const bool kEnableRemoteOta = false;

/// STT 최초 사용 시 통비법 준수 고지 (앱 세션당 1회).
class SgpSttComplianceGate {
  SgpSttComplianceGate._();

  static bool _acknowledgedThisSession = false;

  static bool get acknowledged => _acknowledgedThisSession;

  /// 고지를 표시하고 수사관 확인을 받는다. 이미 확인했으면 즉시 true.
  static Future<bool> ensureAcknowledged(BuildContext context) async {
    if (_acknowledgedThisSession) return true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.record_voice_over, size: 32),
        title: const Text('음성 수신 준수 고지'),
        content: const Text(
          '통신비밀보호법 준수를 위해 다음을 확인합니다.\n\n'
          '1. 본 기능은 수사관 본인이 참여·청취하는 현장 대화 및 '
          '지령 무전의 기록에만 사용합니다.\n\n'
          '2. 제3자 간 통신의 몰래 녹음(감청)에 사용할 수 없습니다.\n\n'
          '3. 채증 목적 녹음 시 경찰관 직무집행법 제10조의2에 따른 '
          '사전 고지를 이행합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인 — 준수하여 사용'),
          ),
        ],
      ),
    );

    if (ok == true) {
      _acknowledgedThisSession = true;
      return true;
    }
    return false;
  }

  /// 테스트·세션 초기화용.
  @visibleForTesting
  static void reset() => _acknowledgedThisSession = false;
}

/// Sprint S4 — LV 7~8 조직 규정·매뉴얼 접근 통제.
///
/// 보안업무규정: 조직 내부 규정(LV7)·현장 매뉴얼(LV8)은 인가된 조직
/// 세션에서만 열람한다. 서버형(Phase 2)에서는 JWT·단말 조직 패키지로
/// 대체되며, 온디바이스에서는 단말에 프로비저닝된 조직 ID로 판정한다.
abstract final class SgpOrgAccessGate {
  /// 단말에 프로비저닝된 조직 ID (기본: 경찰청). 프로비저닝 전에는 null.
  static String? _provisionedOrgId = 'KR-NPA';

  static String? get provisionedOrgId => _provisionedOrgId;

  /// 단말 조직 프로비저닝 (MDM·초기 설정에서 1회 설정).
  static void provision(String? orgId) => _provisionedOrgId = orgId;

  /// 특정 조직 규정·매뉴얼 노드를 열람할 수 있는지 판정.
  static bool canAccessOrg(String? nodeOrgId) {
    if (nodeOrgId == null) return true;
    if (_provisionedOrgId == null) return false;
    return _provisionedOrgId == nodeOrgId;
  }

  /// 테스트·세션 초기화용.
  @visibleForTesting
  static void reset() => _provisionedOrgId = 'KR-NPA';
}
