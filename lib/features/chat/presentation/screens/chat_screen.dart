import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../data/chat_repository.dart';
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
  bool _isRecording = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

    // TODO: Call LLM API for response
    // For now, simulate AI response
    await Future.delayed(const Duration(seconds: 1));
    final aiResponse = ChatMessage(
      sessionId: widget.sessionId,
      role: MessageRole.assistant,
      content: 'I understand you said "$text". Let me help you practice! Can you tell me more about that?',
    );
    await repo.saveMessage(aiResponse);

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _handleRecordToggle() {
    setState(() => _isRecording = !_isRecording);
    // TODO: Implement actual STT recording
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

  const _ChatBubble({required this.message, required this.isUser});

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
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
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
