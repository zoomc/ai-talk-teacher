import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/chat/data/chat_repository.dart';

final profileRepoProvider = Provider((ref) => ProfileRepository());
final chatRepoProvider = Provider((ref) => ChatRepository());
