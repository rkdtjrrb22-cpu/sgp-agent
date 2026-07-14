/// Stage 5 — 은은한 HCI 안전 배너 (로컬 법령 잔상 가동 안내).
library;

import 'package:flutter/material.dart';

import '../sgp_law_offgrid_sync.dart';

/// 통신 단절·폐쇄망 시 상단 안내 — 사법적 유효 기한 인지용.
class SgpLawSnapshotOfflineBanner extends StatelessWidget {
  const SgpLawSnapshotOfflineBanner({
    super.key,
    required this.sync,
  });

  final SgpLawOffGridSync sync;

  @override
  Widget build(BuildContext context) {
    if (!sync.isOfflineMode) return const SizedBox.shrink();

    return Semantics(
      label: sync.subtleBannerLabel,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF9FA8DA).withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_moon_outlined,
              size: 16,
              color: Colors.indigo.shade100,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sync.subtleBannerLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
