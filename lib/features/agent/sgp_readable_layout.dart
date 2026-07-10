/// 현장 가독성 — 문장·줄·키워드 단위 UI 레이아웃.
library;

import 'package:flutter/material.dart';

import 'sgp_agent_core.dart';
import 'sgp_app_theme.dart';
List<String> splitReadableSentences(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return [];

  final parts = normalized
      .split(RegExp(r'(?<=[.!?。])\s+|(?<=다\.)\s+|(?<=요\.)\s+|(?<=음\.)\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (parts.length <= 1 && normalized.length > 42) {
    return _chunkByLength(normalized, 42);
  }
  return parts;
}

List<String> _chunkByLength(String text, int maxLen) {
  final words = text.split(' ');
  final lines = <String>[];
  var buf = StringBuffer();

  for (final word in words) {
    final next = buf.isEmpty ? word : '${buf.toString()} $word';
    if (next.length > maxLen && buf.isNotEmpty) {
      lines.add(buf.toString().trim());
      buf = StringBuffer(word);
    } else {
      buf.write(buf.isEmpty ? word : ' $word');
    }
  }
  if (buf.isNotEmpty) lines.add(buf.toString().trim());
  return lines;
}

/// 마크다운형 출력(■ 제목, - 항목) 파싱.
class ReadableOutputSection {
  const ReadableOutputSection({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;
}

List<ReadableOutputSection> parseStructuredOutput(String raw) {
  final sections = <ReadableOutputSection>[];
  final blocks = raw.split(RegExp(r'(?=■\s)'));

  for (final block in blocks) {
    final trimmed = block.trim();
    if (trimmed.isEmpty) continue;

    final lines = trimmed.split('\n');
    var title = lines.first.trim();
    if (title.startsWith('■')) {
      title = title.replaceFirst('■', '').trim();
    }

    final body = <String>[];
    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('-')) line = line.replaceFirst(RegExp(r'^-\s*'), '');
      if (line.startsWith('[') && line.endsWith(']')) continue;
      body.add(line);
    }

    sections.add(ReadableOutputSection(title: title, lines: body));
  }

  return sections;
}

/// 섹션 제목 라벨.
class ReadableSectionHeader extends StatelessWidget {
  const ReadableSectionHeader({
    super.key,
    required this.title,
    this.color,
    this.icon,
  });

  final String title;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SgpCotColors.neon;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// 문장별 줄바꿈 본문.
class ReadableNarrativeBlock extends StatelessWidget {
  const ReadableNarrativeBlock({
    super.key,
    required this.text,
    this.fontSize = 13,
    this.textColor,
    this.backgroundColor,
  });

  final String text;
  final double fontSize;
  final Color? textColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final sentences = splitReadableSentences(text);
    if (sentences.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sentences.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              sentences[i],
              style: TextStyle(
                fontSize: fontSize,
                height: 1.45,
                color: textColor ?? Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 키워드 칩 나열.
class ReadableKeywordWrap extends StatelessWidget {
  const ReadableKeywordWrap({
    super.key,
    required this.keywords,
    this.color,
  });

  final List<String> keywords;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) return const SizedBox.shrink();
    final c = color ?? Colors.orange.shade800;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: keywords.map((kw) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.35)),
          ),
          child: Text(
            kw,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
          ),
        );
      }).toList(),
    );
  }
}

/// 번호·아이콘 카드형 불릿 목록.
class ReadableActionList extends StatelessWidget {
  const ReadableActionList({
    super.key,
    required this.items,
    required this.accentColor,
    this.title,
  });

  final String? title;
  final List<String> items;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          ReadableSectionHeader(title: title!, color: accentColor),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: SgpAppTheme.textOnAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: SgpAppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

bool isProAnalysisSectionTitle(String title) {
  return title.contains('5단계') ||
      title.contains('SGP-Agent Pro') ||
      title.contains('고도화 분석');
}

/// `[라벨] 내용` 형태 5단계 줄 파싱.
Map<String, List<String>> parseTaggedProLines(List<String> lines) {
  final tagged = <String, List<String>>{};
  final tagRe = RegExp(r'^\[(.+?)\]\s*(.*)$');

  for (final raw in lines) {
    final match = tagRe.firstMatch(raw.trim());
    if (match == null) continue;
    final label = match.group(1)!.trim();
    final body = match.group(2)!.trim();
    if (body.isEmpty) continue;
    tagged.putIfAbsent(label, () => []).add(body);
  }
  return tagged;
}

/// 문장 단위 식별 점·줄 UI.
class ProSentenceLine extends StatelessWidget {
  const ProSentenceLine({
    super.key,
    required this.text,
    required this.accent,
    this.fontSize = 13,
    this.bold = false,
  });

