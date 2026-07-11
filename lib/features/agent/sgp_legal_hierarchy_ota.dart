/// Sprint S5 — 위계 시드 OTA (판례 OTA와 분리 채널).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'sgp_legal_compliance.dart';
import 'sgp_legal_hierarchy.dart';

/// legal_hierarchy 시드 OTA — LV1~8 노드 패치 (판례 OTA와 별도).
class SgpLegalHierarchyOta {
  SgpLegalHierarchyOta._();
  static final SgpLegalHierarchyOta instance = SgpLegalHierarchyOta._();

  static const assetPath = SgpLegalHierarchyRegistry.assetPath;
  static const patchFileName = 'legal_hierarchy_patch.json';

  /// 원격 패치 URL (공식 채널 승인 전 비활성).
  static const remotePatchUrl =
      'https://raw.githubusercontent.com/sgp-agent/patches/main/legal_hierarchy_seed.json';

  String? _lastRefreshStatus;

  String? get lastRefreshStatus => _lastRefreshStatus;

  Future<void> initialize({required Future<String> Function() loadAsset}) async {
    if (SgpLegalHierarchyRegistry.instance.isLoaded) return;
    await _loadRegistry(loadAsset);
    unawaited(refreshInBackground(loadAsset));
  }

  Future<void> refreshInBackground(Future<String> Function() loadAsset) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$patchFileName');

      if (kEnableLegalHierarchyOta) {
        try {
          final response = await http
              .get(Uri.parse(remotePatchUrl))
              .timeout(const Duration(seconds: 12));
          if (response.statusCode == 200 && _verifySignature(response)) {
            final body = response.body;
            if (_isValidNodeList(body)) {
              await localFile.writeAsString(body);
              SgpLegalHierarchyRegistry.instance.loadFromJson(body);
              _lastRefreshStatus = '위계 OTA (${SgpLegalHierarchyRegistry.instance.allNodes.length}노드)';
              return;
            }
          }
        } catch (_) {
          // 네트워크 불가 — 로컬·자산 유지
        }
      }

      if (await localFile.exists()) {
        final local = await localFile.readAsString();
        SgpLegalHierarchyRegistry.instance.loadFromJson(local);
        _lastRefreshStatus = '위계 로컬 캐시 (${SgpLegalHierarchyRegistry.instance.allNodes.length}노드)';
      } else {
        _lastRefreshStatus = '위계 번들 (${SgpLegalHierarchyRegistry.instance.allNodes.length}노드)';
      }
    } catch (e) {
      _lastRefreshStatus = '위계 OTA 스킵: $e';
    }
  }

  Future<void> _loadRegistry(Future<String> Function() loadAsset) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$patchFileName');
      if (await localFile.exists()) {
        SgpLegalHierarchyRegistry.instance.loadFromJson(await localFile.readAsString());
        _lastRefreshStatus = '위계 로컬 캐시';
        return;
      }
    } catch (_) {}

    final asset = await loadAsset();
    SgpLegalHierarchyRegistry.instance.loadFromJson(asset);
    _lastRefreshStatus = '위계 번들';
  }

  bool _isValidNodeList(String source) {
    try {
      final list = jsonDecode(source) as List<dynamic>;
      if (list.isEmpty) return false;
      LegalHierarchyNode.fromJson(list.first as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// X-SGP-Signature: sha256= hex 헤더 검증 (PoC — 공식 키 배포 전 optional).
  bool _verifySignature(http.Response response) {
    final expected = kLegalHierarchyOtaPublicSha256;
    if (expected == null || expected.isEmpty) return true;

    final header = response.headers['x-sgp-signature'];
    if (header == null || !header.startsWith('sha256=')) return false;
    final digest = sha256.convert(utf8.encode(response.body)).toString();
    return header.substring(7) == digest && digest == expected;
  }
}

/// 공식 패치 본문 SHA256 (배포 시 설정). null이면 서명 검증 생략(PoC).
const String? kLegalHierarchyOtaPublicSha256 = null;
