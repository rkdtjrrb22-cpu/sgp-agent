/// 최신 판례·법 감정 트렌드 OTA 갱신 (경량 벡터 매칭).
library;

import 'dart:convert';
import 'dart:io';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 사법부 트렌드 레코드.
class CourtPrecedentTrend {
  const CourtPrecedentTrend({
    required this.id,
    required this.trend,
    required this.holding,
    required this.weightBoost,
    required this.triggers,
    required this.appliesTo,
  });

  final String id;
  final String trend;
  final String holding;
  final double weightBoost;
  final List<String> triggers;
  final List<String> appliesTo;

  factory CourtPrecedentTrend.fromJson(Map<String, dynamic> json) {
    return CourtPrecedentTrend(
      id: json['id'] as String,
      trend: json['trend'] as String,
      holding: json['holding'] as String,
      weightBoost: (json['weightBoost'] as num).toDouble(),
      triggers: (json['triggers'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      appliesTo: (json['appliesTo'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trend': trend,
        'holding': holding,
        'weightBoost': weightBoost,
        'triggers': triggers,
        'appliesTo': appliesTo,
      };
}

/// OTA 판례 트렌드 DB — 앱 기동 시 백그라운드 갱신.
class SgpCourtPrecedentsOta {
  SgpCourtPrecedentsOta._();
  static final SgpCourtPrecedentsOta instance = SgpCourtPrecedentsOta._();

  static const assetPath = 'assets/data/court_precedents.json';

  /// 원격 패치 URL (미배포 시 자산 폴백).
  static const remotePatchUrl =
      'https://raw.githubusercontent.com/sgp-agent/patches/main/court_precedents.json';

  List<CourtPrecedentTrend> _trends = [];
  bool _loaded = false;
  String? _lastRefreshStatus;

  List<CourtPrecedentTrend> get activeTrends => List.unmodifiable(_trends);
  bool get isLoaded => _loaded;
  String? get lastRefreshStatus => _lastRefreshStatus;

  Future<void> initialize() async {
    if (_loaded) return;
    await _loadFromDiskOrAsset();
    _loaded = true;
    unawaited(refreshInBackground());
  }

  Future<void> refreshInBackground() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/court_precedents_patch.json');

      try {
        final response = await http
            .get(Uri.parse(remotePatchUrl))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            await localFile.writeAsString(response.body);
            _trends = decoded
                .map((e) => CourtPrecedentTrend.fromJson(e as Map<String, dynamic>))
                .toList();
            _lastRefreshStatus = 'OTA 패치 적용 (${_trends.length}건)';
            return;
          }
        }
      } catch (_) {
        // 네트워크 불가 — 로컬·자산 유지
      }

      if (await localFile.exists()) {
        final local = await localFile.readAsString();
        _trends = parseTrendsJson(local);
        _lastRefreshStatus = '로컬 캐시 (${_trends.length}건)';
      } else {
        _lastRefreshStatus = '번들 자산 (${_trends.length}건)';
      }
    } catch (e) {
      _lastRefreshStatus = 'OTA 스킵: $e';
    }
  }

  Future<void> _loadFromDiskOrAsset() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/court_precedents_patch.json');
      if (await localFile.exists()) {
        _trends = parseTrendsJson(await localFile.readAsString());
        _lastRefreshStatus = '로컬 캐시';
        return;
      }
    } catch (_) {}

    final asset = await rootBundle.loadString(assetPath);
    _trends = parseTrendsJson(asset);
    _lastRefreshStatus = '번들 자산';
  }

  List<CourtPrecedentTrend> parseTrendsJson(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list.map((e) => CourtPrecedentTrend.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 텍스트·사건 유형에 매칭되는 트렌드.
  List<CourtPrecedentTrend> matchTrends({
    required String text,
    required String incidentScope,
  }) {
    final matched = <CourtPrecedentTrend>[];
    for (final t in _trends) {
      if (!t.appliesTo.contains(incidentScope) && !t.appliesTo.contains('general')) {
        continue;
      }
      if (t.triggers.any((kw) => text.contains(kw))) {
        matched.add(t);
      }
    }
    return matched;
  }
}
