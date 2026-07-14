/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Stage 5 — Off-Grid Law Snapshot (Hybrid Sync)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 통신 무감각 잔상 보존 — 1.5초 Heartbeat · AES Vault · Seamless Fallback.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sgp_law_extractor.dart';
import 'sgp_secure_cache_crypto.dart';

/// LV4 즉결심판·별표서식 123종 카탈로그.
abstract final class SummaryTrialFormCatalog {
  static const targetCount = 123;

  static List<Map<String, String>> build() {
    return List.generate(targetCount, (i) {
      final n = i + 1;
      return {
        'id': 'STF-${n.toString().padLeft(3, '0')}',
        'formNo': '별표서식-$n',
        'title': n == 1
            ? '즉결심판 청구서'
            : n == 2
                ? '응급실 소란·소방방해 조치 확인서'
                : '즉결심판·경미사범 서식 #$n',
      };
    });
  }
}

/// 로컬 Secure Vault에 보존되는 법령 잔상.
class SgpLawSnapshot {
  const SgpLawSnapshot({
    required this.lastSuccessfulSyncTime,
    required this.lawSet,
    required this.summaryTrialForms,
    this.version = 's5-1.0.0',
    this.source = 'local-seed',
  });

  final DateTime lastSuccessfulSyncTime;
  final HierarchicalLawSet lawSet;
  final List<Map<String, String>> summaryTrialForms;
  final String version;
  final String source;

  String get subtleBannerLabel {
    final t = lastSuccessfulSyncTime;
    final stamp =
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    return '오프라인 보호막 모드 가동 중 (최종 법령 동기화: $stamp)';
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'source': source,
        'lastSuccessfulSyncTime': lastSuccessfulSyncTime.toIso8601String(),
        'lawSet': lawSet.toJson(),
        'summaryTrialForms': summaryTrialForms,
      };

  factory SgpLawSnapshot.fromJson(Map<String, dynamic> json) {
    final sync = json['lastSuccessfulSyncTime'] as String?;
    return SgpLawSnapshot(
      version: json['version'] as String? ?? 's5-1.0.0',
      source: json['source'] as String? ?? 'local-seed',
      lastSuccessfulSyncTime:
          sync != null ? DateTime.parse(sync) : DateTime.now(),
      lawSet: HierarchicalLawSet.fromJson(
        (json['lawSet'] as Map<String, dynamic>?) ?? const {},
      ),
      summaryTrialForms: (json['summaryTrialForms'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
              ))
          .toList(),
    );
  }

  static SgpLawSnapshot seed({DateTime? syncTime, String sampleText = ''}) {
    final law = sampleText.trim().isEmpty
        ? SgpLawExtractor.extract(
            '술 취한 자가 옷을 벗고 소란을 피우고 있습니다',
          )
        : SgpLawExtractor.extract(sampleText);
    return SgpLawSnapshot(
      lastSuccessfulSyncTime: syncTime ?? DateTime(2026, 7, 14, 15, 19),
      lawSet: law,
      summaryTrialForms: SummaryTrialFormCatalog.build(),
      source: 'local-seed',
    );
  }
}

/// AES Secure Vault — 법령 잔상 봉인/복원.
abstract final class SgpLawSnapshotVault {
  static const fileName = 'sgp_law_snapshot.sgpcache';
  static const keyAlias = 'sgp_law_snapshot_vault_v1';
  static const architectSignature = 'INSP_KANG_SG_4066';
  static const bool forbidsNetworkEgress = true;

  static SgpCacheCipher defaultCipher([Uint8List? key]) =>
      SgpTestCacheCipher(key ?? _key());

  static Uint8List _key() {
    final seed = utf8.encode('SGP-LAW-SNAP|$architectSignature|$keyAlias');
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = seed[i % seed.length] ^ (0x3C + i);
    }
    return out;
  }

  static Future<File> persist(
    SgpLawSnapshot snapshot, {
    required Directory directory,
    SgpCacheCipher? cipher,
  }) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    final payload = {
      'vault': keyAlias,
      'signature': architectSignature,
      'offlineOnly': forbidsNetworkEgress,
      'snapshot': snapshot.toJson(),
    };
    final enc = await (cipher ?? defaultCipher()).encrypt(jsonEncode(payload));
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(enc, flush: true);
    return file;
  }

  static Future<SgpLawSnapshot?> load({
    required Directory directory,
    SgpCacheCipher? cipher,
  }) async {
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) return null;
    final plain =
        await (cipher ?? defaultCipher()).decrypt(await file.readAsString());
    final map = jsonDecode(plain) as Map<String, dynamic>;
    final snap = map['snapshot'] as Map<String, dynamic>?;
    if (snap == null) return null;
    return SgpLawSnapshot.fromJson(snap);
  }
}

