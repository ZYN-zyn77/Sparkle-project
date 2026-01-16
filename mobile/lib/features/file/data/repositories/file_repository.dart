import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/network/api_endpoints.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/file/file.dart';

/// Interface for file repository
abstract class FileRepositoryInterface {
  Future<UploadSession> prepareUpload({
    required String filename,
    required int fileSize,
    required String mimeType,
  });

  Future<StoredFile> completeUpload({
    required String uploadId,
    String? groupId,
    String? visibility,
    String? description,
  });

  Future<StoredFile> getFile(String fileId, {String? groupId});

  Future<PresignedUrl> getDownloadUrl(String fileId, {String? groupId});

  Future<PresignedUrl> getThumbnailUrl(String fileId, {String? groupId});

  Future<List<StoredFile>> listMyFiles({
    String? status,
    int limit = 20,
    int offset = 0,
  });

  Future<List<StoredFile>> searchMyFiles({
    required String query,
    int limit = 20,
  });

  Future<List<GroupFileInfo>> listGroupFiles(
    String groupId, {
    String? category,
    int limit = 20,
    int offset = 0,
  });

  Future<GroupFileInfo> shareToGroup(
    String groupId,
    String fileId, {
    String? category,
    List<String>? tags,
    GroupFilePermissions? permissions,
    bool sendMessage = true,
  });

  Future<GroupFileInfo> updateGroupFilePermissions(
    String groupId,
    String fileId,
    GroupFilePermissions permissions,
  );

  Future<List<GroupFileCategoryStat>> getGroupFileCategories(String groupId);
}

final fileRepositoryProvider = Provider<FileRepositoryInterface>((ref) {
  if (DemoDataService.isDemoMode) {
    return MockFileRepository();
  }
  final apiClient = ref.watch(apiClientProvider);
  return FileRepository(apiClient.dio);
});

class FileRepository implements FileRepositoryInterface {
  FileRepository(this._dio);

  final Dio _dio;

  @override
  Future<UploadSession> prepareUpload({
    required String filename,
    required int fileSize,
    required String mimeType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.filesPrepareUpload,
      data: {
        'filename': filename,
        'file_size': fileSize,
        'mime_type': mimeType,
      },
    );
    return UploadSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<StoredFile> completeUpload({
    required String uploadId,
    String? groupId,
    String? visibility,
    String? description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.filesCompleteUpload,
      data: {
        'upload_id': uploadId,
        if (groupId != null) 'group_id': groupId,
        if (visibility != null) 'visibility': visibility,
        if (description != null) 'description': description,
      },
    );
    return StoredFile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<StoredFile> getFile(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.file(fileId),
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
    );
    return StoredFile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PresignedUrl> getDownloadUrl(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.fileDownload(fileId),
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
    );
    return PresignedUrl.fromJson(
        response.data as Map<String, dynamic>, 'download_url',);
  }

  @override
  Future<PresignedUrl> getThumbnailUrl(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.fileThumbnail(fileId),
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
    );
    return PresignedUrl.fromJson(
        response.data as Map<String, dynamic>, 'thumbnail_url',);
  }

  @override
  Future<List<StoredFile>> listMyFiles({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.myFiles,
      queryParameters: {
        if (status != null) 'status': status,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => StoredFile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StoredFile>> searchMyFiles({
    required String query,
    int limit = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.myFilesSearch,
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => StoredFile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<GroupFileInfo>> listGroupFiles(
    String groupId, {
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.groupFiles(groupId),
      queryParameters: {
        if (category != null) 'category': category,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => GroupFileInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<GroupFileInfo> shareToGroup(
    String groupId,
    String fileId, {
    String? category,
    List<String>? tags,
    GroupFilePermissions? permissions,
    bool sendMessage = true,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.groupFileShare(groupId, fileId),
      data: {
        if (category != null) 'category': category,
        if (tags != null) 'tags': tags,
        if (permissions != null) 'permissions': permissions.toJson(),
        'send_message': sendMessage,
      },
    );
    return GroupFileInfo.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<GroupFileInfo> updateGroupFilePermissions(
    String groupId,
    String fileId,
    GroupFilePermissions permissions,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.groupFilePermissions(groupId, fileId),
      data: {
        'permissions': permissions.toJson(),
      },
    );
    return GroupFileInfo.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<GroupFileCategoryStat>> getGroupFileCategories(
      String groupId,) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response =
        await _dio.get<List<dynamic>>(ApiEndpoints.groupFileCategories(groupId));
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) =>
            GroupFileCategoryStat.fromJson(item as Map<String, dynamic>),)
        .toList();
  }
}

class MockFileRepository implements FileRepositoryInterface {
  @override
  Future<UploadSession> prepareUpload({
    required String filename,
    required int fileSize,
    required String mimeType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoUploadSession;
    return UploadSession.fromJson(data);
  }

  @override
  Future<StoredFile> completeUpload({
    required String uploadId,
    String? groupId,
    String? visibility,
    String? description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoMyFiles.first;
    return StoredFile.fromJson(data);
  }

  @override
  Future<StoredFile> getFile(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final data = DemoDataService().demoMyFiles.firstWhere(
          (file) => file['id'] == fileId,
          orElse: () => DemoDataService().demoMyFiles.first,
        );
    return StoredFile.fromJson(data);
  }

  @override
  Future<PresignedUrl> getDownloadUrl(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return PresignedUrl(
      url: 'https://mock-download.example.com/file/$fileId',
      expiresIn: 3600,
    );
  }

  @override
  Future<PresignedUrl> getThumbnailUrl(String fileId, {String? groupId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return PresignedUrl(
      url: 'https://mock-thumbnail.example.com/file/$fileId',
      expiresIn: 3600,
    );
  }

  @override
  Future<List<StoredFile>> listMyFiles({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final data = DemoDataService().demoMyFiles;
    return data.map((item) => StoredFile.fromJson(item)).toList();
  }

  @override
  Future<List<StoredFile>> searchMyFiles({
    required String query,
    int limit = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final data = DemoDataService()
        .demoMyFiles
        .where((file) =>
            file['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
    return data.map((item) => StoredFile.fromJson(item)).toList();
  }

  @override
  Future<List<GroupFileInfo>> listGroupFiles(
    String groupId, {
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final data = DemoDataService().demoGroupFiles;
    return data.map((item) => GroupFileInfo.fromJson(item)).toList();
  }

  @override
  Future<GroupFileInfo> shareToGroup(
    String groupId,
    String fileId, {
    String? category,
    List<String>? tags,
    GroupFilePermissions? permissions,
    bool sendMessage = true,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoGroupFiles.first;
    return GroupFileInfo.fromJson(data);
  }

  @override
  Future<GroupFileInfo> updateGroupFilePermissions(
    String groupId,
    String fileId,
    GroupFilePermissions permissions,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoGroupFiles.first;
    return GroupFileInfo.fromJson(data);
  }

  @override
  Future<List<GroupFileCategoryStat>> getGroupFileCategories(
      String groupId,) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final data = DemoDataService().demoFileCategories;
    final byType = data['by_type'] as Map<String, dynamic>;
    return byType.entries
        .map((entry) =>
            GroupFileCategoryStat(category: entry.key, count: entry.value),)
        .toList();
  }
}