  final String text;
  final Color accent;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: SgpAppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 라벨 칩 + 문장 블록.
class ProLabeledSentenceBlock extends StatelessWidget {
  const ProLabeledSentenceBlock({
    super.key,
    required this.label,
    required this.sentences,
    required this.accent,
    this.icon,
    this.backgroundColor,
  });

  final String label;
  final List<String> sentences;
  final Color accent;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (sentences.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < sentences.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            ProSentenceLine(
              text: sentences[i],
              accent: accent,
              bold: label.contains('유발자') || label.contains('피해'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 5단계 SGP-Agent Pro 고도화 분석 — 문장 식별성 강화 UI.
class ProAnalysisStepView extends StatelessWidget {
  const ProAnalysisStepView({
    super.key,
    required this.analysis,
    this.onProceduralTap,
    this.compact = false,
  });

  final SgpAdvancedAnalysis analysis;
  final VoidCallback? onProceduralTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rate = analysis.prosecutionSuccessRate;
    final rateColor = rate >= 65
        ? SgpAppTheme.success
        : rate >= 45
            ? SgpAppTheme.warning
            : SgpAppTheme.error;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: SgpAppTheme.analysisPanelDecoration(
        accentBorder: SgpAppTheme.primary.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepHeader(),
          const SizedBox(height: 12),
          _buildDualAspectSignals(),
          const SizedBox(height: 14),
          ProLabeledSentenceBlock(
            label: '실질 공격 유발자',
            sentences: splitReadableSentences(analysis.primaryAggressor),
            accent: SgpCotColors.highlight,
            icon: Icons.person_off,
            backgroundColor: SgpCotColors.surface,
          ),
          const SizedBox(height: 10),
          ProLabeledSentenceBlock(
            label: '피해·방어 당사자',
            sentences: splitReadableSentences(analysis.primaryVictim),
            accent: SgpCotColors.shield,
            icon: Icons.shield,
            backgroundColor: SgpAppTheme.surfaceHigh,
          ),
          const SizedBox(height: 12),
          ProLabeledSentenceBlock(
            label: '종합 가·피해자 분석',
            sentences: splitReadableSentences(analysis.suspectVictimStatus),
            accent: SgpCotColors.neon,
            icon: Icons.analytics_outlined,
            backgroundColor: SgpCotColors.surface,
          ),
          if (analysis.mutualCombatSuspected) ...[
            const SizedBox(height: 10),
            ProLabeledSentenceBlock(
              label: '쌍방 폭행 주의',
              sentences: const [
                '단순 동시 입건을 지양합니다.',
                '실질 공격 유발자와 정당방위 요건을 재검토하세요.',
              ],
              accent: Colors.amber.shade900,
              icon: Icons.warning_amber_rounded,
              backgroundColor: Colors.amber.shade50,
            ),
          ],
          const SizedBox(height: 12),
          _buildRateBlock(rate, rateColor),
          if (analysis.legalRisks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildNumberedSentenceList(
              title: '법리 리스크',
              items: analysis.legalRisks,
              accent: SgpCotColors.caution,
            ),
          ],
          if (analysis.evidentiaryActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildNumberedSentenceList(
              title: '증거 보강 Action',
              items: analysis.evidentiaryActions,
              accent: SgpCotColors.brand,
            ),
          ],
          if (analysis.proceduralAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildNumberedSentenceList(
              title: '위수증 방어 절차',
              items: analysis.proceduralAlerts,
              accent: SgpCotColors.onDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDualAspectSignals() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _signalChip(
          '선제 공격',
          analysis.preemptiveAttackDetected ? '감지' : '미감지',
          analysis.preemptiveAttackDetected ? SgpCotColors.highlight : Colors.grey.shade600,
        ),
        _signalChip(
          '방어 행위',
          analysis.defenseActDetected ? '감지' : '미감지',
          analysis.defenseActDetected ? SgpCotColors.shield : Colors.grey.shade600,
        ),
        _signalChip(
          '정당방위',
          '${(analysis.selfDefenseLikelihood * 100).round()}%',
          SgpCotColors.neon,
        ),
        _signalChip(
          '흉기 주도권',
          analysis.weaponDominanceHolder.length > 14
              ? '${analysis.weaponDominanceHolder.substring(0, 14)}…'
              : analysis.weaponDominanceHolder,
          Colors.orange.shade900,
        ),
      ],
    );
  }

  Widget _signalChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SgpCotColors.brand,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '5',
            style: TextStyle(
              color: SgpAppTheme.textOnAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '5단계 · SGP-Agent Pro',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SgpAppTheme.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const Text(
                '고도화 분석',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  color: SgpAppTheme.primaryLight,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.psychology, color: SgpCotColors.brand, size: 22),
        if (analysis.hasCriticalProceduralAlert && onProceduralTap != null)
          IconButton(
            tooltip: '위수증 방어 경고',
            onPressed: onProceduralTap,
            icon: const Icon(Icons.warning_amber_rounded, color: SgpCotColors.caution, size: 26),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }

  Widget _buildRateBlock(double rate, Color rateColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rateColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rateColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rateColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '공소유지',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '신뢰도 예측',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: rateColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: rateColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProSentenceLine(
            text: rate >= 65
                ? '기소·영장 유지 가능성이 양호한 수준입니다.'
                : rate >= 45
                    ? '증거·진술 보강이 필요한 구간입니다.'
                    : '불기소·기각 리스크가 높습니다.',
            accent: rateColor,
            fontSize: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedSentenceList({
    required String title,
    required List<String> items,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReadableSectionHeader(title: title, color: accent, icon: Icons.format_list_numbered),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: SgpAppTheme.textOnAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: splitReadableSentences(items[i])
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ProSentenceLine(text: s, accent: accent, fontSize: 12),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 태그 파싱 기반 5단계 폴백 UI (저장 기록 불러오기 등).
class ProAnalysisTaggedSectionView extends StatelessWidget {
  const ProAnalysisTaggedSectionView({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final tagged = parseTaggedProLines(lines);
    if (tagged.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ReadableNarrativeBlock(text: line),
              ),
            )
            .toList(),
      );
    }

    final rateText = tagged['공소유지예상']?.firstOrNull ?? tagged['공소유지']?.firstOrNull;
    final rate = rateText != null
        ? double.tryParse(rateText.replaceAll(RegExp(r'[^0-9.]'), ''))
        : null;
    final victimLines = tagged['피해·방어당사자'] ?? tagged['피해·방어'];
    final summaryLines = tagged['가·피해자종합'] ?? tagged['종합분석'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tagged['실질공격유발자'] != null)
          ProLabeledSentenceBlock(
            label: '실질 공격 유발자',
            sentences: tagged['실질공격유발자']!
                .expand((t) => splitReadableSentences(t))
                .toList(),
            accent: SgpCotColors.highlight,
            icon: Icons.person_off,
            backgroundColor: SgpCotColors.surface,
          ),
        if (victimLines != null) ...[
          const SizedBox(height: 10),
          ProLabeledSentenceBlock(
            label: '피해·방어 당사자',
            sentences: victimLines.expand((t) => splitReadableSentences(t)).toList(),
            accent: SgpCotColors.shield,
            icon: Icons.shield,
            backgroundColor: SgpAppTheme.surfaceHigh,
          ),
        ],
        if (summaryLines != null) ...[
          const SizedBox(height: 10),
          ProLabeledSentenceBlock(
            label: '종합 가·피해자 분석',
            sentences: summaryLines.expand((t) => splitReadableSentences(t)).toList(),
            accent: SgpCotColors.neon,
            icon: Icons.analytics_outlined,
            backgroundColor: SgpCotColors.surface,
          ),
        ],
        if (rate != null) ...[
          const SizedBox(height: 10),
          _ProsecutionRateChip(rate: rate),
        ],
        if (tagged['법리리스크'] != null) ...[
          const SizedBox(height: 10),
          ReadableActionList(
            title: '법리 리스크',
            items: tagged['법리리스크']!,
            accentColor: SgpCotColors.caution,
          ),
        ],
        if (tagged['증거보강'] != null) ...[
          const SizedBox(height: 6),
          ReadableActionList(
            title: '증거 보강',
            items: tagged['증거보강']!,
            accentColor: SgpCotColors.brand,
          ),
        ],
        if (tagged['절차가이드'] != null) ...[
          const SizedBox(height: 6),
          ReadableActionList(
            title: '절차 가이드',
            items: tagged['절차가이드']!,
            accentColor: SgpCotColors.onDark,
          ),
        ],
      ],
    );
  }
}

class _ProsecutionRateChip extends StatelessWidget {
  const _ProsecutionRateChip({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final rateColor = rate >= 65
        ? SgpAppTheme.success
        : rate >= 45
            ? SgpAppTheme.warning
            : SgpAppTheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rateColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rateColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rateColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '공소유지 예상',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: SgpAppTheme.textOnAccent,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${rate.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: rateColor),
          ),
        ],
      ),
    );
  }
}

/// AdvancedAnalysisWidget — ProAnalysisStepView 래퍼.
class AdvancedAnalysisWidget extends StatelessWidget {
  const AdvancedAnalysisWidget({
    super.key,
    required this.analysis,
    this.onProceduralTap,
  });

  final SgpAdvancedAnalysis analysis;
  final VoidCallback? onProceduralTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SgpCotColors.border),
      ),
      child: ProAnalysisStepView(
        analysis: analysis,
        onProceduralTap: onProceduralTap,
      ),
    );
  }
}

/// 구조화된 추론 결과 카드 묶음.
class StructuredOutputView extends StatelessWidget {
  const StructuredOutputView({
    super.key,
    required this.rawOutput,
    this.advancedAnalysis,
    this.onProceduralTap,
    this.proAnalysisAtBottom = false,
  });

