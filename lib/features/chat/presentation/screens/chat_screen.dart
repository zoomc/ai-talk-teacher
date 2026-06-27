import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../data/chat_repository.dart';
import '../../data/llm_service.dart';
import '../../data/stt_service.dart';
import '../../data/tts_service.dart';
import '../../data/recording_service.dart';
import '../../data/tts_playback_service.dart';
import '../../domain/chat_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RecordingService _recordingService = RecordingService();
  final TtsPlaybackService _ttsPlaybackService = TtsPlaybackService();

  bool _isRecording = false;
  bool _isLoading = false;
  String? _playingMessageId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingService.dispose();
    _ttsPlaybackService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSessionOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Character area
          Container(
            height: 200,
            margin: const EdgeInsets.all(AppSpacing.md),
            child: GlassCard(
              glowColor: AppColors.accentPrimary,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // AI Avatar placeholder
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'AI Tutor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    StatusPill(
                      text: _isRecording ? 'Listening...' : _isLoading ? 'Thinking...' : 'Ready',
                      color: _isRecording ? AppColors.accentSecondary : _isLoading ? AppColors.accentPrimary : AppColors.success,
                      isActive: _isRecording || _isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Chat messages area
          Expanded(
            child: _ChatMessageList(
              sessionId: widget.sessionId,
              scrollController: _scrollController,
            ),
          ),

          // Input area
          _ChatInputBar(
            controller: _messageController,
            isRecording: _isRecording,
            onSend: _handleSend,
            onRecordToggle: _handleRecordToggle,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    _messageController.clear();

    final repo = ref.read(chatRepoProvider);
    final message = ChatMessage(
      sessionId: widget.sessionId,
      role: MessageRole.user,
      content: text,
    );
    await repo.saveMessage(message);

    // Call LLM API
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final llmProfile = await profileRepo.getActiveLlmProfile();

      if (llmProfile == null) {
        throw Exception('No LLM profile configured. Please set up your AI service first.');
      }

      // Get chat history
      final history = await repo.getMessages(widget.sessionId);

      // Get scenario system prompt
      final session = await repo.getSession(widget.sessionId);
      String systemPrompt = 'You are a friendly English tutor. Have a natural conversation with the student. Correct their errors naturally.';

      if (session?.scenarioId != null) {
        final scenario = await repo.getScenario(session!.scenarioId!);
        if (scenario != null) {
          systemPrompt = scenario.systemPrompt;
        }
      }

      // Call LLM
      final llmService = LlmService(llmProfile);
      final response = await llmService.sendMessage(
        history: history,
        systemPrompt: systemPrompt,
        userMessage: text,
      );

      // Save AI response
      final aiResponse = ChatMessage(
        sessionId: widget.sessionId,
        role: MessageRole.assistant,
        content: response.content,
      );
      await repo.saveMessage(aiResponse);

      // Save corrections
      for (final correction in response.corrections) {
        await repo.saveCorrection(correction.copyWith(
          messageId: aiResponse.id,
          sessionId: widget.sessionId,
        ));
      }

      // Refresh UI
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRecordToggle() async {
    if (_isRecording) {
      // Stop recording and transcribe
      setState(() => _isRecording = false);

      try {
        final audioData = await _recordingService.stopRecording();
        if (audioData == null || audioData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No audio recorded')),
          );
          return;
        }

        setState(() => _isLoading = true);

        // Get STT profile
        final profileRepo = ref.read(profileRepoProvider);
        final sttProfile = await profileRepo.getActiveSttProfile();

        if (sttProfile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please configure STT service first')),
          );
          return;
        }

        // Transcribe audio
        final sttService = SttService(sttProfile);
        final transcribedText = await sttService.transcribe(audioData);

        if (transcribedText.isNotEmpty) {
          _messageController.text = transcribedText;
          // Auto-send the transcribed message
          await _handleSend();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Start recording
      try {
        await _recordingService.startRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot start recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _playTts(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      // Stop playing
      await _ttsPlaybackService.stop();
      setState(() => _playingMessageId = null);
      return;
    }

    try {
      setState(() => _playingMessageId = messageId);

      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();

      if (ttsProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please configure TTS service first')),
        );
        setState(() => _playingMessageId = null);
        return;
      }

      final ttsService = TtsService(ttsProfile);
      final audioBytes = await ttsService.synthesize(text);

      await _ttsPlaybackService.playAudio(audioBytes);

      // Listen for completion
      _ttsPlaybackService.player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _playingMessageId = null);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS error: ${e.toString()}')),
      );
      setState(() => _playingMessageId = null);
    }
  }

  void _showSessionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive, color: AppColors.textSecondary),
              title: const Text('Archive Session'),
              onTap: () async {
                final repo = ref.read(chatRepoProvider);
                await repo.archiveSession(widget.sessionId);
                if (context.mounted) {
                  Navigator.pop(context);
                  context.go('/');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete Session', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageList extends ConsumerWidget {
  final String sessionId;
  final ScrollController scrollController;

  const _ChatMessageList({
    required this.sessionId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(_messagesProvider(sessionId));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Start a conversation!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Type a message or press the mic button',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isUser = msg.role == MessageRole.user;
            return _ChatBubble(
              message: msg.content,
              isUser: isUser,
              isPlaying: false,
              onPlayTts: isUser ? null : () {},
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

final _messagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, sessionId) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getMessages(sessionId);
});

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isPlaying;
  final VoidCallback? onPlayTts;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    this.isPlaying = false,
    this.onPlayTts,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.bubbleUser : AppColors.bubbleAi,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.accentSecondary.withValues(alpha: 0.2)
                : AppColors.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!isUser && onPlayTts != null) ...[
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: onPlayTts,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.stop_circle : Icons.play_circle,
                      color: AppColors.accentSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPlaying ? 'Stop' : 'Listen',
                      style: TextStyle(
                        color: AppColors.accentSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onRecordToggle;

  const _ChatInputBar({
    required this.controller,
    required this.isRecording,
    required this.onSend,
    required this.onRecordToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        children: [
          // Record button
          GestureDetector(
            onLongPressStart: (_) => onRecordToggle(),
            onLongPressEnd: (_) => onRecordToggle(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? AppColors.error : AppColors.accentSecondary,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? AppColors.error : AppColors.accentSecondary).withValues(alpha: 0.3),
                    blurRadius: isRecording ? 20 : 10,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Send button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientPrimary,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
