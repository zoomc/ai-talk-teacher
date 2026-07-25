/// Chat header (AppBar) widget, extracted from chat_screen.dart as part of
/// P1 task 2.
library;

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/virtual_character.dart';

/// Chat screen AppBar with tutor identity, status dot, and action buttons.
class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  final String tutorName;
  final String tutorAvatar;
  final CharacterState characterState;
  final bool showStatusDot;
  final VoidCallback onBack;
  final VoidCallback onPickTutor;
  final VoidCallback onMoreOptions;

  const ChatHeader({
    super.key,
    required this.tutorName,
    required this.tutorAvatar,
    required this.characterState,
    this.showStatusDot = false,
    required this.onBack,
    required this.onPickTutor,
    required this.onMoreOptions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AppBar(
      leading: IconButton(
        tooltip: l.t('chat.back_home'),
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: onBack,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isLight
                ? AppColors.lightBgTertiary
                : AppColors.bgTertiary,
            child: Text(
              tutorAvatar,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              tutorName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: isLight
              ? AppColors.lightGlassBorder
              : AppColors.glassBorder,
        ),
      ),
      actions: [
        if (showStatusDot)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _AppBarStatusDot(state: characterState),
          ),
        IconButton(
          tooltip: l.t('chat.pick_tutor'),
          icon: const Icon(Icons.swap_horiz),
          onPressed: onPickTutor,
        ),
        IconButton(
          tooltip: l.t('chat.more_options'),
          icon: const Icon(Icons.more_vert),
          onPressed: onMoreOptions,
        ),
      ],
    );
  }
}

/// Small coloured dot showing the tutor's listening/thinking/speaking state.
/// Shown in the AppBar when the character panel is hidden (low-bandwidth or
/// short landscape).
class _AppBarStatusDot extends StatelessWidget {
  final CharacterState state;
  const _AppBarStatusDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = switch (state) {
      CharacterState.idle =>
        isLight ? AppColors.lightTextMuted : AppColors.textMuted,
      CharacterState.listening =>
        isLight ? AppColors.lightAccentSecondary : AppColors.accentSecondary,
      CharacterState.thinking =>
        isLight ? AppColors.lightAccentPrimary : AppColors.accentPrimary,
      CharacterState.speaking =>
        isLight ? AppColors.lightSuccess : AppColors.success,
    };
    return Semantics(
      liveRegion: true,
      label: switch (state) {
        CharacterState.idle => l.t('chat.ready'),
        CharacterState.listening => l.t('chat.listening'),
        CharacterState.thinking => l.t('chat.thinking'),
        CharacterState.speaking => l.t('chat.speaking'),
      },
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: state != CharacterState.idle
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }
}