/// 실시간 Heartbeat — T > 1.5초면 즉시 로컬 잔상 모드.
class LawHeartbeatMonitor {
  LawHeartbeatMonitor({
    this.timeout = const Duration(milliseconds: 1500),
  });

  final Duration timeout;
  bool offlineOnly = false;

  Future<T> guard<T>({
    required Future<T> Function() remote,
    required T Function() localFallback,
  }) async {
    try {
      final v = await remote().timeout(timeout);
      offlineOnly = false;
      return v;
    } on TimeoutException {
      offlineOnly = true;
      return localFallback();
    } on Object {
      offlineOnly = true;
      return localFallback();
    }
  }
}

/// 원격 법제처/중계 포트 (운영 시 암호화 터널 구현체).
abstract interface class LawSnapshotRemoteClient {
  Future<SgpLawSnapshot> fetchLatest({required Duration timeout});
}

class LawSnapshotMockRemote implements LawSnapshotRemoteClient {
  LawSnapshotMockRemote({this.delay = Duration.zero, this.fail = false});

  Duration delay;
  bool fail;

  @override
  Future<SgpLawSnapshot> fetchLatest({required Duration timeout}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw StateError('law remote unreachable');
    return SgpLawSnapshot.seed(
      syncTime: DateTime.now(),
    ).copyWithSource('remote-mock');
  }
}

extension on SgpLawSnapshot {
  SgpLawSnapshot copyWithSource(String src) => SgpLawSnapshot(
        lastSuccessfulSyncTime: lastSuccessfulSyncTime,
        lawSet: lawSet,
        summaryTrialForms: summaryTrialForms,
        version: version,
        source: src,
      );
}

/// Hybrid Off-Grid Sync — 데드존에서도 무중단 법령 조문·서식 제공.
class SgpLawOffGridSync {
  SgpLawOffGridSync({
    LawSnapshotRemoteClient? remote,
    LawHeartbeatMonitor? heartbeat,
    Directory? vaultDirectory,
    SgpCacheCipher? cipher,
    SgpLawSnapshot? seed,
    this.forbidsNetworkEgress = true,
  })  : _remote = remote ?? LawSnapshotMockRemote(),
        _heartbeat = heartbeat ?? LawHeartbeatMonitor(),
        _vaultDir = vaultDirectory,
        _cipher = cipher,
        _active = seed ?? SgpLawSnapshot.seed();

  final bool forbidsNetworkEgress;
  final LawSnapshotRemoteClient _remote;
  final LawHeartbeatMonitor _heartbeat;
  final Directory? _vaultDir;
  final SgpCacheCipher? _cipher;
  SgpLawSnapshot _active;

  SgpLawSnapshot get activeSnapshot => _active;
  bool get isOfflineMode =>
      forbidsNetworkEgress || _heartbeat.offlineOnly;
  String get subtleBannerLabel => _active.subtleBannerLabel;

  Future<void> bootstrap() async {
    final dir = _vaultDir;
    if (dir == null) {
      await _persist();
      return;
    }
    final loaded =
        await SgpLawSnapshotVault.load(directory: dir, cipher: _cipher);
    if (loaded != null) {
      _active = loaded;
    } else {
      await _persist();
    }
  }

  /// 원격 시도 — 실패/1.5초 초과 시 에러 화면 없이 잔상 Seamless 유지.
  Future<SgpLawSnapshot> syncOrResidual() async {
    if (forbidsNetworkEgress) {
      _heartbeat.offlineOnly = true;
      return _active;
    }
    final next = await _heartbeat.guard(
      remote: () => _remote.fetchLatest(timeout: _heartbeat.timeout),
      localFallback: () => _active,
    );
    if (!_heartbeat.offlineOnly) {
      _active = next;
      await _persist();
    }
    return _active;
  }

  /// 현장 텍스트 → 계층 추출 (항상 로컬 추출 + 잔상 서식 결합).
  HierarchicalLawSet extractFromFieldText(String text) {
    final extracted = SgpLawExtractor.extract(text);
    _active = SgpLawSnapshot(
      lastSuccessfulSyncTime: _active.lastSuccessfulSyncTime,
      lawSet: extracted,
      summaryTrialForms: _active.summaryTrialForms.isEmpty
          ? SummaryTrialFormCatalog.build()
          : _active.summaryTrialForms,
      version: _active.version,
      source: _active.source,
    );
    return extracted;
  }

  /// Seamless 잔상 조회 (에러 UI 없음) — 호출 지연 최소화.
  SgpLawSnapshot residualNow() => _active;

  Future<void> _persist() async {
    final dir = _vaultDir;
    if (dir == null) return;
    await SgpLawSnapshotVault.persist(
      _active,
      directory: dir,
      cipher: _cipher,
    );
  }
}
