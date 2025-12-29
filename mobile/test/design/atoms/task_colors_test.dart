import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/tokens/task_colors.dart';

void main() {
  group('TaskColors', () {
    test('returns light palette values with correct tints', () {
      const colors = TaskColors(brightness: Brightness.light);

      expect(colors.getColor(TaskType.learning), const Color(0xFF64B5F6));
      expect(colors.getTint(TaskType.learning), const Color(0x1A64B5F6));
      expect(colors.getBorder(TaskType.learning), const Color(0x4C64B5F6));
      expect(colors.getIcon(TaskType.learning), const Color(0xFF64B5F6));
      expect(colors.getLabel(TaskType.learning), const Color(0xFF64B5F6));
    });

    test('uses dark palette variants for dark brightness', () {
      const colors = TaskColors(brightness: Brightness.dark);

      expect(colors.getColor(TaskType.planning), const Color(0xFF4DB6AC));
      expect(colors.getTint(TaskType.planning), const Color(0x1A4DB6AC));
      expect(colors.getBorder(TaskType.planning), const Color(0x4C4DB6AC));
    });

    test('keeps social color consistent across palettes', () {
      const light = TaskColors(brightness: Brightness.light);
      const dark = TaskColors(brightness: Brightness.dark);

      expect(light.getColor(TaskType.social), const Color(0xFFFFB703));
      expect(dark.getColor(TaskType.social), const Color(0xFFFFB703));
    });
  });
}
