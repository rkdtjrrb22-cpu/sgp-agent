/// S8-MED — 응급 이송·신병 확보 가이드 (글래스모피즘·시한 카운트다운).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sgp_app_theme.dart';
import '../sgp_civil_complaint_data.dart';
import '../sgp_medical_custody_engine.dart';

/// 응급 이송 가이드 본문 + 시한 인디케이터.
class SgpMedicalTransferGuidePanel extends StatelessWidget {
  const SgpMedicalTransferGuidePanel({
    super.key,
    required this.route,
    required this.session,
    required this.deadline,
    this.onDismiss,
    this.onExpectedDischargeChanged,
  });

  final CivilComplaintRouteResult route;
  final SgpMedicalTransferSession session;
  final MedicalCustodyDeadline deadline;
  final VoidCallback? onDismiss;
  final ValueChanged<DateTime?>? onExpectedDischargeChanged;

  @override
  Widget build(BuildContext context) {
    final type = route.type;
    final accent = deadline.isExpired || deadline.isCritical
        ? const Color(0xFFFF5252)
        : deadline.timelineFrozen
            ? SgpCivilGuideColors.emerald
            : SgpCivilGuideColors.neonCyan;

    return _MedGlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(type),
          const SizedBox(height: 12),
          _CountdownIndicator(deadline: deadline),
          const SizedBox(height: 12),
          if (type.custodyGuideLv7.isNotEmpty) ...[
            _sectionTitle('치료 과정별 신병 확보 (LV7)'),
            const SizedBox(height: 6),
            Text(
              type.custodyGuideLv7,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: SgpCivilGuideColors.pureWhite,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _sectionTitle('LV8 실시간 표기'),
          const SizedBox(height: 6),
          Text(
            deadline.lv8DisplayHint,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          if (deadline.validationWarnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final w in deadline.validationWarnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SgpCivilGuideColors.pureWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (deadline.timelineFrozen) ...[
            const SizedBox(height: 12),
            _ExpectedDischargeField(
              value: session.expectedDischargeAt,
              onChanged: onExpectedDischargeChanged,
            ),
          ],
          if (deadline.flightRisk != MedFlightRiskLevel.normal) ...[
            const SizedBox(height: 10),
            _FlightRiskBadge(level: deadline.flightRisk),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(CivilComplaintType type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.local_hospital, color: Color(0xFFFF5252), size: 28),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🚑 응급이송 및 사법확보',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                type.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.pureWhite,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.branch.displayLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SgpCivilGuideColors.neonCyan,
                ),
              ),
            ],
          ),
        ),
        if (onDismiss != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.close_rounded, color: SgpCivilGuideColors.pureWhite),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SgpCivilGuideColors.neonCyan,
      ),
    );
  }
}

class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.deadline});

  final MedicalCustodyDeadline deadline;

  @override
  Widget build(BuildContext context) {
    final color = deadline.isExpired
        ? const Color(0xFFFF5252)
        : deadline.isCritical
            ? const Color(0xFFFF8A80)
            : deadline.timelineFrozen
                ? SgpCivilGuideColors.emerald
                : SgpCivilGuideColors.neonCyan;

    final headline = deadline.timelineFrozen
        ? '⏱️ 행정관리 모드 — 체포 시한 정지'
        : deadline.isExpired
            ? '🚨 사법 시한 초과'
            : deadline.isCritical
                ? '🚨 사법 시한 카운트다운'
                : '체포 48h 시한 진행 중';

    final detail = deadline.timelineFrozen
        ? '도주 우려 등급 ${_flightLabel(deadline.flightRisk)} · 치료 완료 예정 시각 수기 입력'
        : '잔여 ${deadline.remainingMinutes ?? 0}분 · '
            '마감 ${_fmt(deadline.prosecutorFilingDeadline)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: deadline.isCritical || deadline.isExpired
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SgpCivilGuideColors.pureWhite,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static String _flightLabel(MedFlightRiskLevel l) => switch (l) {
        MedFlightRiskLevel.normal => '보통',
        MedFlightRiskLevel.elevated => '상향',
        MedFlightRiskLevel.critical => '긴급',
      };
}

class _ExpectedDischargeField extends StatelessWidget {
  const _ExpectedDischargeField({
    required this.value,
    this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? '치료 완료 예정 시각 입력 (탭)'
        : '치료 완료 예정: ${_fmt(value!)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now().add(const Duration(hours: 6)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 30)),
          );
          if (date == null || !context.mounted) return;
          if (!context.mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time == null) return;
          onChanged?.call(DateTime(date.year, date.month, date.day, time.hour, time.minute));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SgpCivilGuideColors.emerald),
            color: SgpCivilGuideColors.emerald.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_calendar, color: SgpCivilGuideColors.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SgpCivilGuideColors.pureWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

class _FlightRiskBadge extends StatelessWidget {
  const _FlightRiskBadge({required this.level});

  final MedFlightRiskLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      MedFlightRiskLevel.normal => ('도주 우려: 보통', SgpCivilGuideColors.emerald),
      MedFlightRiskLevel.elevated => ('도주 우려: 상향', const Color(0xFFFFB74D)),
      MedFlightRiskLevel.critical => ('도주 우려: 긴급', const Color(0xFFFF5252)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _MedGlassCard extends StatelessWidget {
  const _MedGlassCard({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.5),
                const Color(0xFFFF5252).withValues(alpha: 0.35),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: SgpCivilGuideColors.glassFill,
              ),
              child: Padding(padding: const EdgeInsets.all(14), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 엄지존 — 응급 이송 원터치 진입.
class SgpMedicalTransferThumbButton extends StatelessWidget {
  const SgpMedicalTransferThumbButton({
    super.key,
    required this.onPressed,
    this.active = false,
  });

  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFFF5252) : SgpCivilGuideColors.neonCyan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 1.5),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14)]
                : null,
          ),
          child: const SizedBox(
            width: double.infinity,
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_hospital, color: Color(0xFFFF5252), size: 26),
                SizedBox(width: 10),
                Text(
                  '🚑 응급이송 및 사법확보',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SgpCivilGuideColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
