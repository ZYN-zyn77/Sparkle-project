import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparkle/data/models/chat_message_model.dart';
import 'package:sparkle/data/repositories/chat_repository.dart';
import 'package:sparkle/presentation/providers/task_chat_provider.dart';
import 'package:sparkle/presentation/widgets/task/task_chat_panel.dart';

class FakeTaskChatNotifier extends TaskChatNotifier {
  FakeTaskChatNotifier() : super(ChatRepository(Dio()), 'task-1');

  int retryCalls = 0;

  void triggerError() {
    state = state.copyWith(error: '发送失败，可重试', lastUserText: 'hello');
  }

  @override
  Future<void> sendMessage(String text, {bool addUserMessage = true}) async {
    state = state.copyWith(
      error: '发送失败，可重试',
      lastUserText: text,
      messages: [
        ...state.messages,
        ChatMessageModel(
          id: 'local',
          userId: 'user',
          role: MessageRole.user,
          content: text,
          createdAt: DateTime(2024),
          taskId: taskId,
          conversationId: 'test',
        ),
      ],
    );
  }

  @override
  Future<void> retryLastSend() async {
    retryCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows error bar and allows retry', (tester) async {
    final notifier = FakeTaskChatNotifier();
    final container = ProviderContainer(
      overrides: [
        taskChatProvider.overrideWith((ref, taskId) => notifier),
      ],
    );

    notifier.triggerError();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskChatPanel(taskId: 'task-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('发送失败，可重试'), findsOneWidget);
    expect(find.byKey(const Key('taskChatRetryButton')), findsOneWidget);
    expect(find.byKey(const Key('taskChatCopyButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('taskChatRetryButton')));
    await tester.pump();

    expect(notifier.retryCalls, 1);

    container.dispose();
  });
}
