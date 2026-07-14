/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Flush Overlay
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 「시스템 최적화 및 환각 방지 세척 중」 비동기 오버레이 + 입력 차단.
library;

import 'package:flutter/material.dart';

import '../../agent/sgp_app_theme.dart';

class SgpGlymphaticFlushOverlay extends StatelessWidget {
  const SgpGlymphaticFlushOverlay({
    super.key,
    required this.visible,
    this.message = '시스템 최적화 및 환각 방지 세척 중',
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Material(
              color: SgpFieldColors.surface,
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: SgpAppTheme.info,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: SgpFieldColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1단계  입력·STT 일시정지\n'
                      '2단계  컨텍스트 정화·핑퐁 핸드셰이킹\n'
                      '3단계  최대 3.5초 후 자동 복구 (Fail-Safe)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: SgpFieldColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
