/// SGP-Agent 현장 UI — 원페이지 수사 조서 입력·자기판단 승인.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sgp_agent_core.dart';
import 'sgp_agent_storage.dart';
import 'sgp_agent_stt.dart';
import 'sgp_precedent_dictionary.dart';
import 'sgp_advanced_analysis_widget.dart';
import 'sgp_readable_layout.dart';
import 'sgp_procedure_timeline.dart';
import 'sgp_evidence_notice.dart';
import 'sgp_physical_force_guide.dart';
import 'sgp_procedural_safeguard_dialog.dart';
import 'sgp_report_dialog.dart';
import 'sgp_report_generator.dart';
import 'sgp_quantum_legal_engine.dart';
import 'sgp_court_precedents_ota.dart';
import 'sgp_main_user_interface.dart';
import 'sgp_app_theme.dart';

/// SgpAgentHome — 수사관 진입점. 진입 시 sLLM Lazy Load, 이탈 시 dispose.
class SgpAgentHome extends StatelessWidget {
  const SgpAgentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const SgpAgentScreen();
  }
}

class SgpAgentScreen extends StatefulWidget {
  const SgpAgentScreen({super.key});

  @override
  State<SgpAgentScreen> createState() => _SgpAgentScreenState();
}

class _SgpAgentScreenState extends State<SgpAgentScreen> {
  final _rawTextController = TextEditingController();
  final _engine = SgpAgentEngine();
  final _sttEngine = SgpSttEngine();
  final _scrollController = ScrollController();
  final _storageSectionKey = GlobalKey();

  LawCheckList _checklist = const LawCheckList();
  RuleMatchResult _ruleResult = const RuleMatchResult(
    triggeredFilters: [],
    suggestedChecklist: LawCheckList(),
  );
  Timer? _ruleDebounce;
  bool _selfJudgmentAccepted = false;
  bool _modelLoading = true;
  bool _inferring = false;
  String? _generatedOutput;
  SgpAdvancedAnalysis? _advancedAnalysis;
  String? _statusMessage;
  String? _storagePathLabel;
  List<SavedRecordSummary> _savedRecords = [];
  SavedRecordSummary? _lastSavedRecord;
  bool _loadingRecords = true;
  SttSessionState _sttState = SttSessionState.idle;
  bool _sttBusy = false;
  String _sttSourceLabel = 'STT 초기화 중…';
  SgpProcedureTimeline? _procedureTimeline;
  SgpQuantumLegalComparison? _quantumComparison;
  String? _otaStatus;

  static const _liabilityNotice =
      '최종 체포 결정 및 사법 절차적 모든 법적 책임은 '
      '출동 수사관 본인의 주체적인 판단에 의한다.';

  @override
  void initState() {
    super.initState();
    _rawTextController.addListener(_onRawTextChanged);
    _initEngine();
    _loadPrecedentDictionary();
    _initCourtPrecedentsOta();
    _initStt();
    _refreshSavedRecords();
  }

  Future<void> _initStt() async {
    await _sttEngine.initialize();
    if (!mounted) return;
    setState(() {
      _sttSourceLabel = _sttEngine.canTranscribe
          ? _sttEngine.inputSourceLabel
          : (_sttEngine.lastError ?? 'STT 사용 불가 — 수동 입력');
    });
  }

  Future<void> _initCourtPrecedentsOta() async {
    await SgpCourtPrecedentsOta.instance.initialize();
    if (!mounted) return;
    setState(() => _otaStatus = SgpCourtPrecedentsOta.instance.lastRefreshStatus);
  }

  void _refreshQuantumAnalysis() {
    final text = _rawTextController.text.trim();
    if (text.isEmpty) {
      if (_quantumComparison != null) {
        setState(() => _quantumComparison = null);
      }
      return;
    }
    final comparison = SgpQuantumLegalEngine.analyze(
      rawText: text,
      checklist: _checklist,
      ruleResult: _ruleResult,
      advancedAnalysis: _advancedAnalysis,
      timeline: _procedureTimeline,
    );
    setState(() => _quantumComparison = comparison);
  }

