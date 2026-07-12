/// S7-D — 민원 노드 JSON 로더 (Flutter assets).
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'sgp_civil_complaint_data.dart';

abstract final class SgpCivilComplaintLoader {
  static const assetPath = 'assets/data/civil_complaint_nodes.json';

  static CivilComplaintNodePack? _cached;

  static Future<CivilComplaintNodePack> loadFromAssets() async {
    if (_cached != null) return _cached!;
    final json = await rootBundle.loadString(assetPath);
    _cached = parseFromJson(json);
    return _cached!;
  }

  static CivilComplaintNodePack parseFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return CivilComplaintNodePack.fromJson(map);
  }

  static void resetCache() => _cached = null;
}
