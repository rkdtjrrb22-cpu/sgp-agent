/// S11 — 현장 외근 / 내근 수사 운용 모드.
library;

import 'package:flutter/material.dart' show IconData, Icons;

/// 앱 운용 모드: 무전 입력·패널 레이아웃이 다이내믹 전환된다.
enum SgpOperationalMode {
  /// 현장 외근 — 무전 STT·물리력·민원 가이드 중심.
  field,

  /// 내근 수사 — 사법 리갈 어시스트·48시간 인치 타임라인 중심.
  investigation,
}

extension SgpOperationalModeLabels on SgpOperationalMode {
  String get displayLabel => switch (this) {
        SgpOperationalMode.field => '현장 외근',
        SgpOperationalMode.investigation => '내근 수사',
      };

  String get shortLabel => switch (this) {
        SgpOperationalMode.field => '외근',
        SgpOperationalMode.investigation => '내근',
      };

  String get sttSectionTitle => switch (this) {
        SgpOperationalMode.field => '무전 STT 원문',
        SgpOperationalMode.investigation => '사법 리갈 어시스트',
      };

  String get sttHint => switch (this) {
        SgpOperationalMode.field => '현장 무전·진술 텍스트를 입력하거나 마이크로 수신…',
        SgpOperationalMode.investigation =>
          '조서·진술 녹취록·영장 신청서 초안을 입력하거나 붙여넣기…',
      };

  IconData get icon => switch (this) {
        SgpOperationalMode.field => Icons.local_police_outlined,
        SgpOperationalMode.investigation => Icons.gavel_outlined,
      };
}
