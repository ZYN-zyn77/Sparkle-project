import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';

/// AppTheme - 应用主题管理
/// 提供统一的深色/浅色主题配置
class AppTheme {
  AppTheme._();

  /// 获取背景渐变 (根据主题模式)
  static LinearGradient getBackgroundGradient(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.deepSpaceGradient
        : AppDesignTokens.lightBackgroundGradient;
  }

  /// 获取背景色 (单色，根据主题模式)
  static Color getBackgroundColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.deepSpaceStart
        : AppDesignTokens.lightBackgroundStart;
  }

  /// 获取表面颜色 (卡片背景)
  static Color getSurfaceColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.deepSpaceSurface
        : AppDesignTokens.lightSurface;
  }

  /// 获取玻璃效果背景色
  static Color getGlassBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.glassBackground
        : AppDesignTokens.lightGlassBackground;
  }

  /// 获取玻璃效果边框色
  static Color getGlassBorder(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.glassBorder
        : AppDesignTokens.lightGlassBorder;
  }

  /// 获取文字颜色 (主要文本)
  static Color getTextColor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }

  /// 获取次要文字颜色
  static Color getSecondaryTextColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  /// 获取深色主题数据
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppDesignTokens.primaryBase,
      scaffoldBackgroundColor: AppDesignTokens.deepSpaceStart,
      colorScheme: ColorScheme.dark(
        primary: AppDesignTokens.primaryBase,
        secondary: AppDesignTokens.secondaryBaseDark,
        surface: AppDesignTokens.deepSpaceSurface,
        error: AppDesignTokens.error,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: AppDesignTokens.fontSize6xl,
          fontWeight: AppDesignTokens.fontWeightBold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: AppDesignTokens.fontSize2xl,
          fontWeight: AppDesignTokens.fontWeightSemibold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: AppDesignTokens.fontSizeBase,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: AppDesignTokens.fontSizeSm,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// 获取浅色主题数据
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppDesignTokens.primaryBase,
      scaffoldBackgroundColor: AppDesignTokens.lightBackgroundStart,
      colorScheme: ColorScheme.light(
        primary: AppDesignTokens.primaryBase,
        secondary: AppDesignTokens.secondaryBase,
        surface: AppDesignTokens.lightSurface,
        error: AppDesignTokens.error,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: AppDesignTokens.fontSize6xl,
          fontWeight: AppDesignTokens.fontWeightBold,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          fontSize: AppDesignTokens.fontSize2xl,
          fontWeight: AppDesignTokens.fontWeightSemibold,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: AppDesignTokens.fontSizeBase,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(
          fontSize: AppDesignTokens.fontSizeSm,
          color: Colors.black54,
        ),
      ),
    );
  }
}
