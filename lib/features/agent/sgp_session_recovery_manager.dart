/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Session Lifecycle Recovery (Secure Vault Autosave)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 강제 종료·백그라운드 전환 시 세션 100% 복구용 Secure Vault 오토세이브.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sgp_secure_cache_crypto.dart';

/// 외근·법률 추출 중 보존하는 체크포인트.
class SgpSessionCheckpoint {
  const SgpSessionCheckpoint({
    required this.rawText,
    required this.savedAt,
    this.operationalMode = 'field',
    this.checklistJson = const {},
    this.hierarchicalLawJson,
    this.physicalThreatLevel,
    this.forceExecutionLogged = false,
    this.selfJudgmentAccepted = false,
  });

  final String rawText;
  final DateTime savedAt;
  final String operationalMode;
  final Map<String, dynamic> checklistJson;
  final Map<String, dynamic>? hierarchicalLawJson;
  final String? physicalThreatLevel;
  final bool forceExecutionLogged;
  final bool selfJudgmentAccepted;

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'savedAt': savedAt.toIso8601String(),
        'operationalMode': operationalMode,
        'checklist': checklistJson,
        if (hierarchicalLawJson != null)
          'hierarchicalLawSet': hierarchicalLawJson,
        if (physicalThreatLevel != null)
          'physicalThreatLevel': physicalThreatLevel,
        'forceExecutionLogged': forceExecutionLogged,
        'selfJudgmentAccepted': selfJudgmentAccepted,
        'signature': SgpSessionRecoveryManager.architectSignature,
      };

  factory SgpSessionCheckpoint.fromJson(Map<String, dynamic> json) {
    return SgpSessionCheckpoint(
      rawText: json['rawText'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
      operationalMode: json['operationalMode'] as String? ?? 'field',
      checklistJson: Map<String, dynamic>.from(
        (json['checklist'] as Map?) ?? const {},
      ),
      hierarchicalLawJson: json['hierarchicalLawSet'] is Map
          ? Map<String, dynamic>.from(json['hierarchicalLawSet'] as Map)
          : null,
      physicalThreatLevel: json['physicalThreatLevel'] as String?,
      forceExecutionLogged: json['forceExecutionLogged'] as bool? ?? false,
      selfJudgmentAccepted: json['selfJudgmentAccepted'] as bool? ?? false,
    );
  }

  bool get hasRecoverableContent =>
      rawText.trim().isNotEmpty || hierarchicalLawJson != null;
}

/// AES Secure Vault 기반 세션 오토세이브·복구.
class SgpSessionRecoveryManager {
  SgpSessionRecoveryManager({
    required this.directory,
    SgpCacheCipher? cipher,
    this.debounce = const Duration(milliseconds: 600),
  }) : _cipher = cipher ?? defaultCipher();

  static const fileName = 'sgp_session_autosave.sgpcache';
  static const keyAlias = 'sgp_session_recovery_v1';
  static const architectSignature = 'INSP_KANG_SG_4066';
  static const bool forbidsNetworkEgress = true;

  final Directory directory;
  final SgpCacheCipher _cipher;
  final Duration debounce;

  Timer? _debounceTimer;
  SgpSessionCheckpoint? _lastWritten;
  int autosaveCount = 0;

  static SgpCacheCipher defaultCipher([Uint8List? key]) =>
      SgpTestCacheCipher(key ?? _deriveKey());

  static Uint8List _deriveKey() {
    final seed = utf8.encode('SGP-SESSION|$architectSignature|$keyAlias');
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = seed[i % seed.length] ^ (0x71 + i);
    }
    return out;
  }

  File get _file => File('${directory.path}/$fileName');

  SgpSessionCheckpoint? get lastWritten => _lastWritten;

  /// UI 입력 변경 시 디바운스 오토세이브.
  void scheduleAutosave(SgpSessionCheckpoint checkpoint) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(flush(checkpoint));
    });
  }

  /// 즉시 Vault 기록 (lifecycle paused/detached).
  Future<File> flush(SgpSessionCheckpoint checkpoint) async {
    _debounceTimer?.cancel();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final payload = {
      'vault': keyAlias,
      'offlineOnly': forbidsNetworkEgress,
      'checkpoint': checkpoint.toJson(),
    };
    final enc = await _cipher.encrypt(jsonEncode(payload));
    await _file.writeAsString(enc, flush: true);
    _lastWritten = checkpoint;
    autosaveCount++;
    return _file;
  }

  Future<SgpSessionCheckpoint?> restore() async {
    if (!await _file.exists()) return null;
    final plain = await _cipher.decrypt(await _file.readAsString());
    final map = jsonDecode(plain) as Map<String, dynamic>;
    final cp = map['checkpoint'] as Map<String, dynamic>?;
    if (cp == null) return null;
    final checkpoint = SgpSessionCheckpoint.fromJson(cp);
    _lastWritten = checkpoint;
    return checkpoint;
  }

  Future<void> clear() async {
    _debounceTimer?.cancel();
    if (await _file.exists()) await _file.delete();
    _lastWritten = null;
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
