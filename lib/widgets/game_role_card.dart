import 'package:flutter/material.dart';

import '../core/constants/app_theme.dart';
import '../core/constants/role_visuals.dart';

/// Shared role card for the create-game role picker and the role reveal screen.
///
/// The background is always a neutral surface — only the border, the emoji chip
/// and the role name carry the role color (design rule: no per-role backgrounds).
class GameRoleCard extends StatelessWidget {
  /// Backend role id (e.g. 'VAMPIRE'). Ignored when [roleVisual] is given.
  final String? roleId;

  /// Pre-resolved visual. Takes precedence over [roleId].
  final RoleVisual? roleVisual;

  final bool selected;
  final VoidCallback? onTap;

  /// Dense single-line layout (lists, pickers). Large hero layout when false.
  final bool compact;

  /// Show a check mark when selected (picker use case).
  final bool showSelectionCheck;

  /// Optional trailing widget (e.g. a count stepper). Overrides the check mark.
  final Widget? trailing;

  const GameRoleCard({
    super.key,
    this.roleId,
    this.roleVisual,
    this.selected = false,
    this.onTap,
    this.compact = true,
    this.showSelectionCheck = true,
    this.trailing,
  }) : assert(roleId != null || roleVisual != null,
            'Provide roleId or roleVisual');

  @override
  Widget build(BuildContext context) {
    final visual = roleVisual ?? RoleVisuals.of(roleId);
    final borderColor = selected ? visual.color : AppColors.border;

    // Only tappable (picker) cards get the selection pop; static hero cards
    // (role reveal, elimination) are always "selected" and must not scale.
    final pop = selected && onTap != null;

    return AnimatedScale(
      scale: pop ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.cardElevated : AppColors.card,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
          boxShadow:
              selected ? AppShadows.accentGlow(visual.color) : AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.lgAll,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
              child: compact ? _buildCompact(visual) : _buildLarge(visual),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(RoleVisual visual) {
    return Row(
      children: [
        _emojiChip(visual, 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                visual.displayNameTr,
                style: AppTextStyles.title.copyWith(color: visual.color),
              ),
              if (visual.descriptionTr.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  visual.descriptionTr,
                  style: AppTextStyles.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (showSelectionCheck)
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 22,
            color: selected ? visual.color : AppColors.border,
          ),
      ],
    );
  }

  Widget _buildLarge(RoleVisual visual) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _emojiChip(visual, 88),
        const SizedBox(height: AppSpacing.lg),
        Text(
          visual.displayNameTr.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.displayLarge.copyWith(color: visual.color),
        ),
        if (visual.descriptionTr.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            visual.descriptionTr,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(height: AppSpacing.lg),
          trailing!,
        ],
      ],
    );
  }

  Widget _emojiChip(RoleVisual visual, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: visual.color.withOpacity(0.6)),
      ),
      child: Text(visual.emoji, style: TextStyle(fontSize: size * 0.45)),
    );
  }
}
