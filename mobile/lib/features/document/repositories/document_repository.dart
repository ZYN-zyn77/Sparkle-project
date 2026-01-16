import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sparkle/core/network/dio_provider.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/document/models/document_cleaning_model.dart';

part 'document_repository.g.dart';

/// Interface for document repository
abstract class DocumentRepositoryInterface {
  Future<String> uploadAndClean(File file, {bool enableOcr = true});
  Future<CleaningTaskStatus> getTaskStatus(String taskId);
}

@riverpod
DocumentRepositoryInterface documentRepository(DocumentRepositoryRef ref) {
  if (DemoDataService.isDemoMode) {
    return MockDocumentRepository();
  }
  return DocumentRepository(ref.watch(dioProvider));
}

class DocumentRepository implements DocumentRepositoryInterface {
  DocumentRepository(this._dio);
  final Dio _dio;

  @override
  Future<String> uploadAndClean(File file, {bool enableOcr = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'options': jsonEncode({'enable_ocr': enableOcr}),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/documents/clean',
      data: formData,
    );

    final data = response.data;
    if (data == null || data['task_id'] == null) {
      throw Exception('Missing task_id in response');
    }
    return data['task_id'] as String;
  }

  @override
  Future<CleaningTaskStatus> getTaskStatus(String taskId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response =
        await _dio.get<Map<String, dynamic>>('/documents/clean/$taskId');
    return CleaningTaskStatus.fromJson(response.data ?? <String, dynamic>{});
  }
}

class MockDocumentRepository implements DocumentRepositoryInterface {
  @override
  Future<String> uploadAndClean(File file, {bool enableOcr = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'mock_task_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<CleaningTaskStatus> getTaskStatus(String taskId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const CleaningTaskStatus(
      status: 'completed',
      percent: 100,
      message: 'Document cleaning completed successfully',
      result: CleaningResult(
        status: 'success',
        mode: 'full_text',
        summary:
            '这是一个模拟的文档清理结果。在演示模式下，系统会返回预定义的清理结果，包括文档摘要和元数据信息。',
        fullText:
            '这是一个模拟的文档清理结果。在演示模式下，系统会返回预定义的清理结果，包括文档摘要和元数据信息。文档清理服务会自动提取关键信息、去除噪声并生成结构化输出。',
        fullTextPreview:
            '这是一个模拟的文档清理结果。在演示模式下，系统会返回预定义的清理结果...',
        charCount: 120,
      ),
    );
  }
}
