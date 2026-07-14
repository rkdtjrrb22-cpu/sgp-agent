/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Civil Non-Intervention Yellow Banner
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
library;

import 'package:flutter/material.dart';

import '../sgp_app_theme.dart';
import '../sgp_civil_non_intervention_filter.dart';

/// 노란색 민사불개입 주의 배너.
class SgpCivilNonInterventionBanner extends StatelessWidget {
  const SgpCivilNonInterventionBanner({
    super.key,
    required this.hit,
  });

  final CivilNonInterventionHit hit;

  @override
  Widget build(BuildContext context) {
    if (!hit.matched) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgpFieldColors.cautionOrange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: SgpFieldColors.cautionOrange,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hit.bannerTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SgpFieldColors.cautionOrange.withValues(alpha: 1),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hit.bannerBody,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF5D4037),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hit.triggers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '감지: ${hit.triggers.take(3).join(" · ")}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Color(0xFF795548),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
