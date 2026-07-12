/// S7-A — 5단계 물리력 시연 asset 로더.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

export 'sgp_demo_force_scenarios_data.dart';

import 'sgp_demo_force_scenarios_data.dart';

abstract final class SgpDemoForceScenarioLoader {
  static const assetPath = 'assets/data/demo_force_scenarios.json';

  static Future<SgpDemoForceScenarioPack> load({String? assetPath}) async {
    final json = await rootBundle.loadString(
      assetPath ?? SgpDemoForceScenarioLoader.assetPath,
    );
    return SgpDemoForceScenarioPack.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }
}
