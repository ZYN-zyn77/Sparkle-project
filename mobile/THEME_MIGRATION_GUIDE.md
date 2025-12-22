# 主题统一迁移指南

## 概述
已创建统一的主题系统 `AppTheme`，支持深色/浅色模式自动切换。

## 快速迁移步骤

### 1. 更新屏幕背景色

#### 当前问题
- 星图 (GalaxyScreen): `backgroundColor: Colors.black`
- 社群 (CommunityScreen): 灰色背景
- 对话 (ChatScreen): 白色背景
- 我的 (ProfileScreen): 白色背景

#### 统一方案

在每个屏幕的 `build` 方法中：

```dart
@override
Widget build(BuildContext context) {
  final brightness = Theme.of(context).brightness;

  return Scaffold(
    // 使用统一的背景
    body: Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(brightness),
      ),
      child: YourContent(),
    ),
  );
}
```

### 2. 需要修改的文件

#### GalaxyScreen
**文件**: `lib/presentation/screens/galaxy_screen.dart`

```dart
// 第 165 行改为:
return Scaffold(
  body: Container(
    decoration: BoxDecoration(
      gradient: AppTheme.getBackgroundGradient(Theme.of(context).brightness),
    ),
    child: Stack(
      children: [
        // 现有内容...
      ],
    ),
  ),
);
```

#### ChatScreen
**文件**: `lib/presentation/screens/chat/chat_screen.dart`

在 Scaffold 内包装：
```dart
body: Container(
  decoration: BoxDecoration(
    gradient: AppTheme.getBackgroundGradient(Theme.of(context).brightness),
  ),
  child: // 现有内容...
),
```

#### CommunityScreen
**文件**: `lib/presentation/screens/community/community_screen.dart`

同上方法。

#### ProfileScreen
**文件**: `lib/presentation/screens/profile/profile_screen.dart`

同上方法。

### 3. 侧边栏主题统一

#### AdaptiveNavigation 背景
**文件**: `lib/presentation/widgets/layout/adaptive_navigation.dart`

底部导航栏 (第 224-229 行) 和 NavigationRail (第 163 行) 已使用深色主题。

如需支持浅色模式，修改：
```dart
// BottomNavigationBar
Container(
  decoration: BoxDecoration(
    color: AppTheme.getBackgroundColor(Theme.of(context).brightness).withAlpha(216),
    // ...
  ),
)

// NavigationRail
backgroundColor: AppTheme.getBackgroundColor(Theme.of(context).brightness),
```

## 主题切换

### 方法 1: 在 main.dart 中配置
```dart
MaterialApp(
  theme: AppTheme.getLightTheme(),
  darkTheme: AppTheme.getDarkTheme(),
  themeMode: ThemeMode.system, // 跟随系统
  // ...
)
```

### 方法 2: 添加手动切换
创建一个 ThemeProvider:
```dart
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
```

在设置页面添加切换按钮。

## 配色参考

### 深色模式 (当前默认)
- 背景渐变: `#0D1B2A` → `#1B263B`
- 表面颜色: `#1B2838`
- 主文本: `Colors.white`
- 次要文本: `Colors.white70`

### 浅色模式
- 背景渐变: `#F5F7FA` → `#E8EAF6`
- 表面颜色: `#FFFFFF`
- 主文本: `Colors.black87`
- 次要文本: `Colors.black54`

## 测试清单

- [ ] 驾驶舱 (HomeScreen) - 已完成
- [ ] 星图 (GalaxyScreen) - 待更新
- [ ] 对话 (ChatScreen) - 待更新
- [ ] 社群 (CommunityScreen) - 待更新
- [ ] 我的 (ProfileScreen) - 待更新
- [ ] 导航栏 (AdaptiveNavigation) - 待更新浅色支持
