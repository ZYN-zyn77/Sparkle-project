# Phase 7 演示脚本：资产建议系统闭环

> 演示时长：约3分钟
> 验收目标：展示完整闭环 查词→建议→入Inbox→激活→指标展示

---

## 演示前检查清单

```bash
# 1. 确保服务运行
curl http://localhost:8080/health  # Go Gateway
curl http://localhost:8000/health  # Python gRPC/REST

# 2. 确保数据库可访问
docker compose exec postgres psql -U sparkle -c "SELECT 1;"

# 3. 清理测试数据（可选，用于演示前重置）
docker compose exec postgres psql -U sparkle -c "
  DELETE FROM asset_suggestion_logs WHERE user_id = '<test_user_id>';
  DELETE FROM learning_assets WHERE user_id = '<test_user_id>';
"

# 4. 启动 Flutter 应用
cd mobile && flutter run
```

---

## 演示流程

### Step 1: 首次查词（不触发建议）

**操作**：
1. 打开阅读器，选择一个英文单词（如 "algorithm"）
2. 点击翻译弹窗查看翻译

**预期结果**：
- 显示翻译结果
- 不显示建议卡片（查询次数 < 2）
- 底部显示普通的"生词卡"按钮

**后台验证**：
```bash
# 查看 suggestion log
curl -X GET "http://localhost:8000/api/v1/analytics/suggestion-metrics?start_date=2025-01-01&end_date=2025-12-31" \
  -H "Authorization: Bearer <token>"

# 预期：trigger_count +1, skip_count +1 (lookup_count_below_threshold)
```

---

### Step 2: 再次查询同一词（触发建议）

**操作**：
1. 在同一会话中，再次选择并翻译相同的单词 "algorithm"
2. 观察翻译弹窗

**预期结果**：
- 翻译显示完成后，出现**建议卡片**
- 卡片显示：
  - "💡 建议加入生词本"
  - reason: "在本次会话中查询了 2 次"
- 两个按钮："忽略" / "加入待办箱"

**关键验证点**：
- [ ] reason 使用结构化模板渲染（不是硬编码字符串）
- [ ] 卡片视觉样式符合设计规范

---

### Step 3: 接受建议，创建资产

**操作**：
1. 点击"加入待办箱"按钮

**预期结果**：
- 显示成功提示："✅ 已存入待办箱，请在7天内开始学习"
- 弹窗自动关闭（1秒后）
- 后台创建 LearningAsset（status=INBOX）
- 后台记录 feedback（user_response=ACCEPT）

**后台验证**：
```bash
# 查看创建的资产
curl -X GET "http://localhost:8000/api/v1/assets?status=INBOX" \
  -H "Authorization: Bearer <token>"

# 预期：能看到刚创建的 "algorithm" 资产

# 查看 suggestion feedback
curl -X GET "http://localhost:8000/api/v1/analytics/suggestion-metrics?start_date=2025-01-01&end_date=2025-12-31" \
  -H "Authorization: Bearer <token>"

# 预期：accept_count +1, asset_create_count +1
```

---

### Step 4: 激活资产（Inbox → Active）

**操作**：
1. 导航到"待办箱"页面
2. 找到刚才创建的 "algorithm" 资产
3. 点击"开始学习"激活

**预期结果**：
- 资产状态变为 ACTIVE
- 资产从 Inbox 列表移动到学习列表
- 显示成功反馈

**后台验证**：
```bash
# 查看资产状态
curl -X GET "http://localhost:8000/api/v1/assets/<asset_id>" \
  -H "Authorization: Bearer <token>"

# 预期：status = "ACTIVE"

# 查看指标
curl -X GET "http://localhost:8000/api/v1/analytics/suggestion-metrics?start_date=2025-01-01&end_date=2025-12-31" \
  -H "Authorization: Bearer <token>"

# 预期：inbox_activate_count +1
```

---

### Step 5: 展示指标仪表盘

**操作**：
1. 调用指标 API 或展示管理后台

**API 调用**：
```bash
curl -X GET "http://localhost:8000/api/v1/analytics/suggestion-metrics?start_date=2025-01-01&end_date=2025-12-31" \
  -H "Authorization: Bearer <token>" | jq .
```

**预期响应**：
```json
{
  "start_date": "2025-01-01",
  "end_date": "2025-12-31",
  "trigger_count": 2,
  "suggested_count": 1,
  "skip_count": 1,
  "not_suggested_count": 0,
  "accept_count": 1,
  "dismiss_count": 0,
  "pending_count": 0,
  "asset_create_count": 1,
  "inbox_activate_count": 1,
  "suggestion_rate": 0.5,
  "accept_rate": 1.0,
  "activation_rate": 1.0
}
```

**关键指标解读**：
| 指标 | 含义 | 本次演示值 |
|------|------|------------|
| `trigger_count` | 建议系统被触发次数 | 2 |
| `suggested_count` | 实际显示建议次数 | 1 |
| `accept_rate` | 建议接受率（点击率） | 100% |
| `activation_rate` | 资产激活率 | 100% |

---

## 异常场景演示（可选）

### 场景 A: 忽略建议

**操作**：
1. 重复查询一个新单词触发建议
2. 点击"忽略"

**预期**：
- 建议卡片消失
- 后台记录 DISMISS
- 该用户进入冷却期（30分钟内不再对同一词建议）

### 场景 B: 建议冷却

**操作**：
1. 忽略建议后，立即再次查询同一词

**预期**：
- 不显示建议卡片
- reason_code = "cooldown_active"

---

## Done 定义

本次演示完成的标准：

- [x] 完整闭环可走通（查词→建议→创建→激活）
- [x] reason 使用结构化渲染
- [x] 指标 API 返回正确数据
- [x] 无控制台报错
- [x] 用户体验流畅（<3秒响应）

---

## 故障排查

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 建议不出现 | session_id 未传递 | 检查 X-Session-ID header |
| reason 显示原始代码 | Flutter 未更新 | flutter clean && flutter pub get |
| 指标为 0 | 时间范围不对 | 调整 start_date/end_date |
| 资产创建失败 | 数据库连接问题 | 检查 postgres 日志 |
