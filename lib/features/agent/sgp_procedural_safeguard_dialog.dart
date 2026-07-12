/// 위수증 방어 경고 — 단계별 절차 이행 UI.
library;

import 'package:flutter/material.dart';

import 'sgp_agent_core.dart';
import 'sgp_app_theme.dart';

/// 절차 경고를 실행 가능한 단계로 구조화.
class ProceduralActionStep {
  const ProceduralActionStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.priority,
    this.legalReference,
    this.subSteps = const [],
  });

  final String id;
  final String title;
  final String detail;
  final int priority;
  final String? legalReference;
  final List<String> subSteps;
}

/// 알림 문자열 → 실행 단계 파싱.
List<ProceduralActionStep> parseProceduralSteps(List<String> alerts) {
  final steps = <ProceduralActionStep>[];
  var idx = 0;

  for (final alert in alerts) {
    final clean = alert.replaceAll(RegExp(r'【[^】]+】'), '').trim();
    if (clean.isEmpty) continue;

    var priority = 2;
    String? legalRef;
    final subSteps = <String>[];

    if (alert.contains('임의제출')) {
      priority = 0;
      legalRef = '형소법 제219조 (임의제출)';
      subSteps.addAll([
        '임의제출 동의서 서면 작성·서명·날인',
        '제출 거부권·변호인 참여권 고지',
        '동의 철회 가능 시점 안내',
        '동의서 사본 피의자 교부',
      ]);
    } else if (alert.contains('미란다')) {
      priority = 0;
      legalRef = '헌법 제12조·대법원 (미란다 원칙)';
      subSteps.addAll([
        '묵비권·변호인 조력권 고지 낭독',
        '고지 시각·장소·수사관 성명 기록',
        '고지서 서명 또는 거부 기록',
      ]);
    } else if (alert.contains('위수증')) {
      priority = 1;
      legalRef = '형소법 제308조의2 (위법수집증거 배제)';
      subSteps.addAll([
        '영장 없는 압수·수색 여부 재확인',
        '채증 전 법적 고지·바디캠 가동',
        '압수목록·압수조서 즉시 작성',
        '증거 봉인·연속성(체인 오브 커스터디) 기록',
      ]);
    } else if (alert.contains('영장') || alert.contains('긴급압수')) {
      priority = 1;
      legalRef = '형소법 제119조·제216조';
      subSteps.addAll([
        '영장 범위·대상·시간 대조',
        '긴급압수 시 사후 영장 신청 시한 확인',
        '압수 현장 사진·동영상 촬영',
      ]);
    } else if (alert.contains('분리')) {
      priority = 1;
      legalRef = '가정폭력처벌법·수사 실무';
      subSteps.addAll([
        '피해자·가해자 별실 분리',
        '교차 진술·대질 신문 금지',
        '임시조치·긴급응급조치 통보 검토',
      ]);
    }

    steps.add(
      ProceduralActionStep(
        id: 'step_$idx',
        title: _stepTitle(alert),
        detail: clean,
        priority: priority,
        legalReference: legalRef,
        subSteps: subSteps,
      ),
    );
    idx++;
  }

  steps.sort((a, b) => a.priority.compareTo(b.priority));
  return steps;
}

String _stepTitle(String alert) {
  final match = RegExp(r'【([^】]+)】').firstMatch(alert);
  if (match != null) return match.group(1)!;
  if (alert.contains('임의제출')) return '임의제출 동의';
  if (alert.contains('미란다')) return '미란다 원칙';
  if (alert.contains('위수증')) return '위수증 방어';
  if (alert.contains('영장')) return '영장·압수 절차';
  return '절차 확인';
}

/// 위수증 방어 경고 — 단계별 이행 다이얼로그.
Future<void> showProceduralSafeguardDialog(
  BuildContext context,
  SgpAdvancedAnalysis analysis,
) {
  final critical = analysis.proceduralAlerts.where((a) =>
      a.contains('임의제출') ||
      a.contains('미란다') ||
      a.contains('긴급압수') ||
      a.contains('위수증') ||
      a.contains('영장') ||
      a.contains('분리')).toList();

  return showDialog<void>(
    context: context,
    builder: (ctx) => _ProceduralSafeguardDialog(alerts: critical),
  );
}

class _ProceduralSafeguardDialog extends StatefulWidget {
  const _ProceduralSafeguardDialog({required this.alerts});

  final List<String> alerts;

  @override
  State<_ProceduralSafeguardDialog> createState() => _ProceduralSafeguardDialogState();
}

class _ProceduralSafeguardDialogState extends State<_ProceduralSafeguardDialog> {
  late final List<ProceduralActionStep> _steps;
  final Set<String> _completed = {};

  @override
  void initState() {
    super.initState();
    _steps = parseProceduralSteps(widget.alerts);
  }

  bool get _allCriticalDone {
    final critical = _steps.where((s) => s.priority <= 1);
    if (critical.isEmpty) return _completed.length >= _steps.length;
    return critical.every((s) => _completed.contains(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final hasConsentUrgency = widget.alerts.any((a) => a.contains('임의제출'));

    return AlertDialog(
      icon: Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 40),
      title: const Text(
        '위수증 방어 — 절차 이행 가이드',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasConsentUrgency)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.priority_high, color: Colors.red.shade800, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '즉시 조치 필요',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '영장 없는 디지털 증거 확보 전 임의제출 동의서를 반드시 확보하십시오.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                '아래 단계를 순서대로 이행하고 각 항목을 체크하세요.',
                style: const TextStyle(
                  fontSize: 12,
                  color: SgpFieldColors.fieldGuideBody,
                ),
              ),
              const SizedBox(height: 12),
              ..._steps.map(_buildStepCard),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _steps.isEmpty ? 1 : _completed.length / _steps.length,
                backgroundColor: Colors.grey.shade200,
                color: _allCriticalDone ? Colors.green.shade700 : Colors.orange.shade800,
              ),
              const SizedBox(height: 4),
              Text(
                '${_completed.length}/${_steps.length} 단계 완료',
                style: const TextStyle(
                  fontSize: 11,
                  color: SgpFieldColors.fieldGuideBody,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _allCriticalDone ? () => Navigator.pop(context) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: Text(_allCriticalDone ? '절차 이행 완료' : '필수 단계 미완료'),
        ),
      ],
    );
  }

  Widget _buildStepCard(ProceduralActionStep step) {
    final done = _completed.contains(step.id);
    final color = switch (step.priority) {
      0 => Colors.red.shade700,
      1 => Colors.orange.shade800,
      _ => Colors.blue.shade800,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: done ? 0 : 1,
      color: done ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: done,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _completed.add(step.id);
                } else {
                  _completed.remove(step.id);
                }
              }),
              title: Text(
                step.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: done ? const Color(0xFF1B5E20) : color,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: step.legalReference != null
                  ? Text(
                      step.legalReference!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: SgpFieldColors.fieldGuideBody,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Colors.green.shade700,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                step.detail,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: SgpFieldColors.fieldGuideBody,
                ),
              ),
            ),
            if (step.subSteps.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...step.subSteps.map(
                (sub) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.subdirectory_arrow_right, size: 14, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: SgpFieldColors.fieldGuideBody,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