  final String rawOutput;
  final SgpAdvancedAnalysis? advancedAnalysis;
  final VoidCallback? onProceduralTap;

  /// true면 5단계 전체 UI는 하단 [AdvancedAnalysisWidget]에 위임.
  final bool proAnalysisAtBottom;

  @override
  Widget build(BuildContext context) {
    final sections = parseStructuredOutput(rawOutput);
    if (sections.isEmpty) {
      return SelectableText(rawOutput, style: const TextStyle(fontSize: 13, height: 1.5));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          if (isProAnalysisSectionTitle(sections[i].title) &&
              advancedAnalysis != null &&
              proAnalysisAtBottom)
            _ProStepBottomDelegate(analysis: advancedAnalysis!)
          else if (isProAnalysisSectionTitle(sections[i].title) && advancedAnalysis != null)
            ProAnalysisStepView(
              analysis: advancedAnalysis!,
              onProceduralTap: onProceduralTap,
            )
          else if (isProAnalysisSectionTitle(sections[i].title))
            _ProAnalysisSectionShell(section: sections[i])
          else
            _OutputSectionCard(section: sections[i]),
        ],
      ],
    );
  }
}

class _ProStepBottomDelegate extends StatelessWidget {
  const _ProStepBottomDelegate({required this.analysis});

