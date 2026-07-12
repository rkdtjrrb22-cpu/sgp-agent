/// S11 — 내근 수사 48시간 인치 타임라인 카운트다운 바.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/sgp_procedure_timeline.dart';
import '../agent/sgp_app_theme.dart';
import 'sgp_arrest_timeline_phase.dart';

export 'sgp_arrest_timeline_phase.dart';

/// 지구대 무전 T-0 데이터를 내근 대시보드 48시간 게이지로 표출.
class SgpArrestTimelineBar extends StatefulWidget {
  const SgpArrestTimelineBar({
    super.key,
    required this.timeline,
  });

  final SgpProcedureTimeline timeline;

  @override
  State<SgpArrestTimelineBar> createState() => _SgpArrestTimelineBarState();
}

class _SgpArrestTimelineBarState extends State<SgpArrestTimelineBar> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final neg = d.isNegative;
    final abs = neg ? d.abs() : d;
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60);
    final text = '${h}h ${m.toString().padLeft(2, '0')}m';
    return neg ? '+$text 초과' : text;
  }

  @override
  Widget build(BuildContext context) {
    final t0 = widget.timeline.t0;
    final deadlines = calculateProcedureDeadlines(
      t0: t0,
      arrestType: widget.timeline.arrestType,
    );
    final phase = resolveArrestBarPhase(t0: t0, now: _now);
    final elapsed = _now.difference(t0);
    final remaining48 = deadlines.prosecutorCourtFilingBy.difference(_now);
    final progress = (elapsed.inMinutes / (48 * 60)).clamp(0.0, 1.0);
    final color = _phaseColor(phase);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: phase == ArrestTimelineBarPhase.critical ? 0.45 : 0.2),
            blurRadius: phase == ArrestTimelineBarPhase.critical ? 20 : 10,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            SgpAppTheme.surfaceHigh,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '피의자 인치 48시간 타임라인',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: SgpAppTheme.textPrimary,
                          ),
                    ),
                    Text(
                      'T-0 ${t0.hour.toString().padLeft(2, '0')}:'
                      '${t0.minute.toString().padLeft(2, '0')} · '
                      '${widget.timeline.arrestType.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: SgpAppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  phase.shortPhaseLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: SgpAppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '경과',
                  value: _fmt(elapsed),
                  color: SgpAppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: '48h 잔여',
                  value: _fmt(remaining48),
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: '영장(T+45h)',
                  value: _fmt(deadlines.warrantApplicationBy.difference(_now)),
                  color: const Color(0xFFFFC107),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _phaseLabel(phase),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.35,
            ),
          ),
          if (phase == ArrestTimelineBarPhase.critical) ...[
            const SizedBox(height: 6),
            Text(
              '형소법 제213조의2 — 검사·법원 청구 48시간 시한 임박. '
              '영장 신청서 즉시 검토·112 상황실 연계를 권고합니다.',
              style: TextStyle(
                fontSize: 11,
                color: SgpAppTheme.error,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _phaseColor(ArrestTimelineBarPhase phase) => switch (phase) {
      ArrestTimelineBarPhase.safe => const Color(0xFF4CAF50),
      ArrestTimelineBarPhase.warrantReview => const Color(0xFFFFC107),
      ArrestTimelineBarPhase.critical => const Color(0xFFFF1744),
    };

String _phaseLabel(ArrestTimelineBarPhase phase) => switch (phase) {
      ArrestTimelineBarPhase.safe => '안전 — 영장 신청 여유',
      ArrestTimelineBarPhase.warrantReview => '영장 초안 검토 (T+45h)',
      ArrestTimelineBarPhase.critical => '48시간 시한 임박 — 112 상황실 자동 경보',
    };

extension on ArrestTimelineBarPhase {
  String get shortPhaseLabel => switch (this) {
        ArrestTimelineBarPhase.safe => 'GREEN',
        ArrestTimelineBarPhase.warrantReview => 'YELLOW',
        ArrestTimelineBarPhase.critical => 'RED',
      };
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: SgpAppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SgpAppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: SgpAppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
