/// 판례 인용 보고서 — 팝업·클립보드·공유 UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'sgp_app_theme.dart';
import 'sgp_officer_defense_shield_assembler.dart';
import 'sgp_report_generator.dart';

/// 보고서 팝업 표시 + 클립보드 자동 복사.
Future<void> showLegalReportDialog(
  BuildContext context, {
  required SgpLegalReport report,
  OfficerDefenseShieldPack? defensePack,
  Future<void> Function()? onOpenDefensePackage,
}) async {
  await Clipboard.setData(ClipboardData(text: report.combinedPlainText));

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _LegalReportDialog(
      report: report,
      defensePack: defensePack,
      onOpenDefensePackage: onOpenDefensePackage,
    ),
  );
}

class _LegalReportDialog extends StatefulWidget {
  const _LegalReportDialog({
    required this.report,
    this.defensePack,
    this.onOpenDefensePackage,
  });

  final SgpLegalReport report;
  final OfficerDefenseShieldPack? defensePack;
  final Future<void> Function()? onOpenDefensePackage;

  @override
  State<_LegalReportDialog> createState() => _LegalReportDialogState();
}

class _LegalReportDialogState extends State<_LegalReportDialog>
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

  @override
  Widget build(BuildContext context) {
    final docs = widget.report.officialDocuments;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: SgpAppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SgpAppTheme.surfaceHigh, SgpAppTheme.surface],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: SgpAppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.description_outlined,
                          color: SgpAppTheme.accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '판례 인용 · 사법 서류 초안',
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: SgpAppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '클립보드 복사 완료  ·  판례 ${widget.report.citedPrecedentIds.length}건  ·  '
                              '교열 후 사용',
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: SgpAppTheme.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '사후 물리력 보호막 패키지',
                        icon: Icon(
                          Icons.shield,
                          color: widget.defensePack != null
                              ? const Color(0xFF42A5F5)
                              : SgpAppTheme.textSecondary,
                        ),
                        onPressed: widget.onOpenDefensePackage == null
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onOpenDefensePackage!();
                              },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: SgpAppTheme.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: SgpAppTheme.accent,
                    unselectedLabelColor: SgpAppTheme.textMuted,
                    indicatorColor: SgpAppTheme.primary,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    tabs: const [
                      Tab(text: '1. 초동조치 보고서'),
                      Tab(text: '2. 범죄 발생보고서'),
                      Tab(text: '3. 현행범·긴급체포서'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _docPane(widget.report.markdown),
                  _docPane(docs?.crimeIncidentReport ?? '(생성 데이터 없음)'),
                  _docPane(docs?.arrestWarrantDraft ?? '(생성 데이터 없음)'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _copyCurrentTab,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('탭 복사', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareReport(context),
                      icon: const Icon(Icons.share),
                      label: const Text(
                        '전체 공유',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
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

  Widget _docPane(String text) {
    return ColoredBox(
      color: SgpAppTheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: SelectableText(
          text,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.65,
            letterSpacing: 0.05,
            color: SgpAppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  String _currentTabText() {
    final docs = widget.report.officialDocuments;
    return switch (_tabs.index) {
      1 => docs?.crimeIncidentReport ?? '',
      2 => docs?.arrestWarrantDraft ?? '',
      _ => widget.report.markdown,
    };
  }

  Future<void> _copyCurrentTab() async {
    await Clipboard.setData(ClipboardData(text: _currentTabText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 탭 내용이 클립보드에 복사되었습니다.')),
      );
    }
  }

  /// 보안업무규정 방어 게이트 — 수사자료 외부 전송 전 수사관 확인 필수.
  Future<void> _shareReport(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.security, size: 32),
        title: const Text('수사자료 외부 전송 확인'),
        content: const Text(
          '본 서류에는 수사 관련 정보가 포함되어 있습니다.\n\n'
          '보안업무규정 및 개인정보 보호 원칙에 따라 '
          '승인된 업무 채널(폴넷 메신저 등)로만 전송하십시오.\n\n'
          '외부 메신저·SNS 전송 시 발생하는 책임은 전송자 본인에게 있습니다.',
          style: TextStyle(height: 1.45, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인 후 전송'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await Share.share(
      widget.report.combinedPlainText,
      subject: 'SGP-Agent 사법 서류 초안',
      sharePositionOrigin: origin,
    );
  }
}