  final SgpAdvancedAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final rate = analysis.prosecutionSuccessRate;
  final rateColor = rate >= 65
        ? SgpCotColors.neon
        : rate >= 45
            ? Colors.orange.shade800
            : SgpCotColors.caution;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SgpAppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SgpAppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SgpCotColors.brand,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '5',
              style: TextStyle(
                color: SgpAppTheme.textOnAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SGP-Agent Pro 고도화 분석 → 하단 카드 참조\n'
              '공소유지 ${rate.toStringAsFixed(0)}% · '
              '${analysis.preemptiveAttackDetected ? "선제공격 감지" : "선제공격 미감지"}',
              style: const TextStyle(fontSize: 12, height: 1.35, color: SgpAppTheme.textPrimary),
            ),
          ),
          Icon(Icons.arrow_downward, color: rateColor, size: 20),
        ],
      ),
    );
  }
}

class _ProAnalysisSectionShell extends StatelessWidget {
  const _ProAnalysisSectionShell({required this.section});

  final ReadableOutputSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SgpAppTheme.analysisPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SgpCotColors.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '5',
                  style: TextStyle(
                    color: SgpAppTheme.textOnAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SgpAppTheme.primaryLight,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProAnalysisTaggedSectionView(lines: section.lines),
        ],
      ),
    );
  }
}

class _OutputSectionCard extends StatelessWidget {
  const _OutputSectionCard({required this.section});

  final ReadableOutputSection section;

  @override
  Widget build(BuildContext context) {
    final accent = SgpCotColors.sectionAccent(section.title);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SgpCotColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadableSectionHeader(
            title: section.title,
            icon: Icons.article_outlined,
            color: accent,
          ),
          if (section.lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...section.lines.map((line) {
              final sentences = splitReadableSentences(line);
              if (sentences.length <= 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: SgpAppTheme.textPrimary,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sentences
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: SgpAppTheme.textPrimary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
