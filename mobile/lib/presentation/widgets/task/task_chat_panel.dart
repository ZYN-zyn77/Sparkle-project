import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_system.dart';
import 'package:sparkle/data/models/chat_message_model.dart';
import 'package:sparkle/presentation/providers/task_chat_provider.dart';
import 'package:sparkle/presentation/widgets/chat/chat_bubble.dart';

class TaskChatPanel extends ConsumerStatefulWidget {

  const TaskChatPanel({
    required this.taskId, super.key,
  });
  final String taskId;

  @override
  ConsumerState<TaskChatPanel> createState() => _TaskChatPanelState();
}

class _TaskChatPanelState extends ConsumerState<TaskChatPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _isExpanded = false;

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(taskChatProvider(widget.taskId).notifier).sendMessage(text);
      _controller.clear();
      if (!_isExpanded) {
        setState(() => _isExpanded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(taskChatProvider(widget.taskId));
    final messages = chatState.messages;
    final lastMessage = messages.isNotEmpty ? messages.last : null;
    final errorText = chatState.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: DS.brandPrimaryConst,
        borderRadius: DS.borderRadius16,
        boxShadow: DS.shadowMd,
        border: Border.all(color: DS.neutral200),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(DS.spacing12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DS.sm),
                    decoration: BoxDecoration(
                      gradient: DS.secondaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome, color: DS.brandPrimaryConst, size: 18),
                  ),
                  const SizedBox(width: DS.spacing12),
                  Text(
                    'AI 学习助手',
                    style: TextStyle(
                      fontWeight: DS.fontWeightBold,
                      color: DS.neutral900,
                    ),
                  ),
                  const Spacer(),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: DS.neutral500),
                ],
              ),
            ),
          ),
          
          if (!_isExpanded && lastMessage != null)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Text(
                 "${lastMessage.role == MessageRole.user ? '我' : 'AI'}: ${lastMessage.content}",
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
                 style: TextStyle(color: DS.neutral600, fontSize: 12),
               ),
             ),

          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              height: 300,
              color: DS.neutral50,
              child: messages.isEmpty 
                  ? Center(
                      child: Text(
                        '有问题尽管问我！', 
                        style: TextStyle(color: DS.neutral400),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(DS.lg),
                      itemCount: messages.length,
                      itemBuilder: (context, index) => ChatBubble(message: messages[index]),
                    ),
            ),
            if (errorText != null)
              Container(
                width: double.infinity,
                color: DS.error100,
                padding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.sm),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: DS.error500, size: 18),
                    const SizedBox(width: DS.sm),
                    Expanded(
                      child: Text(
                        '发送失败，可重试',
                        style: TextStyle(color: DS.error700, fontWeight: DS.fontWeightMedium),
                      ),
                    ),
                    TextButton(
                      key: const Key('taskChatRetryButton'),
                      onPressed: () => ref.read(taskChatProvider(widget.taskId).notifier).retryLastSend(),
                      child: const Text('重试'),
                    ),
                    if (chatState.lastUserText != null)
                      TextButton(
                        key: const Key('taskChatCopyButton'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: chatState.lastUserText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制上次发送内容')),
                          );
                        },
                        child: const Text('复制'),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(DS.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '输入问题...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  if (chatState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(DS.sm),
                      child: SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send, color: DS.primaryBase),
                      onPressed: _sendMessage,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
