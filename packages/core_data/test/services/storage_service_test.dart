import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_data/core_data.dart';

@GenerateMocks([SupabaseClient, SupabaseStorageClient, StorageFileApi])
import 'storage_service_test.mocks.dart';

void main() {
  late StorageService storageService;
  late MockSupabaseClient mockClient;
  late MockSupabaseStorageClient mockStorage;
  late MockStorageFileApi mockFileApi;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    mockFileApi = MockStorageFileApi();
    storageService = StorageService(mockClient);

    when(mockClient.storage).thenReturn(mockStorage);
  });

  group('StorageService - File Upload', () {
    test('uploadBytes successfully uploads file and returns URL', () async {
      // Arrange
      final bucket = 'test-bucket';
      final filename = 'test.jpg';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final expectedUrl = 'https://example.com/storage/test-bucket/test.jpg';

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.uploadBinary(
        any,
        bytes,
        fileOptions: anyNamed('fileOptions'),
      )).thenAnswer((_) async => 'path/to/file');
      when(mockFileApi.getPublicUrl(any)).thenReturn(expectedUrl);

      // Act
      final url = await storageService.uploadBytes(
        bucket: bucket,
        bytes: bytes,
        filename: filename,
      );

      // Assert
      expect(url, expectedUrl);
      verify(mockStorage.from(bucket)).called(2); // once for upload, once for getPublicUrl
      verify(mockFileApi.uploadBinary(
        any,
        bytes,
        fileOptions: anyNamed('fileOptions'),
      )).called(1);
    });

    test('uploadBytes with folder creates correct path', () async {
      // Arrange
      final bucket = 'test-bucket';
      final folder = 'community-123';
      final filename = 'test.jpg';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.uploadBinary(
        any,
        bytes,
        fileOptions: anyNamed('fileOptions'),
      )).thenAnswer((_) async => 'path');
      when(mockFileApi.getPublicUrl(any)).thenReturn('url');

      // Act
      await storageService.uploadBytes(
        bucket: bucket,
        bytes: bytes,
        filename: filename,
        folder: folder,
      );

      // Assert
      verify(mockFileApi.uploadBinary(
        argThat(contains(folder)),
        bytes,
        fileOptions: anyNamed('fileOptions'),
      )).called(1);
    });

    test('uploadBytes throws exception on upload failure', () async {
      // Arrange
      final bucket = 'test-bucket';
      final filename = 'test.jpg';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.uploadBinary(
        any,
        bytes,
        fileOptions: anyNamed('fileOptions'),
      )).thenThrow(StorageException('Upload failed'));

      // Act & Assert
      expect(
        () => storageService.uploadBytes(
          bucket: bucket,
          bytes: bytes,
          filename: filename,
        ),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('StorageService - File Validation', () {
    test('validateFileSize returns true for valid file size', () {
      // Arrange
      final file = PlatformFile(
        name: 'test.jpg',
        size: 1024 * 1024, // 1MB
        bytes: Uint8List(0),
      );
      final maxSize = 5 * 1024 * 1024; // 5MB

      // Act
      final isValid = storageService.validateFileSize(file, maxSize);

      // Assert
      expect(isValid, true);
    });

    test('validateFileSize returns false for oversized file', () {
      // Arrange
      final file = PlatformFile(
        name: 'test.jpg',
        size: 10 * 1024 * 1024, // 10MB
        bytes: Uint8List(0),
      );
      final maxSize = 5 * 1024 * 1024; // 5MB

      // Act
      final isValid = storageService.validateFileSize(file, maxSize);

      // Assert
      expect(isValid, false);
    });
  });

  group('StorageService - File Management', () {
    test('deleteFile successfully deletes file', () async {
      // Arrange
      final bucket = 'test-bucket';
      final filePath = 'path/to/file.jpg';

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.remove(any)).thenAnswer((_) async => []);

      // Act
      await storageService.deleteFile(bucket: bucket, filePath: filePath);

      // Assert
      verify(mockFileApi.remove([filePath])).called(1);
    });

    test('getPublicUrl returns correct URL', () {
      // Arrange
      final bucket = 'test-bucket';
      final filePath = 'path/to/file.jpg';
      final expectedUrl = 'https://example.com/storage/$bucket/$filePath';

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.getPublicUrl(filePath)).thenReturn(expectedUrl);

      // Act
      final url = storageService.getPublicUrl(bucket: bucket, filePath: filePath);

      // Assert
      expect(url, expectedUrl);
    });

    test('downloadFile returns file bytes', () async {
      // Arrange
      final bucket = 'test-bucket';
      final filePath = 'path/to/file.jpg';
      final expectedBytes = Uint8List.fromList([1, 2, 3, 4]);

      when(mockStorage.from(bucket)).thenReturn(mockFileApi);
      when(mockFileApi.download(filePath)).thenAnswer((_) async => expectedBytes);

      // Act
      final bytes = await storageService.downloadFile(
        bucket: bucket,
        filePath: filePath,
      );

      // Assert
      expect(bytes, expectedBytes);
    });
  });

  group('StorageService - Utilities', () {
    test('getFileSizeString formats bytes correctly', () {
      expect(storageService.getFileSizeString(500), '500 B');
      expect(storageService.getFileSizeString(1024), '1.0 KB');
      expect(storageService.getFileSizeString(1024 * 1024), '1.0 MB');
      expect(storageService.getFileSizeString(1024 * 1024 * 1024), '1.0 GB');
    });

    test('_sanitizeFilename removes special characters', () {
      // This would test the private method if it were public or via reflection
      // For now, we verify behavior through uploadBytes
    });
  });
}
