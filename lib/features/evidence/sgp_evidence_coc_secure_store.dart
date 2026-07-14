/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : evidenceCoC Local Secure Vault (On-Device Only)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// evidenceCoC 세션(SHA-256·타임라인 JSON) — 외부 전송 없이 로컬 AES 봉인 저장.
///
/// Flutter `path_provider` 비의존 — 호출측이 [Directory]를 주입한다 (온디바이스 폐쇠망).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../agent/sgp_secure_cache_crypto.dart';
import 'sgp_evidence_coc_engine.dart';

/// 유치인(custody)과 분리된 디지털 증거 연속성 전용 금고.
abstract final class SgpEvidenceCoCSecureStore {
  static const filePrefix = 'sgp_evidence_coc_';
  static const keyAlias = 'sgp_evidence_coc_vault_v1';
  static const architectSignature = 'INSP_KANG_SG_4066';

  /// 온디바이스 전용 — 네트워크 호출 없음.
  static const bool forbidsNetworkEgress = true;

  static SgpCacheCipher defaultCipher([Uint8List? testKey]) =>
      SgpTestCacheCipher(testKey ?? _deriveOfflineVaultKey());

  /// AES-256-GCM으로 세션 JSON을 봉인·저장. SHA-256 해시값 포함.
  static Future<File> persistSession(
    EvidenceCoCSession session, {
    required Directory directory,
    SgpCacheCipher? cipher,
  }) async {
    if (!await directory.exists()) await directory.create(recursive: true);

    final id = session.startedAt.millisecondsSinceEpoch.toString();
    final payload = <String, dynamic>{
      'vault': keyAlias,
      'signature': architectSignature,
      'offlineOnly': forbidsNetworkEgress,
      'networkEgress': false,
      'evidenceCoC': session.toJson(),
    };
    final encrypted =
        await (cipher ?? defaultCipher()).encrypt(jsonEncode(payload));
    final file = File(
      '${directory.path}/$filePrefix$id$kSgpEncryptedCacheExtension',
    );
    await file.writeAsString(encrypted, flush: true);
    return file;
  }

  static Future<EvidenceCoCSession?> loadLatest({
    required Directory directory,
    SgpCacheCipher? cipher,
  }) async {
    if (!await directory.exists()) return null;
    final files = directory
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.contains(filePrefix) &&
              f.path.endsWith(kSgpEncryptedCacheExtension),
        )
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (files.isEmpty) return null;
    return loadFile(files.first, cipher: cipher);
  }

  static Future<EvidenceCoCSession?> loadFile(
    File file, {
    SgpCacheCipher? cipher,
  }) async {
    final raw = await file.readAsString();
    final plain = await (cipher ?? defaultCipher()).decrypt(raw);
    final map = jsonDecode(plain) as Map<String, dynamic>;
    final coc = map['evidenceCoC'];
    if (coc is! Map) return null;
    return _sessionFromJson(Map<String, dynamic>.from(coc));
  }

  static Uint8List _deriveOfflineVaultKey() {
    final material = utf8.encode(
      'SGP-Agent|$keyAlias|$architectSignature|offline-vault-v1',
    );
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = material[i % material.length] ^ ((i * 31) & 0xff);
    }
    return out;
  }

  static EvidenceCoCSession _sessionFromJson(Map<String, dynamic> json) {
    final steps = <EvidenceCoCStep, EvidenceCoCStepRecord>{};
    final stepsRaw = json['steps'];
    if (stepsRaw is List) {
      for (final item in stepsRaw) {
        if (item is Map) {
          final rec = EvidenceCoCStepRecord.fromJson(
            Map<String, dynamic>.from(item),
          );
          steps[rec.step] = rec;
        }
      }
    }
    for (final s in EvidenceCoCStep.values) {
      steps.putIfAbsent(
        s,
        () => EvidenceCoCStepRecord(step: s, completed: false),
      );
    }
    final spots = <EvidenceBlindSpot>[];
    final blind = json['blindSpots'];
    if (blind is List) {
      for (final name in blind) {
        spots.add(
          EvidenceBlindSpot.values.firstWhere(
            (b) => b.name == name,
            orElse: () => EvidenceBlindSpot.hashMissing,
          ),
        );
      }
    }
    return EvidenceCoCSession(
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      steps: steps,
      mediaLabel: json['mediaLabel'] as String?,
      deviceType: json['deviceType'] as String?,
      blindSpots: spots,
    );
  }
}
