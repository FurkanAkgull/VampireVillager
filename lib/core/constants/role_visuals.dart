import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Presentation-only metadata for a backend role id.
///
/// Backend role ids stay English (VAMPIRE, VILLAGER, ...). This layer only maps
/// them to Turkish labels, an accent color and a single character icon.
class RoleVisual {
  final String displayNameTr;
  final Color color;
  final String emoji;
  final String descriptionTr;

  const RoleVisual({
    required this.displayNameTr,
    required this.color,
    required this.emoji,
    required this.descriptionTr,
  });
}

class RoleVisuals {
  const RoleVisuals._();

  static const RoleVisual unknown = RoleVisual(
    displayNameTr: 'Bilinmiyor',
    color: AppColors.textSecondary,
    emoji: '❓',
    descriptionTr: '',
  );

  static const Map<String, RoleVisual> byRoleId = {
    'VAMPIRE': RoleVisual(
      displayNameTr: 'Vampir',
      color: AppColors.vampire,
      emoji: '🧛',
      descriptionTr: 'Geceleri avlan.',
    ),
    'VILLAGER': RoleVisual(
      displayNameTr: 'Köylü',
      color: AppColors.villager,
      emoji: '👤',
      descriptionTr: 'Köyü koru, gerçeği bul.',
    ),
    'DOCTOR': RoleVisual(
      displayNameTr: 'Doktor',
      color: AppColors.doctor,
      emoji: '⚕',
      descriptionTr: 'Bu gece birini koru.',
    ),
    'MEDIUM': RoleVisual(
      displayNameTr: 'Medyum',
      color: AppColors.medium,
      emoji: '🔮',
      descriptionTr: 'Ölülerin sırlarını duy.',
    ),
    'CRAZY': RoleVisual(
      displayNameTr: 'Deli',
      color: AppColors.crazy,
      emoji: '🃏',
      descriptionTr: 'Aksiyonların bazen ters teper.',
    ),
    'JESTER': RoleVisual(
      displayNameTr: 'Jester',
      color: AppColors.jester,
      emoji: '🎭',
      descriptionTr: 'Elenerek kazanmaya çalış.',
    ),
    'SEER': RoleVisual(
      displayNameTr: 'Kâhin',
      color: AppColors.villagerLight,
      emoji: '👁',
      descriptionTr: 'Bir oyuncunun kimliğini gör.',
    ),
    'HUNTER': RoleVisual(
      displayNameTr: 'Avcı',
      color: AppColors.warning,
      emoji: '🏹',
      descriptionTr: 'Ölürken yanında birini götür.',
    ),
    'WITCH': RoleVisual(
      displayNameTr: 'Cadı',
      color: AppColors.medium,
      emoji: '🧪',
      descriptionTr: 'Bir can kurtar ya da bir can al.',
    ),
    'DETECTIVE': RoleVisual(
      displayNameTr: 'Dedektif',
      color: AppColors.villager,
      emoji: '🔍',
      descriptionTr: 'İzleri sür, suçluyu bul.',
    ),
    'BODYGUARD': RoleVisual(
      displayNameTr: 'Koruma',
      color: AppColors.success,
      emoji: '🛡',
      descriptionTr: 'Birinin önüne geç, onu koru.',
    ),
    'SILENCER': RoleVisual(
      displayNameTr: 'Susturucu',
      color: AppColors.vampireDark,
      emoji: '🤫',
      descriptionTr: 'Bir oyuncuyu bugün sustur.',
    ),
    'UNKNOWN': unknown,
  };

  /// Safe lookup: null / empty / unrecognised ids fall back to [unknown].
  static RoleVisual of(String? roleId) =>
      byRoleId[roleId?.toUpperCase()] ?? unknown;

  /// True when the role is actually revealed (not null / "UNKNOWN").
  static bool isRevealed(String? roleId) {
    if (roleId == null || roleId.isEmpty) return false;
    return roleId.toUpperCase() != 'UNKNOWN';
  }

  /// Ids that make sense to offer in the create-game role picker.
  static const List<String> selectableRoleIds = [
    'VAMPIRE',
    'VILLAGER',
    'DOCTOR',
    'MEDIUM',
    'SEER',
    'HUNTER',
    'WITCH',
    'DETECTIVE',
    'BODYGUARD',
    'SILENCER',
    'CRAZY',
    'JESTER',
  ];
}
