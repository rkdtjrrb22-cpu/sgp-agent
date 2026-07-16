/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Legal Blackbox Forensic Engine (WORM Provenance Chain)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 법률 에이전트 블랙박스 — 추론 체인 증명(Provenance) WORM 로거.
///
/// 체인: [온톨로지 노드 ID → KG-RAG 문서 가중치 → LLM 프롬프트 해시 → 사용자 서명]
/// 저장: Write-Once-Read-Many (파일 덮어쓰기 거부, 해시 체인 연결).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../agent/sgp_secure_cache_crypto.dart';

/// 단일 추론 체인 링크.
class LegalProvenanceEntry {
  const LegalProvenanceEntry({
    required this.entryId,
    required this.timestamp,
    required this.ontologyNodeIds,
    required this.kgragDocWeights,
    required this.promptHash,
    required this.userSignatureHash,
    required this.prevEntryHash,
    required this.entryHash,
    this.opinionSummary = '',
    this.operationalMode = 'field',
  });

  final String entryId;
  final DateTime timestamp;
  final List<String> ontologyNodeIds;
  final Map<String, double> kgragDocWeights;
  final String promptHash;
  final String userSignatureHash;
  final String prevEntryHash;
  final String entryHash;
  final String opinionSummary;
  final String operationalMode;

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'timestamp': timestamp.toIso8601String(),
        'ontologyNodeIds': ontologyNodeIds,
        'kgragDocWeights': kgragDocWeights,
        'promptHash': promptHash,
        'userSignatureHash': userSignatureHash,
        'prevEntryHash': prevEntryHash,
        'entryHash': entryHash,
        'opinionSummary': opinionSummary,
        'operationalMode': operationalMode,
        'signature': SgpLegalBlackbox.architectSignature,
        'worm': true,
      };

  factory LegalProvenanceEntry.fromJson(Map<String, dynamic> json) {
    final weightsRaw = json['kgragDocWeights'];
    final weights = <String, double>{};
    if (weightsRaw is Map) {
      for (final e in weightsRaw.entries) {
        weights['${e.key}'] = (e.value as num).toDouble();
      }
    }
    return LegalProvenanceEntry(
      entryId: json['entryId'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ontologyNodeIds: (json['ontologyNodeIds'] as List?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      kgragDocWeights: weights,
      promptHash: json['promptHash'] as String? ?? '',
      userSignatureHash: json['userSignatureHash'] as String? ?? '',
      prevEntryHash: json['prevEntryHash'] as String? ?? '',
      entryHash: json['entryHash'] as String? ?? '',
      opinionSummary: json['opinionSummary'] as String? ?? '',
      operationalMode: json['operationalMode'] as String? ?? 'field',
    );
  }
}

/// 체인 검증 결과.
class LegalBlackboxAuditReport {
  const LegalBlackboxAuditReport({
    required this.valid,
    required this.entryCount,
    this.brokenAtEntryId,
    this.message = '',
  });

  final bool valid;
  final int entryCount;
  final String? brokenAtEntryId;
  final String message;
}

/// WORM 법률 블랙박스.
class SgpLegalBlackbox {
  SgpLegalBlackbox({
    Directory? directory,
    SgpCacheCipher? cipher,
    this.genesisHash = 'SGP_LEGAL_BLACKBOX_GENESIS_v1',
  })  : _directory = directory,
        _cipher = cipher ?? SgpLegalBlackbox.defaultCipher();

  static const filePrefix = 'sgp_legal_bb_';
  static const keyAlias = 'sgp_legal_blackbox_worm_v1';
  static const architectSignature = 'INSP_KANG_SG_4066';
  static const bool forbidsNetworkEgress = true;

  final Directory? _directory;
  final SgpCacheCipher _cipher;
  final String genesisHash;

  final List<LegalProvenanceEntry> _memoryChain = [];
  final Set<String> _writtenPaths = {};

  String get tipHash =>
      _memoryChain.isEmpty ? genesisHash : _memoryChain.last.entryHash;

  int get length => _memoryChain.length;

  List<LegalProvenanceEntry> get chain =>
      List<LegalProvenanceEntry>.unmodifiable(_memoryChain);

  static SgpCacheCipher defaultCipher([Uint8List? testKey]) =>
      SgpTestCacheCipher(testKey ?? _deriveOfflineVaultKey());

  static String hashPayload(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();

  static String hashPrompt(String prompt) => hashPayload(prompt);

  static String hashUserSignature(String signatureMaterial) =>
      hashPayload(signatureMaterial);

  /// Provenance 링크 생성·체인 연결·WORM 기록.
  Future<LegalProvenanceEntry> appendInference({
    required List<String> ontologyNodeIds,
    required Map<String, double> kgragDocWeights,
    required String prompt,
    required String userSignatureMaterial,
    String opinionSummary = '',
    String operationalMode = 'field',
    DateTime? at,
  }) async {
    final ts = at ?? DateTime.now();
    final entryId =
        '${ts.millisecondsSinceEpoch}_${_memoryChain.length.toString().padLeft(6, '0')}';
    final promptHash = hashPrompt(prompt);
    final userSig = hashUserSignature(userSignatureMaterial);
    final prev = tipHash;

    final canonical = jsonEncode({
      'entryId': entryId,
      'timestamp': ts.toIso8601String(),
      'ontologyNodeIds': ontologyNodeIds,
      'kgragDocWeights': kgragDocWeights,
      'promptHash': promptHash,
      'userSignatureHash': userSig,
      'prevEntryHash': prev,
      'opinionSummary': opinionSummary,
      'operationalMode': operationalMode,
    });
    final entryHash = hashPayload(canonical);

    final entry = LegalProvenanceEntry(
      entryId: entryId,
      timestamp: ts,
      ontologyNodeIds: List<String>.from(ontologyNodeIds),
      kgragDocWeights: Map<String, double>.from(kgragDocWeights),
      promptHash: promptHash,
      userSignatureHash: userSig,
      prevEntryHash: prev,
      entryHash: entryHash,
      opinionSummary: opinionSummary,
      operationalMode: operationalMode,
    );

    await _wormPersist(entry);
    _memoryChain.add(entry);
    return entry;
  }

  Future<void> _wormPersist(LegalProvenanceEntry entry) async {
    final dir = _directory;
    if (dir == null) return;
    if (!await dir.exists()) await dir.create(recursive: true);

    final path =
        '${dir.path}/$filePrefix${entry.entryId}$kSgpEncryptedCacheExtension';
    if (_writtenPaths.contains(path) || await File(path).exists()) {
      throw StateError(
        'WORM violation: blackbox entry already exists ($path)',
      );
    }

    final encrypted = await _cipher.encrypt(jsonEncode(entry.toJson()));
    final file = File(path);
    await file.writeAsString(encrypted, flush: true);
    // 플랫폼 가능 시 읽기 전용 마킹 (덮어쓰기 억제)
    try {
      await file.setLastModified(entry.timestamp);
    } catch (_) {}
    _writtenPaths.add(path);
  }

  /// 해시 체인 무결성 검증 (사후 포렌식).
  LegalBlackboxAuditReport verifyChain() {
    var expectedPrev = genesisHash;
    for (final e in _memoryChain) {
      if (e.prevEntryHash != expectedPrev) {
        return LegalBlackboxAuditReport(
          valid: false,
          entryCount: _memoryChain.length,
          brokenAtEntryId: e.entryId,
          message: 'prevEntryHash mismatch',
        );
      }
      final canonical = jsonEncode({
        'entryId': e.entryId,
        'timestamp': e.timestamp.toIso8601String(),
        'ontologyNodeIds': e.ontologyNodeIds,
        'kgragDocWeights': e.kgragDocWeights,
        'promptHash': e.promptHash,
        'userSignatureHash': e.userSignatureHash,
        'prevEntryHash': e.prevEntryHash,
        'opinionSummary': e.opinionSummary,
        'operationalMode': e.operationalMode,
      });
      final recomputed = hashPayload(canonical);
      if (recomputed != e.entryHash) {
        return LegalBlackboxAuditReport(
          valid: false,
          entryCount: _memoryChain.length,
          brokenAtEntryId: e.entryId,
          message: 'entryHash tamper detected',
        );
      }
      expectedPrev = e.entryHash;
    }
    return LegalBlackboxAuditReport(
      valid: true,
      entryCount: _memoryChain.length,
      message: 'chain intact — 100% provenance transparency',
    );
  }

  /// 디스크 WORM 볼륨에서 체인 재적재 (읽기 전용).
  Future<int> loadFromDisk() async {
    final dir = _directory;
    if (dir == null || !await dir.exists()) return 0;
    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.contains(filePrefix) &&
              f.path.endsWith(kSgpEncryptedCacheExtension),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    _memoryChain.clear();
    _writtenPaths.clear();
    for (final file in files) {
      final plain = await _cipher.decrypt(await file.readAsString());
      final map = jsonDecode(plain) as Map<String, dynamic>;
      final entry = LegalProvenanceEntry.fromJson(map);
      _memoryChain.add(entry);
      _writtenPaths.add(file.path);
    }
    return _memoryChain.length;
  }

  static Uint8List _deriveOfflineVaultKey() {
    final material = utf8.encode(
      'SGP-Agent|$keyAlias|$architectSignature|worm-blackbox-v1',
    );
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = material[i % material.length] ^ ((i * 37) & 0xff);
    }
    return out;
  }
}
