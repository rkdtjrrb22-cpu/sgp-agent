/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Self-Healing Context Purification Engine
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 *              : [20-Year Veteran Public Order & Security Operations Commander]
 * PATENT NO    : KR 10-2026-0128052 (Asynchronous Context Flush Mechanism)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 글림파틱 실시간 관제 대시보드 — 피로 지표·핑퐁 노드 상태 시각화.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../agent/sgp_agent_core.dart';
import '../../agent/sgp_app_theme.dart';
import '../sgp_glymphatic_agent_node.dart';
import '../sgp_glymphatic_controller.dart';
import '../sgp_glymphatic_handshake.dart';
import '../sgp_glymphatic_innovation_engine.dart';

/// UI 바인딩용 글림파틱 스냅샷.
class GlymphaticDashboardSnapshot {
  const GlymphaticDashboardSnapshot({
    required this.semanticEntropy,
    required this.contextSaturationRatio,
    required this.inferenceLatencyMs,
    required this.activeNodeId,
    required this.mainNodeId,
    required this.shadowNodeId,
    required this.mainState,
    required this.shadowState,
    required this.isFlushInFlight,
    required this.monitorRunning,
    this.readyReport,
    this.lastHealAt,
  });

  final double semanticEntropy;
  final double contextSaturationRatio;
  final double inferenceLatencyMs;
  final String activeNodeId;
  final String mainNodeId;
  final String shadowNodeId;
  final GlymphaticAgentState mainState;
  final GlymphaticAgentState shadowState;
  final bool isFlushInFlight;
  final bool monitorRunning;
  final GlymphaticReadyStateReport? readyReport;
  final DateTime? lastHealAt;

  double get contextSaturationPercent => contextSaturationRatio * 100;

  bool get semanticDanger =>
      semanticEntropy > SgpAgentEngine.glymphaticSemanticThreshold;

  bool get contextDanger =>
      contextSaturationRatio > SgpAgentEngine.glymphaticContextRatioThreshold;

  static GlymphaticDashboardSnapshot capture({
    required SgpAgentEngine engine,
    required SgpGlymphaticController controller,
  }) {
    GlymphaticReadyStateReport? ready = engine.lastGlymphaticReadyReport;
    DateTime? lastHeal;
    if (controller.healLog.isNotEmpty) {
      final last = controller.healLog.last;
      ready ??= last.flushReport.readyState;
      lastHeal = last.timestamp;
    }

    return GlymphaticDashboardSnapshot(
      semanticEntropy: engine.getSemanticEntropy(),
      contextSaturationRatio: engine.getContextTokenSaturation(),
      inferenceLatencyMs: engine.getInferenceLatencyMs(),
      activeNodeId: controller.activeNode.nodeId,
      mainNodeId: controller.mainNode.nodeId,
      shadowNodeId: controller.shadowNode.nodeId,
      mainState: controller.mainNode.state,
      shadowState: controller.shadowNode.state,
      isFlushInFlight:
          controller.isFlushing || engine.isGlymphaticFlushInFlight,
      monitorRunning: engine.isGlymphaticMonitorRunning,
      readyReport: ready,
      lastHealAt: lastHeal,
    );
  }
}

/// 글림파틱 관제 패널 — 엔트로피 게이지·컨텍스트 포화·노드 칩.
class SgpGlymphaticDashboard extends StatelessWidget {
  /// 컴파일 타임 아키텍트·특허 시그니처 (지식재산권 방어용 내장 표식).
  static const String architectSignature =
      SgpGlymphaticInnovationEngine.architectSignature;

