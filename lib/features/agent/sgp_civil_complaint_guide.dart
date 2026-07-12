/// S7-D / S8-UI — 종합 민원 가이드 화면·패널 진입점.
library;

export 'panels/sgp_civil_complaint_guide_panel.dart';

import 'package:flutter/material.dart';

import 'sgp_app_theme.dart';
import 'sgp_civil_complaint_data.dart';
import 'panels/sgp_civil_complaint_guide_panel.dart';

/// 종합 민원 가이드 전체 화면 — 엄지존 하단 고정.
class SgpCivilComplaintGuideScreen extends StatelessWidget {
  const SgpCivilComplaintGuideScreen({
    super.key,
    required this.route,
  });

  final CivilComplaintRouteResult route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgpCivilGuideColors.deepNight,
      appBar: AppBar(
        backgroundColor: SgpCivilGuideColors.spaceGray,
        foregroundColor: SgpCivilGuideColors.pureWhite,
        elevation: 0,
        title: const Text(
          '종합 민원 가이드',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_rounded, size: 26),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SgpCivilComplaintGuidePanel(
                route: route,
                embedded: false,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: SgpCivilGuideColors.spaceGray,
              border: Border(
                top: BorderSide(
                  color: SgpCivilGuideColors.neonCyan.withValues(alpha: 0.25),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SgpCivilComplaintThumbActions(type: route.type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
