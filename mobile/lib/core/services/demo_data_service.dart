// ignore_for_file: use_setters_to_change_properties

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/features/chat/data/models/chat_message_model.dart';
import 'package:sparkle/features/knowledge/data/models/knowledge_detail_model.dart';
import 'package:sparkle/features/plan/data/models/plan_model.dart';
import 'package:sparkle/shared/entities/galaxy_model.dart';
import 'package:sparkle/shared/entities/task_model.dart';
import 'package:sparkle/shared/entities/user_model.dart';
import 'package:uuid/uuid.dart';

class DemoDataService {
  factory DemoDataService() => _instance;
  DemoDataService._internal();
  static bool isDemoMode = false;

  static final DemoDataService _instance = DemoDataService._internal();

  final _uuid = const Uuid();
  final _random = Random();

  String? _currentAvatarUrl;

  // --- User Data ---
  UserModel get demoUser => UserModel(
        id: 'CS_Sophomore_12345',
        username: 'AI_Learner_02',
        email: 'learner@sparkle.ai',
        nickname: 'AI_Learner_02',
        avatarUrl: _currentAvatarUrl ??
            'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_02',
        flameLevel: 15,
        flameBrightness: 0.85,
        depthPreference: 0.7,
        curiosityPreference: 0.8,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
        pushPreferences: PushPreferences(),
      );

  void updateDemoAvatar(String url) {
    _currentAvatarUrl = url;
  }

