import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/data/models/chat_message_model.dart';
import 'package:sparkle/data/repositories/chat_repository.dart';
import 'package:sparkle/presentation/providers/chat_provider.dart';

class TaskChatState {

  TaskChatState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.lastUserText,
  });
  final bool isLoading;
  final List<ChatMessageModel> messages;
  final String? error;
  final String? lastUserText;

  TaskChatState copyWith({
    bool? isLoading,
    List<ChatMessageModel>? messages,
    String? error,
    bool clearError = false,
    String? lastUserText,
  }) => TaskChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: clearError ? null : error ?? this.error,
      lastUserText: lastUserText ?? this.lastUserText,
    );
}

class TaskChatNotifier extends StateNotifier<TaskChatState> {

  TaskChatNotifier(this._repository, this.taskId) : super(TaskChatState());
  final ChatRepository _repository;
  final String taskId;
  String? _conversationId;

  Future<void> sendMessage(String text, {bool addUserMessage = true}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    // 1. Add user message
    final userMsg = ChatMessageModel(
      id: DateTime.now().toString(),
      userId: 'current_user',
      role: MessageRole.user,
      content: trimmedText,
      createdAt: DateTime.now(),
      taskId: taskId,
      conversationId: _conversationId ?? 'new',
    );

    state = state.copyWith(
      messages: addUserMessage ? [...state.messages, userMsg] : state.messages,
      isLoading: true,
      lastUserText: trimmedText,
      clearError: true,
    );

    try {
      // 2. Call API
      final response = await _repository.sendMessageToTask(taskId, trimmedText, _conversationId);
      
      _conversationId = response.conversationId;

      // 3. Add assistant message
      final aiMsg = ChatMessageModel(
        id: DateTime.now().toString(), // Should come from backend ideally
        userId: 'ai',
        role: MessageRole.assistant,
        content: response.message,
        createdAt: DateTime.now(),
        taskId: taskId,
        conversationId: _conversationId!,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '发送失败，可重试',
      );
    }
  }

  Future<void> retryLastSend() async {
    final lastMessage = state.lastUserText;
    if (lastMessage == null) return;

    await sendMessage(lastMessage, addUserMessage: false);
  }
}

final taskChatProvider = StateNotifierProvider.family<TaskChatNotifier, TaskChatState, String>((ref, taskId) {
  final repository = ref.watch(chatRepositoryProvider);
  return TaskChatNotifier(repository, taskId);
});
