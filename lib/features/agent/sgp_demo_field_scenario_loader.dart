/// 현장 시연 Mock — asset 번들 로더.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'sgp_demo_field_scenario_data.dart';

abstract final class SgpDemoFieldScenarioLoader {
  static const assetPath = 'assets/data/demo_field_scenario.json';

  static Future<SgpDemoFieldScenario> load({String? assetPath}) async {
    final json = await rootBundle.loadString(
      assetPath ?? SgpDemoFieldScenarioLoader.assetPath,
    );
    return SgpDemoFieldScenario.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }
}
