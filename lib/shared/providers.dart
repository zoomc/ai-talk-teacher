import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