  // --- Task Data ---
  List<TaskModel> get demoTasks {
    final now = DateTime.now();
    return [
      TaskModel(
        id: _uuid.v4(),
        userId: 'CS_Sophomore_12345',
        title: '数据结构 - 链表实现',
        type: TaskType.learning,
        tags: ['CS', 'Data Structures', 'C++'],
        estimatedMinutes: 120,
        difficulty: 3,
        energyCost: 3,
        status: TaskStatus.pending,
        priority: 3, // High
        dueDate: now.add(const Duration(days: 45)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
      TaskModel(
        id: _uuid.v4(),
        userId: 'CS_Sophomore_12345',
        title: '离散数学 - 图论基础',
        type: TaskType.learning,
        tags: ['Math', 'Graph Theory'],
        estimatedMinutes: 90,
        difficulty: 4,
        energyCost: 4,
        status: TaskStatus.inProgress,
        priority: 2, // Medium
        dueDate: now.add(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
      TaskModel(
        id: _uuid.v4(),
        userId: 'CS_Sophomore_12345',
        title: '计算机系统 - CPU调度算法',
        type: TaskType.learning,
        tags: ['CS', 'OS'],
        estimatedMinutes: 60,
        difficulty: 3,
        energyCost: 2,
        status: TaskStatus.completed,
        priority: 1, // Low
        dueDate: now.subtract(const Duration(days: 3)),
        completedAt: now.subtract(const Duration(days: 3)),
        actualMinutes: 55,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      TaskModel(
        id: _uuid.v4(),
        userId: 'CS_Sophomore_12345',
        title: '数字电路 - 逻辑门实验',
        type: TaskType.training,
        tags: ['Hardware', 'Lab'],
        estimatedMinutes: 180,
        difficulty: 2,
        energyCost: 3,
        status: TaskStatus.pending,
        priority: 2,
        dueDate: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      ),
      TaskModel(
        id: _uuid.v4(),
        userId: 'CS_Sophomore_12345',
        title: '摄影技巧 - 光影构图学习',
        type: TaskType.learning,
        tags: ['Hobby', 'Photography'],
        estimatedMinutes: 45,
        difficulty: 1,
        energyCost: 1,
        status: TaskStatus.completed,
        priority: 1,
        dueDate: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(days: 1)),
        actualMinutes: 50,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now,
      ),
    ];
  }

  // --- Galaxy Data ---
  GalaxyGraphResponse get demoGalaxy {
    final nodes = <GalaxyNodeModel>[];

    // Core Subjects & Colors
    final subjects = ['数据结构', '离散数学', '计算机系统', '数字电路', '摄影', '文学'];
    final subjectColors = {
      '数据结构': '#4CAF50', // Green
      '离散数学': '#2196F3', // Blue
      '计算机系统': '#FFC107', // Amber
      '数字电路': '#9C27B0', // Purple
      '摄影': '#E91E63', // Pink
      '文学': '#795548', // Brown
    };

    // Generate ~500 nodes
    for (var i = 0; i < 500; i++) {
      final subject = subjects[i % subjects.length];
      final isCore = i < 20;
      final status = _determineNodeStatus(i);
      final isUnlocked = status != NodeStatus.locked;
      final mastery = status == NodeStatus.mastered
          ? 100
          : (status == NodeStatus.unlocked ? 30 : 0);

      String? parentId;
      if (!isCore) {
        parentId = 'node_${i % 20}';
      }

      nodes.add(
        GalaxyNodeModel(
          id: 'node_$i',
          name: isCore ? subject : '$subject - 知识点 ${i + 1}',
          importance: isCore ? 5 : _random.nextInt(3) + 1,
          sector: SectorEnum.values[i % SectorEnum.values.length],
          isUnlocked: isUnlocked,
          masteryScore: mastery,
          baseColor: subjectColors[subject],
          parentId: parentId,
        ),
      );
    }

    return GalaxyGraphResponse(
      nodes: nodes,
      userFlameIntensity: 0.85,
    );
  }

  // Helper enum for logic (internal use)
  NodeStatus _determineNodeStatus(int index) {
    if (index > 350) return NodeStatus.locked;
    if (index < 50) return NodeStatus.mastered;
    if (index < 130) return NodeStatus.review;
    return NodeStatus.unlocked;
  }

  /// Get demo node detail for a specific node ID
  KnowledgeDetailResponse getDemoNodeDetail(String nodeId) {
    // Parse node index from ID
    final indexStr = nodeId.replaceAll('node_', '');
    final index = int.tryParse(indexStr) ?? 0;

    final subjects = ['数据结构', '离散数学', '计算机系统', '数字电路', '摄影', '文学'];
    final subject = subjects[index % subjects.length];
    final isCore = index < 20;
    final status = _determineNodeStatus(index);

    // Determine sector based on index
    final sectorValues = [
      'COSMOS',
      'TECH',
      'ART',
      'CIVILIZATION',
      'LIFE',
      'WISDOM',
      'VOID',
    ];
    final sectorCode = sectorValues[index % sectorValues.length];

    return KnowledgeDetailResponse(
      node: KnowledgeNodeDetail(
        id: nodeId,
        name: isCore ? subject : '$subject - 知识点 ${index + 1}',
        nameEn: isCore ? subject : '$subject - Point ${index + 1}',
        description: '这是关于$subject的知识点描述。该知识点涵盖了核心概念和应用场景，帮助你更好地理解和掌握相关内容。',
        keywords: [subject, '计算机科学', '基础知识'],
        importanceLevel: isCore ? 5 : _random.nextInt(3) + 1,
        sectorCode: sectorCode,
        isSeed: isCore,
        sourceType: isCore ? 'seed' : 'llm_expanded',
        parentId: isCore ? null : 'node_${index % 20}',
        subjectId: index % subjects.length + 1,
        subjectName: subject,
        createdAt: DateTime.now().subtract(Duration(days: index)),
      ),
      relations: [
        if (index > 0)
          NodeRelation(
            id: 'rel_${index}_prev',
            sourceNodeId: 'node_${index - 1}',
            targetNodeId: nodeId,
            relationType: 'prerequisite',
            strength: 0.8,
            sourceNodeName: '$subject - 知识点 $index',
            targetNodeName: isCore ? subject : '$subject - 知识点 ${index + 1}',
          ),
        if (index < 499)
          NodeRelation(
            id: 'rel_${index}_next',
            sourceNodeId: nodeId,
            targetNodeId: 'node_${index + 1}',
            relationType: 'related',
            strength: 0.6,
            sourceNodeName: isCore ? subject : '$subject - 知识点 ${index + 1}',
            targetNodeName: '$subject - 知识点 ${index + 2}',
          ),
      ],
      relatedTasks: demoTasks.take(2).toList(),
      relatedPlans: demoPlans
          .map(
            (p) => RelatedPlan(
              id: p.id,
              title: p.name,
              planType: p.type.toString().split('.').last,
              status: p.isActive ? 'active' : 'completed',
              targetDate: p.targetDate,
            ),
          )
          .toList(),
      userStats: KnowledgeUserStats(
        masteryScore: status == NodeStatus.mastered
            ? 95.0
            : status == NodeStatus.review
                ? 60.0
                : status == NodeStatus.unlocked
                    ? 30.0
                    : 0.0,
        totalStudyMinutes: (index % 10 + 1) * 15,
        studyCount: index % 5 + 1,
        isUnlocked: status != NodeStatus.locked,
        isFavorite: index % 7 == 0,
        lastStudyAt: DateTime.now().subtract(Duration(days: index % 7)),
        nextReviewAt: status == NodeStatus.review
            ? DateTime.now().add(Duration(days: index % 3 + 1))
            : null,
        decayPaused: index % 10 == 0,
      ),
    );
  }

  // --- Plan Data ---
  List<PlanModel> get demoPlans {
    final now = DateTime.now();
    return [
      PlanModel(
        id: 'plan_sprint_1',
        userId: 'CS_Sophomore_12345',
        name: '数据结构期中冲刺',
        type: PlanType.sprint,
        dailyAvailableMinutes: 120,
        masteryLevel: 0.6,
        progress: 0.7, // 70%
        isActive: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
        targetDate: now.add(const Duration(days: 7)),
        description: '集中攻克链表、栈、队列和二叉树，准备期中考试。',
        totalEstimatedHours: 20,
      ),
      PlanModel(
        id: 'plan_growth_1',
        userId: 'CS_Sophomore_12345',
        name: '计算机科学基础巩固',
        type: PlanType.growth,
        dailyAvailableMinutes: 60,
        masteryLevel: 0.3,
        progress: 0.45, // 45%
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
        targetDate: now.add(const Duration(days: 90)), // 3 months
        description: '系统性复习CS基础四大件，构建完整的知识体系。',
        totalEstimatedHours: 100,
      ),
    ];
  }

  // --- Chat Data ---
  List<ChatMessageModel> get demoChatHistory => [
        ChatMessageModel(
          id: 'msg_1',
          conversationId: 'demo_conv_1',
          role: MessageRole.user,
          content: '我觉得最近学习效率有点低，总是忍不住想玩手机，怎么办？',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        ChatMessageModel(
          id: 'msg_2',
          conversationId: 'demo_conv_1',
          role: MessageRole.assistant,
          content:
              '理解你的感受。这种焦虑和自责其实是恶性循环的一部分。我们试着接纳这种情绪，而不是对抗它.\n\n根据你的学习记录，你这周已经在《离散数学》上投入了7.5小时，这非常棒。也许你可以试着先做一个简单的任务来找回状态？',
          createdAt:
              DateTime.now().subtract(const Duration(hours: 1, minutes: 59)),
        ),
        ChatMessageModel(
          id: 'msg_3',
          conversationId: 'demo_conv_1',
          role: MessageRole.user,
          content: '确实，那我先复习一下链表吧，但是我有点忘了怎么实现了。',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        ChatMessageModel(
          id: 'msg_4',
          conversationId: 'demo_conv_1',
          role: MessageRole.assistant,
          content: '没问题。根据你的学习进度，建议先复习 **单链表的插入与删除** 操作.\n\n正在为您生成数据结构学习计划...',
          createdAt: DateTime.now().subtract(const Duration(minutes: 29)),
          toolResults: [
            ToolResultModel(
                success: true,
                toolName: 'generate_plan',
                data: {'status': 'completed'},),
          ],
        ),
        ChatMessageModel(
          id: 'msg_5',
          conversationId: 'demo_conv_1',
          role: MessageRole.assistant,
          content: '''
这是一个简单的链表节点定义（C++），你可以作为参考：

```cpp
struct ListNode {
    int val;
    ListNode *next;
    ListNode(int x) : val(x), next(NULL) {}
};
```

你可以试着手写一下 `reverseList` 函数吗？''',
          createdAt: DateTime.now().subtract(const Duration(minutes: 28)),
        ),
      ];

  // --- Dashboard Data ---
  Map<String, dynamic> get demoDashboard => {
        'weather': {
          'type': 'sunny',
          'condition': 'Clear sky',
        },
        'flame': {
          'level': 15,
          'brightness': 85,
          'today_focus_minutes': 120,
          'tasks_completed': 3,
          'nudge_message': '你今天已经在《数据结构》上投入了2小时，非常棒！休息一下吧。',
        },
        'sprint': {
          'id': 'plan_sprint_1',
          'name': '数据结构期中冲刺',
          'progress': 0.7,
          'days_left': 7,
          'total_estimated_hours': 20.0,
        },
        'growth': {
          'id': 'plan_growth_1',
          'name': 'CS基础巩固',
          'progress': 0.45,
          'mastery_level': 0.3,
        },
        'next_actions': [
          {
            'id': 'task_1',
            'title': '数据结构 - 链表实现',
            'estimated_minutes': 120,
            'priority': 3,
            'type': 'learning',
          },
          {
            'id': 'task_2',
            'title': '离散数学 - 图论基础',
            'estimated_minutes': 90,
            'priority': 2,
            'type': 'learning',
          },
        ],
        'cognitive': {
          'weekly_pattern': 'Deep Work',
          'pattern_type': 'productive',
          'description': 'You are in a flow state this week.',
          'solution_text': 'Keep it up!',
          'status': 'analyzed',
          'has_new_insight': true,
        },
      };

  // --- Community Data ---
  List<Map<String, dynamic>> get demoCommunityFeed => [
    {
      'id': 'post_1',
      'author': {
        'id': 'user_001',
        'username': 'AI_Learner_01',
        'nickname': 'AI Learner 01',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_01',
      },
      'content': '今天完成了数据结构的学习，链表的反转操作终于掌握了！',
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'likes': 12,
      'comments': 3,
      'liked_by_me': false,
    },
    {
      'id': 'post_2',
      'author': {
        'id': 'user_002',
        'username': 'Study_Buddy',
        'nickname': '学习伙伴',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=Study_Buddy',
      },
      'content': '推荐一个很棒的离散数学学习资源：图论部分讲解得非常清晰。',
      'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'likes': 8,
      'comments': 2,
      'liked_by_me': true,
    },
  ];

  List<Map<String, dynamic>> get demoFriends => [
    {
      'id': 'friend_1',
      'friend': {
        'id': 'user_001',
        'username': 'AI_Learner_01',
        'nickname': 'AI Learner 01',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_01',
      },
      'status': 'accepted',
      'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
    },
    {
      'id': 'friend_2',
      'friend': {
        'id': 'user_002',
        'username': 'Study_Buddy',
        'nickname': '学习伙伴',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=Study_Buddy',
      },
      'status': 'accepted',
      'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
    },
  ];

  List<Map<String, dynamic>> get demoPendingRequests => [
    {
      'id': 'request_1',
      'friend': {
        'id': 'user_003',
        'username': 'New_Student',
        'nickname': '新生小王',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=New_Student',
      },
      'status': 'pending',
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'initiated_by_me': false,
    },
  ];

  List<Map<String, dynamic>> get demoFriendRecommendations => [
    {
      'user': {
        'id': 'user_004',
        'username': 'CS_Expert',
        'nickname': 'CS 专家',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=CS_Expert',
      },
      'match_score': 0.85,
      'match_reasons': ['共同学习数据结构', '相同专业'],
    },
    {
      'user': {
        'id': 'user_005',
        'username': 'Math_Lover',
        'nickname': '数学爱好者',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=Math_Lover',
      },
      'match_score': 0.72,
      'match_reasons': ['共同学习离散数学'],
    },
  ];

  List<Map<String, dynamic>> get demoMyGroups => [
    {
      'id': 'group_1',
      'name': 'CS 学习小组',
      'type': 'squad',
      'member_count': 15,
      'total_flame_power': 320,
      'focus_tags': ['数据结构', '算法', '计算机系统'],
      'my_role': 'member',
      'days_remaining': 7,
    },
    {
      'id': 'group_2',
      'name': '期中冲刺营',
      'type': 'sprint',
      'member_count': 8,
      'total_flame_power': 180,
      'focus_tags': ['离散数学', '图论'],
      'my_role': 'admin',
      'days_remaining': 14,
    },
  ];

  List<Map<String, dynamic>> get demoGroupMessages => [
    {
      'id': 'msg_1',
      'message_type': 'text',
      'content': '大家好，今天有谁要一起学习链表吗？',
      'sender': {
        'id': 'user_001',
        'username': 'AI_Learner_01',
        'nickname': 'AI Learner 01',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_01',
      },
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'reactions': {'👍': 2},
    },
    {
      'id': 'msg_2',
      'message_type': 'text',
      'content': '我刚完成了一道链表反转的题目，很有成就感！',
      'sender': {
        'id': 'user_002',
        'username': 'Study_Buddy',
        'nickname': '学习伙伴',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=Study_Buddy',
      },
      'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'reactions': {'🎉': 3, '🔥': 1},
    },
  ];

  List<Map<String, dynamic>> get demoPrivateMessages => [
    {
      'id': 'private_msg_1',
      'message_type': 'text',
      'content': '嗨，最近学习怎么样？',
      'sender': {
        'id': 'user_001',
        'username': 'AI_Learner_01',
        'nickname': 'AI Learner 01',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_01',
      },
      'receiver': {
        'id': 'CS_Sophomore_12345',
        'username': 'AI_Learner_02',
        'nickname': 'AI Learner 02',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=AI_Learner_02',
      },
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'is_read': false,
    },
  ];

  Map<String, dynamic> get demoFlameStatus => {
    'group_id': 'group_1',
    'total_power': 320,
    'bonfire_level': 3,
    'flames': [
      {
        'user_id': 'user_001',
        'flame_power': 80,
        'flame_color': '#FF6B35',
        'flame_size': 1.2,
        'position_x': 0.3,
        'position_y': 0.4,
      },
      {
        'user_id': 'CS_Sophomore_12345',
        'flame_power': 65,
        'flame_color': '#FF8C42',
        'flame_size': 1.0,
        'position_x': 0.6,
        'position_y': 0.5,
      },
    ],
  };

  // --- Focus Data ---
  Map<String, dynamic> get demoFocusStats => {
    'total_minutes': 240,
    'pomodoro_count': 4,
    'today_date': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> get demoLLMGuidance => {
    'guidance': '''
根据你的学习风格，我建议采用以下方法：

1. **分解任务**：将大任务拆分为 25 分钟的小块
2. **主动回忆**：每完成一个知识点，尝试不看笔记复述
3. **间隔复习**：在 1 天、3 天、7 天后复习

你现在处于深度学习状态，继续保持！''',
  };

  List<String> get demoTaskBreakdown => [
    '理解链表的基本概念（5分钟）',
    '实现单链表节点定义（10分钟）',
    '练习插入操作（15分钟）',
    '练习删除操作（15分钟）',
    '完成链表反转题目（20分钟）',
    '总结常见错误（5分钟）',
  ];

  // --- Nightly Review Data ---
  Map<String, dynamic> get demoNightlyReview => {
    'id': 'review_${DateTime.now().toIso8601String()}',
    'date': DateTime.now().toIso8601String(),
    'summary': '今天你在数据结构和离散数学上投入了 3.5 小时，完成了 2 个任务。继续保持良好的学习节奏！',
    'achievements': [
      {'title': '链表大师', 'description': '成功掌握链表的插入、删除和反转操作'},
      {'title': '专注达人', 'description': '连续完成 4 个番茄钟'},
    ],
    'improvements': [
      {'area': '时间管理', 'suggestion': '建议在下午 2-4 点安排最难的学习任务'},
      {'area': '复习频率', 'suggestion': '增加对已掌握知识点的间隔复习'},
    ],
    'tomorrow_goals': [
      '完成图论基础学习',
      '复习链表相关题目',
      '开始二叉树章节',
    ],
  };

  // --- Capsule Data ---
  List<Map<String, dynamic>> get demoTodayCapsules => [
    {
      'id': 'capsule_1',
      'title': '图论中的欧拉路径',
      'content': '欧拉路径是指经过图中每条边恰好一次的路径。欧拉路径存在的充要条件是：图中所有顶点的度数都是偶数，或者恰好有两个顶点的度数是奇数。',
      'source': '离散数学 - 图论',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'is_read': false,
    },
    {
      'id': 'capsule_2',
      'title': '时间复杂度的渐进表示法',
      'content': '大 O 表示法用于描述算法的渐进上界。例如，冒泡排序的时间复杂度是 O(n²)，表示在最坏情况下，执行时间与 n² 成正比。',
      'source': '算法导论',
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'is_read': true,
    },
  ];

  // --- Error Book Data ---
  List<Map<String, dynamic>> get demoErrors => [
    {
      'id': 'error_1',
      'subject': '数据结构',
      'question': '实现单链表的反转操作',
      'user_answer': '使用递归方式，但未处理空指针异常',
      'correct_answer': '使用迭代方式，使用三个指针分别记录前驱、当前和后继节点',
      'mistake_type': '逻辑错误',
      'difficulty': 3,
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'review_count': 2,
      'next_review_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    },
    {
      'id': 'error_2',
      'subject': '离散数学',
      'question': '判断图中是否存在欧拉回路',
      'user_answer': '认为所有顶点度数为偶数即可',
      'correct_answer': '需要图连通且所有顶点度数为偶数',
      'mistake_type': '概念理解错误',
      'difficulty': 4,
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      'review_count': 1,
      'next_review_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
    },
  ];

  Map<String, dynamic> get demoErrorStats => {
    'total_errors': 15,
    'reviewed_today': 2,
    'mastered': 5,
    'needs_review': 8,
    'by_subject': {
      '数据结构': 8,
      '离散数学': 4,
      '计算机系统': 3,
    },
  };

  Map<String, dynamic> get demoSemanticSummary => {
    'summary': '你的错误主要集中在图论算法和链表操作上。建议加强这两个领域的基础概念理解，并多做练习题巩固。',
    'patterns': [
      {
        'pattern': '边界条件处理不当',
        'suggestion': '在实现算法时，先考虑空输入、单元素等边界情况',
      },
      {
        'pattern': '递归理解不深',
        'suggestion': '学习递归的三要素：终止条件、递归公式、返回值处理',
      },
    ],
  };

  // --- File Data ---
  Map<String, dynamic> get demoUploadSession => {
    'session_id': 'upload_${DateTime.now().millisecondsSinceEpoch}',
    'file_name': '数据结构笔记.pdf',
    'file_size': 2048000,
    'upload_url': 'https://mock-upload.example.com/file/abc123',
    'expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
  };

  List<Map<String, dynamic>> get demoMyFiles => [
    {
      'id': 'file_1',
      'name': '数据结构笔记.pdf',
      'type': 'pdf',
      'size': 2048000,
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      'tags': <String>['数据结构', '笔记'],
      'shared_with': <String>[],
    },
    {
      'id': 'file_2',
      'name': '离散数学错题集.docx',
      'type': 'docx',
      'size': 512000,
      'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      'tags': <String>['离散数学', '错题'],
      'shared_with': <String>['group_1'],
    },
  ];

  List<Map<String, dynamic>> get demoGroupFiles => [
    {
      'id': 'group_file_1',
      'name': '小组学习计划.pdf',
      'type': 'pdf',
      'size': 1024000,
      'uploaded_by': {
        'id': 'user_001',
        'username': 'AI_Learner_01',
        'nickname': 'AI Learner 01',
      },
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'permissions': 'read',
    },
  ];

  Map<String, dynamic> get demoFileCategories => {
    'total_size': 3584000,
    'by_type': {
      'pdf': 3072000,
      'docx': 512000,
    },
    'by_tag': {
      '数据结构': 2048000,
      '离散数学': 1024000,
      '笔记': 2048000,
      '错题': 512000,
    },
  };

  // --- Vocabulary Data ---
  Map<String, dynamic> get demoVocabularyLookup => {
    'word': 'polymorphism',
    'phonetic': '/ˈpɒlɪmɔːfɪzəm/',
    'definition': '多态性：在面向对象编程中，同一个接口可以有多种不同的实现方式',
    'examples': [
      'Polymorphism allows objects of different classes to be treated as objects of a common superclass.',
      '多态性允许不同类的对象被视为共同父类的对象处理。',
    ],
    'related_words': ['inheritance', 'encapsulation', 'abstraction'],
    'part_of_speech': 'noun',
  };

  List<Map<String, dynamic>> get demoWordbook => [
    {
      'id': 'word_1',
      'word': 'algorithm',
      'definition': '算法：解决问题的明确步骤',
      'added_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      'review_count': 3,
      'mastery_level': 0.8,
    },
    {
      'id': 'word_2',
      'word': 'recursion',
      'definition': '递归：函数调用自身的过程',
      'added_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'review_count': 1,
      'mastery_level': 0.4,
    },
  ];

  List<Map<String, dynamic>> get demoReviewList => [
    {
      'id': 'review_1',
      'word': 'algorithm',
      'next_review_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'priority': 'high',
    },
    {
      'id': 'review_2',
      'word': 'recursion',
      'next_review_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'priority': 'medium',
    },
  ];

  Map<String, dynamic> get demoAssociations => {
    'word': 'algorithm',
    'associations': [
      {'word': 'complexity', 'relation': 'related', 'strength': 0.8},
      {'word': 'efficiency', 'relation': 'related', 'strength': 0.7},
      {'word': 'data structure', 'relation': 'prerequisite', 'strength': 0.9},
    ],
  };

  String get demoGeneratedSentence =>
      'The algorithm efficiently solves the problem by using a recursive approach.';

  // --- Notification Data ---
  List<Map<String, dynamic>> get demoNotifications => [
    {
      'id': 'notif_1',
      'type': 'friend_request',
      'title': '新的好友请求',
      'content': '新生小王请求添加你为好友',
      'data': {'friendship_id': 'request_1'},
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'read': false,
    },
    {
      'id': 'notif_2',
      'type': 'group_message',
      'title': 'CS 学习小组',
      'content': 'AI Learner 01 提到了你：大家好，今天有谁要一起学习链表吗？',
      'data': {'group_id': 'group_1', 'message_id': 'msg_1'},
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'read': false,
    },
    {
      'id': 'notif_3',
      'type': 'achievement',
      'title': '成就解锁',
      'content': '你已连续学习 7 天，获得「学习达人」徽章！',
      'data': {'achievement_id': 'streak_7'},
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'read': true,
    },
  ];

  // --- OmniBar Data ---
  Map<String, dynamic> get demoOmniBarDispatch => {
    'action': 'create_task',
    'parameters': {
      'title': '复习链表',
      'type': 'learning',
      'estimated_minutes': 60,
      'priority': 2,
    },
    'confirmation': '已创建任务：复习链表（60分钟）',
  };

  // --- Asset Data ---
  List<Map<String, dynamic>> get demoInboxAssets => [
    {
      'id': 'asset_1',
      'title': '图论学习资源',
      'source': 'AI 推荐',
      'type': 'article',
      'status': 'unread',
      'priority': 0.8,
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'tags': ['离散数学', '图论'],
    },
    {
      'id': 'asset_2',
      'title': '链表常见面试题',
      'source': '社区分享',
      'type': 'collection',
      'status': 'reading',
      'priority': 0.6,
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'tags': ['数据结构', '面试'],
    },
  ];

  Map<String, dynamic> get demoInboxStats => {
    'total': 12,
    'unread': 5,
    'reading': 3,
    'completed': 4,
    'by_type': {
      'article': 6,
      'video': 3,
      'collection': 3,
    },
  };
}

enum NodeStatus { locked, unlocked, review, mastered }

/// Provider for DemoDataService
final demoDataServiceProvider =
    Provider<DemoDataService>((ref) => DemoDataService());
