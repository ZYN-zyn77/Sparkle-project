import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/data/repositories/omnibar_repository.dart';
import 'package:sparkle/presentation/providers/task_provider.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/providers/cognitive_provider.dart';

/// OmniBar - Project Cockpit Floating Dock
class OmniBar extends ConsumerStatefulWidget {
  const OmniBar({super.key});

  @override
  ConsumerState<OmniBar> createState() => _OmniBarState();
}

class _OmniBarState extends ConsumerState<OmniBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _intentType; // 'TASK', 'CAPSULE', 'CHAT'

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text.toLowerCase();
    String? newIntent;
    if (text.contains('提醒') || text.contains('做') || text.contains('任务') || text.contains('背')) {
      newIntent = 'TASK';
    } else if (text.contains('烦') || text.contains('想') || text.contains('！') || text.contains('好')) {
      newIntent = 'CAPSULE';
    } else if (text.length > 8) {
      newIntent = 'CHAT';
    }

    if (newIntent != _intentType) {
      setState(() => _intentType = newIntent);
      if (newIntent != null) {
        _glowController.forward(from: 0);
      } else {
        _glowController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(omniBarRepositoryProvider).dispatch(text);
      if (mounted) {
        await _handleResult(result);
        _controller.clear();
        _focusNode.unfocus();
        setState(() => _intentType = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e'), backgroundColor: AppDesignTokens.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResult(Map<String, dynamic> result) async {
    final type = result['action_type'] as String?;
    switch (type) {
      case 'CHAT': context.push('/chat'); break;
      case 'TASK':
        await ref.read(taskListProvider.notifier).refreshTasks();
        await ref.read(dashboardProvider.notifier).refresh();
        break;
      case 'CAPSULE':
        await ref.read(cognitiveProvider.notifier).loadFragments();
        await ref.read(dashboardProvider.notifier).refresh();
        break;
    }
  }

  Color _getIntentColor() {
    switch (_intentType) {
      case 'TASK': return Colors.greenAccent;
      case 'CAPSULE': return Colors.purpleAccent;
      case 'CHAT': return Colors.blueAccent;
      default: return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final color = _getIntentColor();
        return Container(
          height: 50, // Slightly more compact
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: color.withOpacity(0.2 + (_glowAnimation.value * 0.4)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '刚才为什么分心了？',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: Icon(
                    _intentType == 'CHAT' ? Icons.auto_awesome : Icons.arrow_upward_rounded,
                    color: _intentType != null ? color : Colors.white70,
                    size: 18,
                  ),
                  onPressed: _submit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        );
      },
    );
  }
}
