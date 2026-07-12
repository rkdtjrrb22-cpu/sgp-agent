/// S11 — 글래스모피즘 현장/내근 모드 토글.
library;

import 'package:flutter/material.dart';

import '../sgp_glass_skin.dart';
import '../sgp_operational_mode.dart';
import '../sgp_app_theme.dart';

class SgpModeToggleButton extends StatelessWidget {
  const SgpModeToggleButton({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final SgpOperationalMode mode;
  final ValueChanged<SgpOperationalMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SgpGlassSkinCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: SgpOperationalMode.field.displayLabel,
              icon: SgpOperationalMode.field.icon,
              selected: mode == SgpOperationalMode.field,
              accent: SgpAppTheme.accent,
              onTap: () => onChanged(SgpOperationalMode.field),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeChip(
              label: SgpOperationalMode.investigation.displayLabel,
              icon: SgpOperationalMode.investigation.icon,
              selected: mode == SgpOperationalMode.investigation,
              accent: SgpAppTheme.error,
              onTap: () => onChanged(SgpOperationalMode.investigation),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : SgpAppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? accent : SgpAppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