  const SgpGlymphaticDashboard({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final GlymphaticDashboardSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: SgpFieldColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: snapshot.semanticDanger || snapshot.contextDanger
              ? SgpFieldColors.criticalRed.withValues(alpha: 0.45)
              : SgpFieldColors.border,
          width: snapshot.semanticDanger || snapshot.contextDanger ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRow(snapshot: snapshot),
          SizedBox(height: compact ? 8 : 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SemanticEntropyGauge(
                value: snapshot.semanticEntropy,
                compact: compact,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ContextSaturationBar(
                      ratio: snapshot.contextSaturationRatio,
                      compact: compact,
                    ),
                    const SizedBox(height: 8),
                    _LatencyRow(
                      latencyMs: snapshot.inferenceLatencyMs,
                      monitorRunning: snapshot.monitorRunning,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          _NodeStatusRow(snapshot: snapshot),
          if (snapshot.readyReport != null) ...[
            const SizedBox(height: 8),
            _ReadyStateBanner(report: snapshot.readyReport!),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.snapshot});

  final GlymphaticDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlymphaticTripleNodeBreather(
          isFlushing: snapshot.isFlushInFlight,
          isMonitorActive: snapshot.monitorRunning,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '글림파틱 자가치유 관제',
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: SgpFieldColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Active  ${snapshot.activeNodeId}',
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: SgpFieldColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 타이틀 좌측 3원 노드 — 호흡 펄스·좌→우 에너지 순환·Flushing 시 가속/회전.
class _GlymphaticTripleNodeBreather extends StatefulWidget {
  const _GlymphaticTripleNodeBreather({
    required this.isFlushing,
    required this.isMonitorActive,
  });

  final bool isFlushing;
  final bool isMonitorActive;

  @override
  State<_GlymphaticTripleNodeBreather> createState() =>
      _GlymphaticTripleNodeBreatherState();
}

class _GlymphaticTripleNodeBreatherState extends State<_GlymphaticTripleNodeBreather>
    with SingleTickerProviderStateMixin {
  static const _nodeDiameters = <double>[6, 9, 12];
  static const _staggerPhase = <double>[0.0, 0.22, 0.44];
  static const _activeBreathMs = 2400;
  static const _flushBreathMs = 620;

  static const _skyBlueActive = Color(0xFF7DD3FC);
  static const _skyBlueCore = Color(0xFF38BDF8);
  static const _flushCyan = Color(0xFF22D3EE);

  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.isFlushing ? _flushBreathMs : _activeBreathMs,
      ),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GlymphaticTripleNodeBreather oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlushing != widget.isFlushing) {
      _breath.duration = Duration(
        milliseconds: widget.isFlushing ? _flushBreathMs : _activeBreathMs,
      );
      if (!_breath.isAnimating) {
        _breath.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Color _nodeColor(int index) {
    if (widget.isFlushing) {
      return index == 1 ? _flushCyan : _skyBlueCore;
    }
    if (widget.isMonitorActive) {
      return index == 1 ? _skyBlueCore : _skyBlueActive;
    }
    return SgpFieldColors.textSecondary.withValues(alpha: 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = _breath.value;
        final spin = widget.isFlushing ? t * math.pi * 1.35 : 0.0;

        return Transform.rotate(
          angle: spin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _nodeDiameters.length; i++) ...[
                if (i > 0) SizedBox(width: i == 1 ? 3 : 4),
                _breathingNode(
                  index: i,
                  t: t,
                  diameter: _nodeDiameters[i],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _breathingNode({
    required int index,
    required double t,
    required double diameter,
  }) {
    final phase = _staggerPhase[index];
    final wave = math.sin((t + phase) * math.pi * 2);
    final scale = widget.isFlushing
        ? 0.78 + (wave + 1) * 0.16
        : 0.84 + (wave + 1) * 0.10;
    final glow = widget.isFlushing
        ? 0.35 + (wave + 1) * 0.32
        : 0.22 + (wave + 1) * 0.20;
    final color = _nodeColor(index);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.55 + glow * 0.35),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: glow.clamp(0.0, 1.0)),
              blurRadius: widget.isFlushing ? 6 + wave * 2 : 4 + wave,
              spreadRadius: widget.isFlushing ? 0.8 : 0.3,
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.65 + glow * 0.2),
            width: widget.isFlushing ? 1.2 : 0.8,
          ),
        ),
      ),
    );
  }
}

class _SemanticEntropyGauge extends StatelessWidget {
  const _SemanticEntropyGauge({
    required this.value,
    required this.compact,
  });

  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final danger = clamped > SgpAgentEngine.glymphaticSemanticThreshold;
    final color = danger ? SgpFieldColors.criticalRed : SgpFieldColors.safeGreen;
    final size = compact ? 64.0 : 78.0;

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: clamped,
                  strokeWidth: compact ? 5 : 6,
                  backgroundColor: SgpFieldColors.border,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clamped.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '엔트로피',
                    style: TextStyle(
                      fontSize: compact ? 8 : 9,
                      color: SgpFieldColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          danger ? '위험 (>0.65)' : '정상',
          style: TextStyle(
            fontSize: 9,
            fontWeight: danger ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ContextSaturationBar extends StatelessWidget {
  const _ContextSaturationBar({
    required this.ratio,
    required this.compact,
  });

  final double ratio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    final percent = (clamped * 100).clamp(0.0, 100.0);
    final danger =
        clamped > SgpAgentEngine.glymphaticContextRatioThreshold;
    final color =
        danger ? SgpFieldColors.cautionOrange : SgpFieldColors.accentBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '컨텍스트 포화',
              style: TextStyle(
                fontSize: 10,
                color: SgpFieldColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: compact ? 6 : 8,
            backgroundColor: SgpFieldColors.border,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Window ${SgpAgentEngine.glymphaticMaxWindowTokens} tok · 임계 75%',
          style: const TextStyle(
            fontSize: 8,
            color: SgpFieldColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LatencyRow extends StatelessWidget {
  const _LatencyRow({
    required this.latencyMs,
    required this.monitorRunning,
  });

  final double latencyMs;
  final bool monitorRunning;

  @override
  Widget build(BuildContext context) {
    final danger =
        latencyMs > SgpAgentEngine.glymphaticLatencyThresholdMs;
    return Row(
      children: [
        Icon(
          monitorRunning ? Icons.sensors : Icons.sensors_off,
          size: 12,
          color: monitorRunning
              ? SgpFieldColors.safeGreen
              : SgpFieldColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '추론 지연 ${latencyMs.round()}ms',
          style: TextStyle(
            fontSize: 10,
            color: danger
                ? SgpFieldColors.criticalRed
                : SgpFieldColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          monitorRunning ? '1s 감시 ON' : '감시 OFF',
          style: TextStyle(
            fontSize: 9,
            color: monitorRunning
                ? SgpFieldColors.safeGreen
                : SgpFieldColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _NodeStatusRow extends StatelessWidget {
  const _NodeStatusRow({required this.snapshot});

  final GlymphaticDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _GlymphaticNodeChip(
          label: 'Main',
          nodeId: snapshot.mainNodeId,
          state: snapshot.mainState,
          isCommanding: snapshot.activeNodeId == snapshot.mainNodeId,
          isFlushInFlight: snapshot.isFlushInFlight,
        ),
        _GlymphaticNodeChip(
          label: 'Shadow',
          nodeId: snapshot.shadowNodeId,
          state: snapshot.shadowState,
          isCommanding: snapshot.activeNodeId == snapshot.shadowNodeId,
          isFlushInFlight: snapshot.isFlushInFlight,
        ),
      ],
    );
  }
}

enum _ChipVisual { active, flushing, ready }

/// 노드 상태 칩 — Active(초록) / Flushing(파랑 애니메이션) / Ready(회색).
class _GlymphaticNodeChip extends StatefulWidget {
  const _GlymphaticNodeChip({
    required this.label,
    required this.nodeId,
    required this.state,
    required this.isCommanding,
    required this.isFlushInFlight,
  });

  final String label;
  final String nodeId;
  final GlymphaticAgentState state;
  final bool isCommanding;
  final bool isFlushInFlight;

  @override
  State<_GlymphaticNodeChip> createState() => _GlymphaticNodeChipState();
}

class _GlymphaticNodeChipState extends State<_GlymphaticNodeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _GlymphaticNodeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (_visual == _ChipVisual.flushing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  _ChipVisual get _visual {
    switch (widget.state) {
      case GlymphaticAgentState.active:
        return _ChipVisual.active;
      case GlymphaticAgentState.flushing:
      case GlymphaticAgentState.sleeping:
        return _ChipVisual.flushing;
      case GlymphaticAgentState.throttled:
        return widget.isCommanding && widget.isFlushInFlight
            ? _ChipVisual.flushing
            : _ChipVisual.ready;
      case GlymphaticAgentState.ready:
      case GlymphaticAgentState.clean:
        return _ChipVisual.ready;
    }
  }

  Color get _color {
    switch (_visual) {
      case _ChipVisual.active:
        return SgpFieldColors.safeGreen;
      case _ChipVisual.flushing:
        return SgpAppTheme.info;
      case _ChipVisual.ready:
        return SgpFieldColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (_visual) {
      case _ChipVisual.active:
        return widget.isCommanding ? 'Active · 지휘중' : 'Active';
      case _ChipVisual.flushing:
        return 'Flushing · 정화중';
      case _ChipVisual.ready:
        return 'Ready · 대기';
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blur = _visual == _ChipVisual.flushing
        ? 2.0 + _pulse.value * 3.0
        : 0.0;
    final opacity = _visual == _ChipVisual.flushing
        ? 0.55 + _pulse.value * 0.35
        : 1.0;

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12 * opacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _color.withValues(alpha: 0.55 + (_visual == _ChipVisual.active ? 0.2 : 0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_visual == _ChipVisual.flushing)
            _PulsingDot(color: _color, size: 7, animation: _pulse)
          else
            Icon(
              _visual == _ChipVisual.active
                  ? Icons.play_circle_filled
                  : Icons.hourglass_empty,
              size: 12,
              color: _color,
            ),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.label} (${widget.nodeId})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              Text(
                _statusLabel,
                style: const TextStyle(
                  fontSize: 8,
                  color: SgpFieldColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (_visual == _ChipVisual.flushing) {
      chip = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur * 0.15,
          sigmaY: blur * 0.15,
        ),
        child: chip,
      );
    }

    return chip;
  }
}

class _ReadyStateBanner extends StatelessWidget {
  const _ReadyStateBanner({required this.report});

  final GlymphaticReadyStateReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SgpFieldColors.safeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SgpFieldColors.safeGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'Clean · ${report.nodeId} Ready '
        '(유지 ${report.retainedFragments} · 소거 ${report.prunedNoiseFragments})',
        style: const TextStyle(
          fontSize: 9,
          color: SgpFieldColors.safeGreen,
        ),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({
    required this.color,
    required this.size,
    this.animation,
  });

  final Color color;
  final double size;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final scale = animation != null
        ? 0.75 + math.sin(animation!.value * math.pi) * 0.35
        : 1.0;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar 하단 컴팩트 관제 스트립 (단일 행, 48px 고정).
class SgpGlymphaticToolbarStrip extends StatelessWidget
    implements PreferredSizeWidget {
  const SgpGlymphaticToolbarStrip({
    super.key,
    required this.snapshot,
  });

  final GlymphaticDashboardSnapshot snapshot;

  static const _stripHeight = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(_stripHeight);

  @override
  Widget build(BuildContext context) {
    final entropy = snapshot.semanticEntropy.clamp(0.0, 1.0);
    final danger = snapshot.semanticDanger;
    final entropyColor =
        danger ? SgpFieldColors.criticalRed : SgpFieldColors.safeGreen;

    return Material(
      color: SgpFieldColors.surfaceHigh,
      child: SizedBox(
        height: _stripHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _GlymphaticTripleNodeBreather(
                isFlushing: snapshot.isFlushInFlight,
                isMonitorActive: snapshot.monitorRunning,
              ),
              const SizedBox(width: 8),
              Text(
                'E ${entropy.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: entropyColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: snapshot.contextSaturationRatio.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: SgpFieldColors.border,
                    color: snapshot.contextDanger
                        ? SgpFieldColors.cautionOrange
                        : SgpFieldColors.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${snapshot.contextSaturationPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: SgpFieldColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.activeNodeId,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: snapshot.isFlushInFlight
                      ? SgpAppTheme.info
                      : SgpFieldColors.safeGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