  bool get _canGenerateReport =>
      _rawTextController.text.trim().isNotEmpty &&
      (_advancedAnalysis != null || _procedureTimeline != null);

  Future<void> _loadPrecedentDictionary() async {
    try {
      final json = await rootBundle.loadString('assets/data/precedent_dictionary.json');
      setPrecedentDictionaryFromJson(json);
    } catch (_) {
      // 폴백: sgp_precedent_dictionary.dart 내장 JSON 사용
    }
  }

  void _onRawTextChanged() {
    _ruleDebounce?.cancel();
    _ruleDebounce = Timer(const Duration(milliseconds: 400), _applyRuleMapping);
  }

  void _applyRuleMapping() {
    final rules = matchLawFilters(_rawTextController.text);
    if (!mounted) return;
    setState(() {
      _ruleResult = rules;
      _checklist = mergeChecklists(_checklist, rules.suggestedChecklist);
    });
    _refreshQuantumAnalysis();
  }

  Future<void> _refreshSavedRecords() async {
    try {
      final pathLabel = await getAgentStoragePathLabel();
      final records = await listSavedRecords();
      if (mounted) {
        setState(() {
          _storagePathLabel = pathLabel;
          _savedRecords = records;
          _loadingRecords = false;
          if (_lastSavedRecord != null &&
              !records.any((r) => r.filePath == _lastSavedRecord!.filePath)) {
            _lastSavedRecord = records.isNotEmpty ? records.first : null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRecords = false);
      }
    }
  }

  Future<bool> _confirmDeleteDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: SgpAppTheme.error, size: 32),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SgpAppTheme.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteRecord(SavedRecordSummary record) async {
    final ok = await _confirmDeleteDialog(
      title: '저장 기록 삭제',
      message: '${record.fileName}\n\n이 조서를 단말에서 영구 삭제합니다.',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;

    try {
      await deleteAgentRecord(record.filePath);
      await _refreshSavedRecords();
      if (mounted) {
        _showSnack('삭제됨: ${record.fileName}');
      }
    } catch (e) {
      if (mounted) _showSnack('삭제 실패: $e');
    }
  }

  Future<void> _deleteAllRecords() async {
    if (_savedRecords.isEmpty) return;

    final ok = await _confirmDeleteDialog(
      title: '전체 기록 삭제',
      message: '저장된 조서 ${_savedRecords.length}건을 모두 삭제합니다.\n'
          '복구할 수 없습니다.',
      confirmLabel: '전체 삭제',
    );
    if (!ok || !mounted) return;

    try {
      final count = await deleteAllAgentRecords();
      await _refreshSavedRecords();
      if (mounted) {
        setState(() => _lastSavedRecord = null);
        _showSnack('$count건 삭제 완료');
      }
    } catch (e) {
      if (mounted) _showSnack('삭제 실패: $e');
    }
  }

  Future<void> _loadRecordIntoForm(SavedRecordSummary summary) async {
    final record = await loadAgentRecord(summary.filePath);
    if (!mounted || record == null) {
      _showSnack('파일을 읽을 수 없습니다.');
      return;
    }

    setState(() {
      _rawTextController.text = record.rawText;
      _checklist = record.checklist;
      _generatedOutput = record.output;
      _selfJudgmentAccepted = false;
      _ruleResult = matchLawFilters(record.rawText);
      _advancedAnalysis = record.advancedAnalysis == null
          ? null
          : SgpAdvancedAnalysis.fromJson(record.advancedAnalysis!);
      _procedureTimeline = procedureTimelineFromJson(record.procedureTimeline);
      _quantumComparison = record.quantumLegalAnalysis == null
          ? null
          : SgpQuantumLegalComparison.fromJson(record.quantumLegalAnalysis!);
    });

    _showSnack('기록 불러옴 — 자기판단 확인 후 재확정 필요');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _copyToClipboard(String text, {required String label}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showSnack('$label 복사됨');
    }
  }

  void _scrollToStorageSection() {
    final context = _storageSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _startSttCapture() async {
    if (_sttBusy) return;
    setState(() {
      _sttBusy = true;
      _sttState = SttSessionState.listening;
    });

    try {
      final result = await _sttEngine.transcribeFromMic();
      if (!mounted) return;

      if (result.text.trim().isEmpty) {
        setState(() {
          _sttState = SttSessionState.idle;
          _sttBusy = false;
        });
        _showSnack('인식된 음성이 없습니다. 마이크에 가까이 대고 다시 시도하세요.');
        return;
      }
      final existing = _rawTextController.text.trim();
      final merged = existing.isEmpty
          ? result.text
          : '$existing\n${result.text}';
      _rawTextController.text = merged;
      _applyRuleMapping();

      setState(() {
        _sttState = SttSessionState.idle;
        _sttBusy = false;
      });
      _showSnack(
        result.offline
            ? '온디바이스 STT 입력 완료 (오프라인)'
            : 'STT 입력 완료',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _sttState = SttSessionState.error;
          _sttBusy = false;
        });
        _showSnack('STT 오류: $e');
      }
    }
  }

  Future<void> _initEngine() async {
    try {
      await _engine.loadModel();
      if (mounted) {
        setState(() {
          _modelLoading = false;
          _statusMessage = '온디바이스 모델 적재 완료 (오프라인 추론 가능)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelLoading = false;
          _statusMessage = '모델 적재 실패: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _ruleDebounce?.cancel();
    _engine.dispose();
    _sttEngine.dispose();
    _rawTextController.removeListener(_onRawTextChanged);
    _rawTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeSuggestArrestTimeline(LawCheckList checklist) {
    if (_procedureTimeline != null) return;
    final type = detectArrestType(
      rawText: _rawTextController.text,
      checklist: checklist,
    );
    if (type == null) return;
    _showSnack('체포 정황 감지 — 하단 「체포 확정」으로 타임라인을 시작하세요.');
  }

  Future<void> _confirmArrestTimeline() async {
    final suggested = detectArrestType(
          rawText: _rawTextController.text,
          checklist: _checklist,
        ) ??
        ArrestType.currentOffender;

    final timeline = await showArrestConfirmDialog(
      context,
      suggestedType: suggested,
    );
    if (timeline != null && mounted) {
      setState(() => _procedureTimeline = timeline);
      _showSnack('T-0 기준 사법 절차 타임라인이 시작되었습니다.');
    }
  }

  void _onTimelineCheckChanged(String nodeId, String checkId, bool value) {
    if (_procedureTimeline == null) return;
    setState(() {
      _procedureTimeline = _procedureTimeline!.toggleCheck(nodeId, checkId, value);
    });
    _refreshQuantumAnalysis();
  }

  void _onThreatLevelChanged(PhysicalThreatLevel level) {
    if (_procedureTimeline == null) return;
    setState(() {
      _procedureTimeline = _procedureTimeline!.copyWith(physicalThreatLevel: level);
    });
  }

  Future<void> _onStartEvidenceNotice() async {
    final offenseHint = _rawTextController.text;
    final completed = await showEvidenceNoticeDialog(context, offenseHint: offenseHint);
    if (completed == true && mounted && _procedureTimeline != null) {
      setState(() {
        _procedureTimeline = _procedureTimeline!
            .toggleCheck('evidence_notice', 'evidence_legal_notice', true);
      });
      _showSnack('채증 법적 고지가 기록되었습니다. 녹화 개시 시각을 기재하세요.');
    }
  }

  Future<void> _onGenerateLegalReport() async {
    final input = SgpReportInput(
      rawText: _rawTextController.text,
      checklist: _checklist,
      generatedAt: DateTime.now(),
      advancedAnalysis: _advancedAnalysis,
      timeline: _procedureTimeline,
      quantumComparison: _quantumComparison,
    );
    final report = SgpReportGenerator.generate(input);
    await showLegalReportDialog(context, report: report);
    if (mounted && _procedureTimeline != null) {
      setState(() {
        _procedureTimeline = _procedureTimeline!
            .toggleCheck(kLegalReportNodeId, 'report_generated', true);
      });
      _showSnack('초동조치 보고서가 생성·복사되었습니다.');
    }
  }

  void _showProceduralAlert(SgpAdvancedAnalysis analysis) {
    showProceduralSafeguardDialog(context, analysis);
  }

  Future<void> _runInference() async {
    final rawText = _rawTextController.text;
    if (rawText.trim().isEmpty) {
      _showSnack('무전 STT 텍스트를 입력하세요.');
      return;
    }

    setState(() {
      _inferring = true;
      _generatedOutput = null;
      _advancedAnalysis = null;
    });

    try {
      final pipeline = await _engine.runPipeline(
        rawText: rawText,
        checklist: _checklist,
      );
      if (mounted) {
        setState(() {
          _ruleResult = pipeline.ruleResult;
          _checklist = pipeline.mergedChecklist;
          _generatedOutput = pipeline.output;
          _advancedAnalysis = pipeline.advancedAnalysis;
          _inferring = false;
        });
        _refreshQuantumAnalysis();
        if (pipeline.advancedAnalysis.hasCriticalProceduralAlert) {
          _showProceduralAlert(pipeline.advancedAnalysis);
        }
        _maybeSuggestArrestTimeline(pipeline.mergedChecklist);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inferring = false);
        _showSnack('추론 오류: $e');
      }
    }
  }

  Future<void> _confirmAndSave() async {
    if (!_selfJudgmentAccepted) {
      _showSnack('자기판단 고지를 확인하고 체크해 주세요.');
      return;
    }

    final rawText = _rawTextController.text.trim();
    if (rawText.isEmpty) {
      _showSnack('저장할 무전 텍스트가 없습니다.');
      return;
    }

    final rules = matchLawFilters(rawText);
    final merged = mergeChecklists(_checklist, rules.suggestedChecklist);
    final advanced = runAdvancedAnalysis(
      rawText: rawText,
      checklist: merged,
      ruleResult: rules,
    );
    final pipeline = _generatedOutput != null
        ? InferencePipelineResult(
            ruleResult: rules,
            mergedChecklist: merged,
            prompt: buildPipelinePrompt(
              rawText: rawText,
              checklist: merged,
              ruleResult: rules,
            ),
            output: _generatedOutput!,
            advancedAnalysis: advanced,
          )
        : await _engine.runPipeline(rawText: rawText, checklist: _checklist);

    final record = AgentRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      rawText: rawText,
      checklist: pipeline.mergedChecklist,
      prompt: pipeline.prompt,
      output: pipeline.output,
      selfJudgmentConfirmed: true,
      advancedAnalysis: pipeline.advancedAnalysis.toJson(),
      procedureTimeline: _procedureTimeline == null
          ? null
          : procedureTimelineToJson(_procedureTimeline!),
      quantumLegalAnalysis: _quantumComparison?.toJson(),
    );

    try {
      final file = await saveAgentRecord(record);
      final summary = SavedRecordSummary.fromFile(file);

      await _refreshSavedRecords();

      if (mounted) {
        setState(() => _lastSavedRecord = summary);
        _showSaveSuccessSheet(summary);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToStorageSection();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack('저장 실패: $e');
      }
    }
  }

  void _showSaveSuccessSheet(SavedRecordSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: SgpAppTheme.success, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '서류 확정 · 로컬 저장 완료',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _pathInfoTile(
              label: '파일명',
              value: summary.fileName,
              onCopy: () => _copyToClipboard(summary.fileName, label: '파일명'),
            ),
            const SizedBox(height: 10),
            _pathInfoTile(
              label: '저장 경로',
              value: summary.displayPath,
              onCopy: () => _copyToClipboard(summary.filePath, label: '저장 경로'),
            ),
            const SizedBox(height: 10),
            _pathInfoTile(
              label: '저장 시각',
              value: formatRecordTimestamp(summary.createdAt),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRecordDetail(summary);
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('내용 보기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check),
                    label: const Text('확인'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SgpAppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordDetail(SavedRecordSummary summary) async {
    final record = await loadAgentRecord(summary.filePath);
    if (!mounted || record == null) {
      _showSnack('파일을 읽을 수 없습니다.');
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: SgpAppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                summary.fileName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                summary.filePath,
                style: const TextStyle(fontSize: 12, color: SgpAppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              _detailSection('무전 STT 원문', record.rawText),
              _detailSection('정형화 결과', record.output),
              _detailSection(
                '법리 체크',
                '흉기·위험물: ${record.checklist.isWeaponUsed ? "Y" : "N"}\n'
                    '가정폭력·스토킹: ${record.checklist.isDomesticViolence ? "Y" : "N"}\n'
                    '자의적 음주·약물: ${record.checklist.isIntoxicated ? "Y" : "N"}\n'
                    '도주·신분확인 거부: ${record.checklist.isFleeing ? "Y" : "N"}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadRecordIntoForm(summary);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('화면에 불러오기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(
                        summary.filePath,
                        label: '저장 경로',
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('경로 복사'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteRecord(summary);
                },
                icon: Icon(Icons.delete_outline, color: SgpAppTheme.error),
                label: Text(
                  '이 기록 삭제',
                  style: TextStyle(color: SgpAppTheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: SgpAppTheme.error.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SgpAppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(body, style: const TextStyle(fontSize: 13, height: 1.45)),
          ),
        ],
      ),
    );
  }

  Widget _pathInfoTile({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgpAppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SgpAppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SgpAppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (onCopy != null)
                InkWell(
                  onTap: onCopy,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: SgpAppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '복사',
                        style: TextStyle(fontSize: 12, color: SgpAppTheme.accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgpFieldColors.background,
      appBar: AppBar(
        title: const Text('SGP-Agent'),
        actions: [
          IconButton(
            tooltip: '저장 기록',
            icon: Badge(
              isLabelVisible: _savedRecords.isNotEmpty,
              label: Text('${_savedRecords.length}'),
              child: const Icon(Icons.folder_open),
            ),
            onPressed: _scrollToStorageSection,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_modelLoading)
                    const LinearProgressIndicator(minHeight: 3),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SgpAppTheme.textMuted,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SgpBluetoothStatusBar(
                    sttEngine: _sttEngine,
                    sttState: _sttState,
                    otaStatus: _otaStatus,
                  ),
                  const SizedBox(height: 12),
                  _buildSttField(),
                  if (_quantumComparison != null) ...[
                    const SizedBox(height: 12),
                    SgpFieldCard(
                      child: SgpQuantumComparisonPanel(
                        comparison: _quantumComparison!,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SgpActionGuidanceBar(
                      guidance: _quantumComparison!.actionGuidance,
                      urgency: _quantumComparison!.urgencyLevel,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildRuleMappingSection(),
                  const SizedBox(height: 16),
                  _buildChecklistSection(),
                  const SizedBox(height: 16),
                  _buildInferenceSection(),
                  _buildArrestTimelineSection(),
                  if (_generatedOutput != null) ...[
                    const SizedBox(height: 16),
                    _buildOutputPreview(),
                  ],
                  if (_advancedAnalysis != null) ...[
                    const SizedBox(height: 16),
                    AdvancedAnalysisWidget(
                      analysis: _advancedAnalysis!,
                      onProceduralTap: () => _showProceduralAlert(_advancedAnalysis!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildStorageSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_procedureTimeline != null)
            Flexible(
              child: SgpTimelineWidget(
                timeline: _procedureTimeline!,
                onCheckChanged: _onTimelineCheckChanged,
                onDismiss: () => setState(() => _procedureTimeline = null),
                maxHeight: 340,
                physicalThreatLevel: _procedureTimeline!.physicalThreatLevel,
                onThreatLevelChanged: _onThreatLevelChanged,
                onStartEvidenceNotice: _onStartEvidenceNotice,
                onGenerateReport: _onGenerateLegalReport,
              ),
            ),
          _buildLiabilityPanel(),
          if (_canGenerateReport)
            SgpLifecycleFooter(
              selfJudgmentAccepted: _selfJudgmentAccepted,
              onSelfJudgmentChanged: (v) => setState(() => _selfJudgmentAccepted = v),
              canGenerateReport: _canGenerateReport,
              onGenerateReport: _onGenerateLegalReport,
            ),
        ],
      ),
    );
  }

  Widget _buildSttField() {
    final isListening = _sttState == SttSessionState.listening;
    final isProcessing = _sttState == SttSessionState.processing;
    final accent = isListening ? SgpAppTheme.cotAggressor : SgpAppTheme.accent;

    return SgpFieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isListening ? Icons.settings_voice : Icons.mic,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '무전 STT 원문',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              if (_sttBusy)
                Text(
                  sttStateLabel(_sttState),
                  style: const TextStyle(
                    fontSize: 11,
                    color: SgpCotColors.caution,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rawTextController,
            maxLines: 6,
            minLines: 4,
            style: const TextStyle(
              color: SgpAppTheme.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
            cursorColor: SgpAppTheme.primaryLight,
            decoration: InputDecoration(
              hintText: '현장 무전·진술 텍스트를 입력하거나 마이크로 수신…',
              hintStyle: TextStyle(color: SgpAppTheme.textMuted),
              filled: true,
              fillColor: SgpAppTheme.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SgpCotColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _sttBusy ? null : _startSttCapture,
              icon: isListening || isProcessing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(Icons.mic_none, color: accent),
              label: Text(
                isListening
                    ? '수신 중… 말씀하세요'
                    : isProcessing
                        ? '변환 중…'
                        : _sttEngine.canTranscribe
                            ? '마이크 STT 수신'
                            : 'STT 준비 안 됨',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isListening
                    ? accent.withValues(alpha: 0.15)
                    : SgpCotColors.brand.withValues(alpha: 0.2),
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _sttSourceLabel,
            style: TextStyle(
              fontSize: 11,
              color: _sttEngine.canTranscribe ? SgpCotColors.neon : SgpCotColors.onDark,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '법리 변수 (4대 체크)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _checkCard(
          title: '흉기·위험물 사용',
          subtitle: '특수죄 구성요건 · 반의사불벌죄 배제 가이드',
          value: _checklist.isWeaponUsed,
          suggestedByRule: isFieldSuggestedByRule(_ruleResult, LawChecklistField.weapon),
          onChanged: (v) => setState(
            () => _checklist = _checklist.copyWith(isWeaponUsed: v),
          ),
          icon: Icons.gavel,
        ),
        _checkCard(
          title: '가정폭력·스토킹 관계',
          subtitle: '스토킹/가정폭력처벌법 관계성 필터',
          value: _checklist.isDomesticViolence,
          suggestedByRule: isFieldSuggestedByRule(_ruleResult, LawChecklistField.relational),
          onChanged: (v) => setState(
            () => _checklist = _checklist.copyWith(isDomesticViolence: v),
          ),
          icon: Icons.shield,
        ),
        _checkCard(
          title: '자의적 음주·약물',
          subtitle: '형법 제10조 3항 자의행위 매핑',
          value: _checklist.isIntoxicated,
          suggestedByRule: isFieldSuggestedByRule(_ruleResult, LawChecklistField.intoxication),
          onChanged: (v) => setState(
            () => _checklist = _checklist.copyWith(isIntoxicated: v),
          ),
          icon: Icons.warning_amber,
        ),
        _checkCard(
          title: '도주·신분확인 거부',
          subtitle: '형소법 제211조 체포 필요성',
          value: _checklist.isFleeing,
          suggestedByRule: isFieldSuggestedByRule(_ruleResult, LawChecklistField.fleeing),
          onChanged: (v) => setState(
            () => _checklist = _checklist.copyWith(isFleeing: v),
          ),
          icon: Icons.directions_run,
        ),
      ],
    );
  }

  Widget _buildRuleMappingSection() {
    final triggered = _ruleResult.triggeredFilters;
    return Card(
      elevation: 0,
      color: triggered.isEmpty
          ? SgpAppTheme.surface
          : SgpAppTheme.warning.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: triggered.isEmpty ? SgpAppTheme.border : SgpAppTheme.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rule_folder_outlined,
                  size: 20,
                  color: triggered.isEmpty
                      ? SgpAppTheme.textMuted
                      : SgpAppTheme.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  '1단계: 규칙 기반 법리 매핑',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              triggered.isEmpty
                  ? '무전 텍스트 입력 시 키워드·관계성을 자동 분석합니다.'
                  : '${triggered.length}개 필터 트리거 — 아래 체크박스에 AI 추천 표시',
              style: const TextStyle(fontSize: 12, color: SgpAppTheme.textSecondary),
            ),
            if (triggered.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...triggered.map((t) {
                final law = t.definition.mappingLaw['primary'] ??
                    t.definition.mappingLaw['domestic'] ??
                    t.definition.mappingLaw.values.first;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SgpAppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SgpAppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.definition.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: SgpAppTheme.warning,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '감지 키워드',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ReadableKeywordWrap(
                        keywords: t.matchedKeywords,
                        color: SgpAppTheme.warning,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '적용 법리',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ReadableNarrativeBlock(
                        text: law,
                        fontSize: 12,
                        backgroundColor: SgpAppTheme.surfaceOverlay,
                        textColor: SgpAppTheme.textPrimary,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkCard({
    required String title,
    required String subtitle,
    required bool value,
    required bool suggestedByRule,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: suggestedByRule
            ? BorderSide(color: SgpAppTheme.warning.withValues(alpha: 0.6), width: 1.5)
            : BorderSide(color: SgpAppTheme.border),
      ),
      color: suggestedByRule
          ? SgpAppTheme.warning.withValues(alpha: 0.08)
          : SgpAppTheme.surface,
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        secondary: Icon(icon, color: SgpAppTheme.primaryLight),
        title: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (suggestedByRule)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SgpAppTheme.warning,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AI 추천',
                  style: TextStyle(color: SgpAppTheme.textOnAccent, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: splitReadableSentences(subtitle)
              .map((line) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(line, style: const TextStyle(fontSize: 12, height: 1.35)),
                  ))
              .toList(),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildArrestTimelineSection() {
    final detected = detectArrestType(
      rawText: _rawTextController.text,
      checklist: _checklist,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: SgpAppTheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  '실시간 사법 타임테이블',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detected != null
                  ? 'AI 감지: ${detected.displayName} — 체포 확정 시 T-0부터 시한 자동 계산'
                  : '체포·구속 시 형소법 마감 시한(24h·45h·10일) 실시간 관리',
              style: TextStyle(fontSize: 11, color: SgpAppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _confirmArrestTimeline,
              icon: const Icon(Icons.gavel),
              label: Text(
                _procedureTimeline != null ? '체포 시각·방식 재설정' : '체포 확정 — 타임라인 시작',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: SgpAppTheme.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInferenceSection() {
    return FilledButton.icon(
      onPressed: (_modelLoading || _inferring) ? null : _runInference,
      icon: _inferring
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(_inferring ? '2·3단계 추론 중...' : '2·3단계: 법리 추론 (CoT)'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildOutputPreview() {
    return Card(
      color: SgpAppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: SgpAppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ReadableSectionHeader(
              title: '정형화 결과\n(단계별 요약)',
              icon: Icons.fact_check_outlined,
              color: SgpAppTheme.accent,
            ),
            const SizedBox(height: 10),
            StructuredOutputView(
              rawOutput: _generatedOutput!,
              advancedAnalysis: _advancedAnalysis,
              proAnalysisAtBottom: _advancedAnalysis != null,
              onProceduralTap: _advancedAnalysis != null
                  ? () => _showProceduralAlert(_advancedAnalysis!)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSection() {
    return Card(
      key: _storageSectionKey,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sd_storage, color: SgpAppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '로컬 저장 기록',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (!_loadingRecords && _savedRecords.isNotEmpty)
                  TextButton.icon(
                    onPressed: _deleteAllRecords,
                    icon: Icon(Icons.delete_sweep, size: 18, color: SgpAppTheme.error),
                    label: Text(
                      '전체 삭제',
                      style: TextStyle(fontSize: 12, color: SgpAppTheme.error),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (!_loadingRecords) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${_savedRecords.length}건',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SgpAppTheme.accent,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SgpAppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SgpAppTheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '기본 저장 폴더',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_storagePathLabel != null)
                        InkWell(
                          onTap: () => _copyToClipboard(
                            _storagePathLabel!,
                            label: '저장 폴더',
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 14, color: SgpAppTheme.accent),
                              const SizedBox(width: 4),
                              Text(
                                '복사',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SgpAppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _storagePathLabel ?? '경로 불러오는 중…',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '패키지: com.sgp.sgp_agent · 파일 형식: sgp_agent_<ID>.json',
                    style: const TextStyle(fontSize: 11, color: SgpAppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (_lastSavedRecord != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SgpAppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SgpAppTheme.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: SgpAppTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '최근 저장: ${_lastSavedRecord!.fileName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: SgpAppTheme.success,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _lastSavedRecord!.displayPath,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: SgpAppTheme.success.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loadingRecords)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else if (_savedRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '아직 저장된 서류가 없습니다.\n'
                  '하단 「자기판단 선택 및 서류 확정」 후 이곳에 기록됩니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: SgpAppTheme.textMuted, height: 1.5),
                ),
              )
            else
              ..._savedRecords.map(_buildRecordListTile),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordListTile(SavedRecordSummary record) {
    return Dismissible(
      key: ValueKey(record.filePath),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: SgpAppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(height: 4),
            Text('삭제', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final ok = await _confirmDeleteDialog(
          title: '저장 기록 삭제',
          message: '${record.fileName}\n\n이 조서를 단말에서 영구 삭제합니다.',
          confirmLabel: '삭제',
        );
        if (!ok) return false;
        try {
          await deleteAgentRecord(record.filePath);
          await _refreshSavedRecords();
          if (mounted) _showSnack('삭제됨: ${record.fileName}');
          return true;
        } catch (e) {
          if (mounted) _showSnack('삭제 실패: $e');
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: SgpAppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SgpAppTheme.border),
        ),
        child: InkWell(
          onTap: () => _showRecordDetail(record),
          onLongPress: () => _loadRecordIntoForm(record),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 18, color: SgpAppTheme.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '불러오기',
                      icon: Icon(Icons.upload_file, size: 20, color: SgpAppTheme.primaryLight),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _loadRecordIntoForm(record),
                    ),
                    IconButton(
                      tooltip: '삭제',
                      icon: Icon(Icons.delete_outline, size: 20, color: SgpAppTheme.error),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _deleteRecord(record),
                    ),
                  ],
                ),
                Text(
                  formatRecordTimestamp(record.createdAt),
                  style: const TextStyle(fontSize: 11, color: SgpAppTheme.textMuted),
                ),
                if (record.rawTextPreview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.rawTextPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: SgpAppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                SelectableText(
                  record.displayPath,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: SgpAppTheme.textMuted,
                  ),
                ),
                Text(
                  '탭: 상세 · 길게 누르기: 불러오기 · ← 스와이프: 삭제',
                  style: const TextStyle(fontSize: 10, color: SgpAppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiabilityPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SgpAppTheme.surfaceHigh,
        border: Border(
          top: BorderSide(color: SgpAppTheme.error.withValues(alpha: 0.5), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_outlined, color: SgpAppTheme.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _liabilityNotice,
                  style: const TextStyle(
                    color: SgpAppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _selfJudgmentAccepted ? _confirmAndSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: SgpAppTheme.primary,
              disabledBackgroundColor: SgpAppTheme.surfaceOverlay,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '자기판단 선택 및 서류 확정',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
