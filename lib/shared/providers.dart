import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/project_space/data/project_repository.dart';

final profileRepoProvider = Provider((ref) => ProfileRepository());
final chatRepoProvider = Provider((ref) => ChatRepository());
final projectRepoProvider = Provider((ref) => ProjectRepository());

/// Global theme mode state. Initialized in main() from the persisted
/// `theme` user setting (via ProviderScope.overrides) so the very first
/// frame uses the user's saved preference. The settings screen updates
/// this provider when the user picks a new theme — MaterialApp rebuilds
/// immediately, no app restart needed (P1-8).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Global interface-locale state. Initialized in main() with the
/// resolution: persisted `app_language` setting > browser language
/// (auto-detected on web) > `AppLocale.zh` (spec: "如果检测不到就是默认
/// 中文"). The settings screen updates this provider when the user picks
/// a language — MaterialApp rebuilds immediately with the new locale.
final localeProvider = StateProvider<AppLocale>((ref) => AppLocale.zh);

/// Phase-1 P0 #8 — global low-bandwidth mode. When true, heavy visual
/// effects (3D Live2D avatar, ambient ripples, etc.) are suppressed to
/// save data + battery on metered / slow connections. Initialized in
/// main() from the persisted `low_bandwidth` setting so the first frame
/// already respects the user's choice; the settings screen flips this
/// and the chat panel rebuilds to drop the avatar.
final lowBandwidthProvider = StateProvider<bool>((ref) => false);
