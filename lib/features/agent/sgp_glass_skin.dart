/// S9 — 모던 고대비 글래스모피즘 스킨 (8% 화이트 + 네온 블루 그라디언트 테두리).
library;

import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class SgpGlassSkinColors {
  static const neonBlue = Color(0xFF00B0FF);
  static const neonBlueBright = Color(0xFF40C4FF);
  static const realBlack = Color(0xFF000000);
  static const glassFill = Color(0x14FFFFFF);
}

class SgpGlassSkinCard extends StatelessWidget {
  const SgpGlassSkinCard({
    super.key,
    required this.child,
    this.accent = SgpGlassSkinColors.neonBlue,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16,
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.55),
                SgpGlassSkinColors.neonBlueBright.withValues(alpha: 0.45),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                color: SgpGlassSkinColors.glassFill,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
