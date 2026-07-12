/// S10-UI — KG-RAG 판례 매칭·정당방위 예측 패널 (글래스모피즘).
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../sgp_glass_skin.dart';
import '../sgp_kgrag_router.dart';

abstract final class SgpKgragUiColors {
  static const neonPurple = Color(0xFFE040FB);
  static const neonPurpleGlow = Color(0xFFEA80FC);
  static const realBlack = Color(0xFF000000);
  static const highBadge = Color(0xFF7B1FA2);
}

/// KG-RAG 추론 패널 — 쌍방 폭행 주의 하단 배치.
class SgpKgragReasoningPanel extends StatelessWidget {
  const SgpKgragReasoningPanel({
    super.key,
    this.result,
    this.loading = false,
  });

  final KgragReasoningResult? result;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _KgragSkeletonLoader();
    if (result == null) return const SizedBox.shrink();
    return _KgragResultCard(result: result!);
  }
}

class _KgragResultCard extends StatelessWidget {
  const _KgragResultCard({required this.result});

  final KgragReasoningResult result;

  @override
  Widget build(BuildContext context) {
    final isHigh = result.confidenceLabel == 'High';
    return SgpGlassSkinCard(
      accent: SgpKgragUiColors.neonPurple,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: SgpKgragUiColors.neonPurple, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'KG-RAG 판례 매칭',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SgpKgragUiColors.neonPurpleGlow,
                  ),
                ),
              ),
              if (result.hallucinationGuardPass)
                const Icon(Icons.verified_user, size: 18, color: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 10),
          _GlowBadge(
            label: '유사 판례 ${result.matchedCorpusCount}건 매칭 — '
                '법원 정당방위 인정 확률 ${result.confidenceLabel == 'High' ? '고(High)' : result.confidenceLabel}',
            glow: isHigh,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SgpKgragUiColors.neonPurple.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Text(
              result.recommendedAction,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: SgpKgragUiColors.realBlack,
              ),
            ),
          ),
          if (result.precedentHits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Top 판례 (${(result.selfDefenseProbability * 100).round()}% 정당방위 추정)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SgpKgragUiColors.neonPurple.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            for (final hit in result.precedentHits.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• [${hit.court} ${hit.caseNo}] '
                  '${(hit.similarity * 100).round()}% — ${hit.holding}',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
          if (result.ontologyShield.legalNodeIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final id in result.ontologyShield.legalNodeIds.take(6))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: SgpKgragUiColors.neonPurple.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      id,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GlowBadge extends StatelessWidget {
  const _GlowBadge({required this.label, required this.glow});

  final String label;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            SgpKgragUiColors.neonPurple.withValues(alpha: glow ? 0.35 : 0.2),
            SgpKgragUiColors.highBadge.withValues(alpha: glow ? 0.45 : 0.25),
          ],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: SgpKgragUiColors.neonPurple.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: Border.all(color: SgpKgragUiColors.neonPurple, width: 1.2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
        ),
      ),
    );
  }
}

/// 글래스모피즘 스켈레톤 로딩.
class _KgragSkeletonLoader extends StatefulWidget {
  const _KgragSkeletonLoader();

  @override
  State<_KgragSkeletonLoader> createState() => _KgragSkeletonLoaderState();
}

class _KgragSkeletonLoaderState extends State<_KgragSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity = 0.25 + _ctrl.value * 0.35;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: SgpKgragUiColors.neonPurple.withValues(alpha: 0.5),
                ),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(width: 140, opacity: opacity),
                    const SizedBox(height: 10),
                    _bar(width: double.infinity, height: 36, opacity: opacity),
                    const SizedBox(height: 8),
                    _bar(width: double.infinity, height: 48, opacity: opacity),
                    const SizedBox(height: 8),
                    _bar(width: 200, opacity: opacity),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar({required double width, double height = 12, required double opacity}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: SgpKgragUiColors.neonPurple.withValues(alpha: opacity),
      ),
    );
  }
}
