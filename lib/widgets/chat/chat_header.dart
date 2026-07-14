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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        tooltip: l.t('chat.back_home'),
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: onBack,
      ),
      title: Row(
        children: [
          Text(tutorAvatar, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(tutorName, overflow: TextOverflow.ellipsis),
          ),
        ],
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
    final color = switch (state) {
      CharacterState.idle => AppColors.textMuted,
      CharacterState.listening => AppColors.accentSecondary,
      CharacterState.thinking => AppColors.accentPrimary,
      CharacterState.speaking => AppColors.success,
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
