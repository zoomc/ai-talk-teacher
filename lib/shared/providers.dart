import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/chat/data/chat_repository.dart';

final profileRepoProvider = Provider((ref) => ProfileRepository());
final chatRepoProvider = Provider((ref) => ChatRepository());

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
