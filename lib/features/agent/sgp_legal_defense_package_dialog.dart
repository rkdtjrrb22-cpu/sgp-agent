/// 사후 소송 대응 — 물리력 보호막 패키지 전용 다이얼로그 (내근·보고서).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sgp_app_theme.dart';
import 'sgp_officer_defense_shield_assembler.dart';

/// 방패 아이콘 클릭 시 — 독직폭행·인권위 등 사후 법적 분쟁 대응 패키지.
Future<void> showLegalDefensePackageDialog(
  BuildContext context, {
  required OfficerDefenseShieldPack pack,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => SgpLegalDefensePackageDialog(pack: pack),
  );
}

class SgpLegalDefensePackageDialog extends StatefulWidget {
  const SgpLegalDefensePackageDialog({
    super.key,
    required this.pack,
  });

  final OfficerDefenseShieldPack pack;

  @override
  State<SgpLegalDefensePackageDialog> createState() =>
      _SgpLegalDefensePackageDialogState();
}

class _SgpLegalDefensePackageDialogState
    extends State<SgpLegalDefensePackageDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  OfficerDefenseShieldPack get pack => widget.pack;

  String _tabMarkdown(int i) => switch (i) {
        0 => '${pack.timelineTableMarkdown}\n\n---\n\n${pack.integrityReportMarkdown}',
        1 => pack.legalDefenseMarkdown,
        _ => '${pack.dutyLiabilityInsuranceMarkdown}\n\n---\n\n${pack.activeAdminExemptionMarkdown}',
      };

  Future<void> _copy(String label, String markdown) async {
    await Clipboard.setData(
      ClipboardData(text: OfficerDefenseShieldPack.stripMarkdown(markdown)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label 클립보드 복사 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1565C0);
    final arrow =
        pack.timelineEntries.map((e) => e.arrowLine).join(' ➔ ');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: SgpAppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.shield, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '물리력 보호막 패키지 (사후 대응)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '사건 종결 후 독직폭행·인권위 진정 등 법적 문제 발생 시에만 사용',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                            if (arrow.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                arrow,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.lightBlue.shade100,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.lightBlueAccent,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(text: '1. CoC 타임라인'),
                      Tab(text: '2. 맞대응 변론서'),
                      Tab(text: '3. 구제 원클릭'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _pane(
                    tip: '사법기관 증빙용 — 저항 단계 연속성 표 + 무결성 보고서',
                    body: _tabMarkdown(0),
                    copyLabel: 'CoC·타임라인',
                  ),
                  _pane(
                    tip: '경직법 제11조의5 · 형법 제20조 부합 변론 요지',
                    body: pack.legalDefenseMarkdown,
                    copyLabel: '변론서',
                  ),
                  _reliefPane(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copy('현재 탭', _tabMarkdown(_tabs.index)),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('탭 복사', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _copy('통합 패키지', pack.combinedMarkdown),
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text(
                        '전체 패키지 복사',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pane({
    required String tip,
    required String body,
    required String copyLabel,
  }) {
    return ColoredBox(
      color: SgpAppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 11,
                color: SgpAppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: SelectableText(
                body,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: SgpAppTheme.textPrimary,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(copyLabel, body),
              icon: const Icon(Icons.copy, size: 16),
              label: Text('$copyLabel 복사'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reliefPane() {
    return ColoredBox(
      color: SgpAppTheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '구제 원클릭 — 로컬 스냅샷으로 양식 자동 완성',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SgpAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _formCard(
              icon: Icons.account_balance_outlined,
              title: '공무 수행 책임보험',
              subtitle: '지방청 청문감사과 연계 신청 가이드',
              onCopy: () => _copy(
                '책임보험 가이드',
                pack.dutyLiabilityInsuranceMarkdown,
              ),
              preview: pack.dutyLiabilityInsuranceMarkdown,
            ),
            const SizedBox(height: 10),
            _formCard(
              icon: Icons.verified_user_outlined,
              title: '적극행정 면책신청서',
              subtitle: '정당 직무·비례성 소명 자동 완성',
              onCopy: () => _copy(
                '면책신청서',
                pack.activeAdminExemptionMarkdown,
              ),
              preview: pack.activeAdminExemptionMarkdown,
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onCopy,
    required String preview,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgpAppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF42A5F5), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: SgpAppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SgpAppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onCopy,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('조립·복사', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preview.split('\n').take(8).join('\n'),
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: SgpAppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
