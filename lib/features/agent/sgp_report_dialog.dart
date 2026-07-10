/// 판례 인용 보고서 — 팝업·클립보드·공유 UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'sgp_app_theme.dart';
import 'sgp_report_generator.dart';

/// 보고서 팝업 표시 + 클립보드 자동 복사.
Future<void> showLegalReportDialog(
  BuildContext context, {
  required SgpLegalReport report,
}) async {
  await Clipboard.setData(ClipboardData(text: report.plainText));

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _LegalReportDialog(report: report),
  );
}

class _LegalReportDialog extends StatefulWidget {
  const _LegalReportDialog({required this.report});

  final SgpLegalReport report;

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      backgroundColor: SgpAppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SgpAppTheme.surfaceHigh, SgpAppTheme.surface],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: SgpAppTheme.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: SgpAppTheme.accent, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '사법 서류 초안',
                              style: TextStyle(
                                color: SgpAppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '클립보드 복사됨 · 판례 ${widget.report.citedPrecedentIds.length}건',
                              style: const TextStyle(color: SgpAppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: SgpAppTheme.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  TabBar(
                    controller: _tabs,
                    labelColor: SgpAppTheme.accent,
                    unselectedLabelColor: SgpAppTheme.textMuted,
                    indicatorColor: SgpAppTheme.primary,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: '초동조치 보고서'),
                      Tab(text: '범죄 발생보고서'),
                      Tab(text: '현행범·긴급체포서'),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyCurrentTab(),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('탭 복사'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareReport(context),
                      icon: const Icon(Icons.share),
                      label: const Text('전체 공유'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          fontFamily: 'monospace',
          color: SgpAppTheme.textPrimary,
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

  Future<void> _shareReport(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await Share.share(
      widget.report.plainText,
      subject: 'SGP-Agent 사법 서류 초안',
      sharePositionOrigin: origin,
    );
  }
}
