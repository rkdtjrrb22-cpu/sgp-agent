/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Legal Blackbox Intranet Ledger Mirror + Resiliency
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 망분리 수사 넷 분산 원장 단방향 미러링 + Secure Enclave 복구 탄력성.
///
/// - 로컬 WORM → Intranet Forensic Ledger (async, encrypted, one-way)
/// - 동기화 실패 시 KeyStore/Enclave 격리 큐에 임시 보관
/// - 재연결 시 기존 파일 덮어쓰기(StateError) 없이 tip 이후만 append
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../agent/sgp_secure_cache_crypto.dart';
import 'sgp_legal_blackbox.dart';

/// 미러링 대상 원장 (인메모리/디렉터리 시뮬레이션 — 실제 망은 주입).
abstract class SgpIntranetLedgerSink {
  Future<void> mirrorEntry(LegalProvenanceEntry entry, String encryptedPayload);
  Future<Set<String>> knownEntryIds();
  Future<List<LegalProvenanceEntry>> pullChain();
}

/// 로컬 디렉터리로 단방향 미러 (폐쇄망 PoC).
class SgpDirectoryLedgerSink implements SgpIntranetLedgerSink {
  SgpDirectoryLedgerSink(this.directory, {SgpCacheCipher? cipher})
      : _cipher = cipher ?? SgpLegalBlackbox.defaultCipher();

  final Directory directory;
  final SgpCacheCipher _cipher;
  static const prefix = 'sgp_ledger_';

  @override
  Future<void> mirrorEntry(
    LegalProvenanceEntry entry,
    String encryptedPayload,
  ) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    final path =
        '${directory.path}/$prefix${entry.entryId}$kSgpEncryptedCacheExtension';
    final file = File(path);
    if (await file.exists()) {
      // 단방향 원장도 WORM — 덮어쓰기 거부 (멱등 no-op)
      return;
    }
    await file.writeAsString(encryptedPayload, flush: true);
  }

  @override
  Future<Set<String>> knownEntryIds() async {
    if (!await directory.exists()) return {};
    final ids = <String>{};
    for (final f in directory.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.startsWith(prefix)) continue;
      final id = name
          .replaceFirst(prefix, '')
          .replaceFirst(kSgpEncryptedCacheExtension, '');
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<List<LegalProvenanceEntry>> pullChain() async {
    if (!await directory.exists()) return const [];
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(prefix))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final out = <LegalProvenanceEntry>[];
    for (final f in files) {
      final plain = await _cipher.decrypt(await f.readAsString());
      out.add(
        LegalProvenanceEntry.fromJson(
          jsonDecode(plain) as Map<String, dynamic>,
        ),
      );
    }
    return out;
  }
}

/// Secure Enclave / KeyStore 연동 임시 큐 (온디바이스 격리).
class SgpSecureEnclavePendingQueue {
  SgpSecureEnclavePendingQueue({SgpCacheCipher? cipher})
      : _cipher = cipher ?? SgpLegalBlackbox.defaultCipher();

  final SgpCacheCipher _cipher;
  final List<String> _sealedBlobs = [];
  final Set<String> _pendingIds = {};

  int get length => _sealedBlobs.length;
  bool get isEmpty => _sealedBlobs.isEmpty;
  Set<String> get pendingIds => Set.unmodifiable(_pendingIds);

  Future<void> enqueue(LegalProvenanceEntry entry) async {
    if (_pendingIds.contains(entry.entryId)) return;
    final sealed = await _cipher.encrypt(jsonEncode(entry.toJson()));
    _sealedBlobs.add(sealed);
    _pendingIds.add(entry.entryId);
  }

  Future<List<LegalProvenanceEntry>> drain() async {
    final out = <LegalProvenanceEntry>[];
    for (final blob in _sealedBlobs) {
      final plain = await _cipher.decrypt(blob);
      out.add(
        LegalProvenanceEntry.fromJson(
          jsonDecode(plain) as Map<String, dynamic>,
        ),
      );
    }
    _sealedBlobs.clear();
    _pendingIds.clear();
    return out;
  }

  /// 디스크 스냅샷 (강제 전원 차단 대비).
  Future<void> persistTo(Directory dir) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/sgp_enclave_pending.sgpcache');
    final payload = jsonEncode({'blobs': _sealedBlobs, 'ids': _pendingIds.toList()});
    await file.writeAsString(await _cipher.encrypt(payload), flush: true);
  }

  Future<void> restoreFrom(Directory dir) async {
    final file = File('${dir.path}/sgp_enclave_pending.sgpcache');
    if (!await file.exists()) return;
    final plain = await _cipher.decrypt(await file.readAsString());
    final map = jsonDecode(plain) as Map<String, dynamic>;
    _sealedBlobs
      ..clear()
      ..addAll((map['blobs'] as List?)?.map((e) => '$e') ?? const []);
    _pendingIds
      ..clear()
      ..addAll((map['ids'] as List?)?.map((e) => '$e') ?? const []);
  }
}

