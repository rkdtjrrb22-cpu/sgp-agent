/// 현장 채증 법적 고지 프로토콜 — 스크립트·팝업.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 채증 고지 스크립트 (현장 낭독용).
class SgpEvidenceNoticeScript {
  const SgpEvidenceNoticeScript._();

  static const String legalBasis = '경찰관 직무집행법 제10조의2';

  static const String primaryScript =
      '경찰관 직무집행법 제10조의2에 의거, 귀하의 불법 행위(폭행/소란)에 대해 '
      '현 시간부로 영상 촬영 및 음성 녹음을 실시합니다. '
      '촬영·녹음 자료는 수사 목적으로만 사용되며, '
      '귀하는 촬영 거부권이 제한될 수 있음을 고지합니다.';

  static const String domesticViolenceScript =
      '경찰관 직무집행법 제10조의2 및 가정폭력처벌법에 의거, '
      '가정폭력 관련 현장 조사를 위해 영상 촬영 및 음성 녹음을 실시합니다. '
      '피해자·가해자 분리 상태에서 채증이 진행됩니다.';

  static const String weaponSeizureScript =
      '경찰관 직무집행법 제10조의2에 의거, 흉기·위험물 압수 및 '
      '위수증 방지를 위한 현장 채증(영상·음성)을 실시합니다. '
      '압수 절차는 형사소송법에 따릅니다.';

  static List<String> readingSteps(String script) => [
        '1. 피의자·관계인에게 정면 응시하며 낭독',
        '2. "위 내용을 이해하셨습니까?" 확인 질문',
        '3. 거부·소란 시에도 채증 계속 — 거부 발언 별도 녹음',
        '4. 고지 완료 시각·장소·목격자를 수사일지에 기재',
        '5. 바디캠·휴대 녹화기 동시 가동 여부 확인',
      ];
}

/// 거대 팝업 — 현장 즉시 낭독용 채증 고지.
Future<bool?> showEvidenceNoticeDialog(
  BuildContext context, {
  String? offenseHint,
}) {
  final script = offenseHint != null && offenseHint.contains('가정')
      ? SgpEvidenceNoticeScript.domesticViolenceScript
      : offenseHint != null &&
              (offenseHint.contains('흉기') || offenseHint.contains('압수'))
          ? SgpEvidenceNoticeScript.weaponSeizureScript
          : SgpEvidenceNoticeScript.primaryScript;

  final steps = SgpEvidenceNoticeScript.readingSteps(script);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현장 채증 법적 고지',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          SgpEvidenceNoticeScript.legalBasis,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300, width: 2),
                      ),
                      child: SelectableText(
                        script,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '낭독 절차 체크리스트',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...steps.map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(step, style: const TextStyle(fontSize: 13, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: script));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('고지 스크립트가 클립보드에 복사되었습니다.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('복사'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.record_voice_over),
                      label: const Text('고지 완료 — 채증 개시'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