/// 미러링 트랜잭션 결과.
class SgpLedgerMirrorReport {
  const SgpLedgerMirrorReport({
    required this.mirrored,
    required this.queuedInEnclave,
    required this.skippedExisting,
    required this.ok,
    this.message = '',
  });

  final int mirrored;
  final int queuedInEnclave;
  final int skippedExisting;
  final bool ok;
  final String message;
}

/// 블랙박스 ↔ 분산 원장 미러 + 복구 탄력성.
class SgpLegalBlackboxResiliency {
  SgpLegalBlackboxResiliency({
    required this.blackbox,
    required this.ledger,
    SgpSecureEnclavePendingQueue? enclave,
    SgpCacheCipher? cipher,
  })  : enclave = enclave ?? SgpSecureEnclavePendingQueue(cipher: cipher),
        _cipher = cipher ?? SgpLegalBlackbox.defaultCipher();

  final SgpLegalBlackbox blackbox;
  final SgpIntranetLedgerSink ledger;
  final SgpSecureEnclavePendingQueue enclave;
  final SgpCacheCipher _cipher;

  bool _intranetReachable = true;

  void setIntranetReachable(bool value) => _intranetReachable = value;
  bool get intranetReachable => _intranetReachable;

  /// 단방향 비동기 미러. 실패 시 Enclave 큐잉 (앱 프리징 없음).
  Future<SgpLedgerMirrorReport> mirrorPending({
    bool simulateTransportError = false,
  }) async {
    var mirrored = 0;
    var queued = 0;
    var skipped = 0;

    final known = _intranetReachable && !simulateTransportError
        ? await ledger.knownEntryIds()
        : <String>{};

    for (final entry in blackbox.chain) {
      if (known.contains(entry.entryId)) {
        skipped++;
        continue;
      }
      if (!_intranetReachable || simulateTransportError) {
        await enclave.enqueue(entry);
        queued++;
        continue;
      }
      try {
        final encrypted = await _cipher.encrypt(jsonEncode(entry.toJson()));
        await ledger.mirrorEntry(entry, encrypted);
        mirrored++;
      } catch (_) {
        await enclave.enqueue(entry);
        queued++;
      }
    }

    return SgpLedgerMirrorReport(
      mirrored: mirrored,
      queuedInEnclave: queued,
      skippedExisting: skipped,
      ok: queued == 0 || enclave.length > 0,
      message: queued > 0
          ? 'enclave quarantine active — await reconnect'
          : 'mirror complete',
    );
  }

  /// 재연결 복원 — 기존 WORM 엔트리 덮어쓰기 없이 tip 이후만 병합.
  Future<SgpLedgerMirrorReport> restoreAfterReconnect() async {
    _intranetReachable = true;
    final pending = await enclave.drain();
    var mirrored = 0;
    var skipped = 0;
    final known = await ledger.knownEntryIds();
    final localIds = blackbox.chain.map((e) => e.entryId).toSet();

    for (final entry in pending) {
      if (known.contains(entry.entryId) || localIds.contains(entry.entryId)) {
        skipped++;
        // StateError 회피: 이미 존재하면 no-op
        continue;
      }
      try {
        // 로컬 체인에 없는 경우만 안전 append (해시 체인 tip 연결)
        await blackbox.appendRecoveredEntry(entry);
        localIds.add(entry.entryId);
      } on StateError {
        skipped++;
        continue;
      }
      final encrypted = await _cipher.encrypt(jsonEncode(entry.toJson()));
      await ledger.mirrorEntry(entry, encrypted);
      mirrored++;
    }

    // 로컬 → 원장 잔여 미러
    final flush = await mirrorPending();
    return SgpLedgerMirrorReport(
      mirrored: mirrored + flush.mirrored,
      queuedInEnclave: flush.queuedInEnclave,
      skippedExisting: skipped + flush.skippedExisting,
      ok: true,
      message: 'resilient restore complete — no WORM StateError',
    );
  }

  /// 강제 전원 차단 시나리오: Enclave 디스크 스냅샷.
  Future<void> checkpointEnclave(Directory dir) => enclave.persistTo(dir);

  Future<void> recoverEnclave(Directory dir) => enclave.restoreFrom(dir);
}

/// 복구 전용 append — tip 재연결, 동일 entryId면 무시.
extension SgpLegalBlackboxRecovery on SgpLegalBlackbox {
  Future<LegalProvenanceEntry?> appendRecoveredEntry(
    LegalProvenanceEntry orphan,
  ) async {
    if (chain.any((e) => e.entryId == orphan.entryId)) {
      return null;
    }
    // tip에 맞게 prev를 재바인딩한 새 엔트리로 WORM 기록
    return appendInference(
      ontologyNodeIds: orphan.ontologyNodeIds,
      kgragDocWeights: orphan.kgragDocWeights,
      prompt: 'RECOVERED|${orphan.promptHash}',
      userSignatureMaterial: 'recovery|${orphan.userSignatureHash}',
      opinionSummary: orphan.opinionSummary,
      operationalMode: orphan.operationalMode,
      at: orphan.timestamp.add(Duration(milliseconds: length + 1)),
    );
  }
}
