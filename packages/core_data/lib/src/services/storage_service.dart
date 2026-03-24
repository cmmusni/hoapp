import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  /// Pick a file from the device
  /// Returns the picked file or null if cancelled
  Future<PlatformFile?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: true, // Important for web
    );

    return result?.files.first;
  }

  /// Pick an image file
  Future<PlatformFile?> pickImage() async {
    return pickFile(
      type: FileType.image,
    );
  }

  /// Pick a PDF file
  Future<PlatformFile?> pickPDF() async {
    return pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
  }

  /// Upload a file to Supabase Storage
  /// 
  /// [bucket] - Storage bucket name (e.g., 'violation-photos', 'pool-documents')
  /// [file] - The file to upload
  /// [folder] - Optional folder path within the bucket
  /// 
  /// Returns the public URL of the uploaded file
  Future<String> uploadFile({
    required String bucket,
    required PlatformFile file,
    String? folder,
  }) async {
    if (file.bytes == null) {
      throw Exception('File data is null. Cannot upload.');
    }

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(file.name);
    final filename = '${timestamp}_${_sanitizeFilename(file.name)}';
    final filePath = folder != null ? '$folder/$filename' : filename;

    // Determine content type
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';

    // Upload to Supabase Storage
    await _client.storage.from(bucket).uploadBinary(
          filePath,
          file.bytes!,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    // Get public URL
    final url = _client.storage.from(bucket).getPublicUrl(filePath);

    return url;
  }

  /// Upload image file specifically
  Future<String> uploadImage({
    required String bucket,
    required PlatformFile file,
    String? folder,
  }) async {
    // Validate it's an image
    final mimeType = lookupMimeType(file.name);
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw Exception('File is not a valid image');
    }

    return uploadFile(bucket: bucket, file: file, folder: folder);
  }

  /// Upload from bytes directly
  Future<String> uploadBytes({
    required String bucket,
    required Uint8List bytes,
    required String filename,
    String? folder,
    String? contentType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = _sanitizeFilename(filename);
    final filePath = folder != null ? '$folder/${timestamp}_$sanitized' : '${timestamp}_$sanitized';

    final mimeType = contentType ?? lookupMimeType(filename) ?? 'application/octet-stream';

    await _client.storage.from(bucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    return _client.storage.from(bucket).getPublicUrl(filePath);
  }

  /// Delete a file from storage
  Future<void> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    await _client.storage.from(bucket).remove([filePath]);
  }

  /// Get download URL for a file
  String getPublicUrl({
    required String bucket,
    required String filePath,
  }) {
    return _client.storage.from(bucket).getPublicUrl(filePath);
  }

  /// Download file bytes
  Future<Uint8List> downloadFile({
    required String bucket,
    required String filePath,
  }) async {
    return await _client.storage.from(bucket).download(filePath);
  }

  /// Sanitize filename to remove special characters
  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Validate file size (in bytes)
  bool validateFileSize(PlatformFile file, int maxSizeBytes) {
    if (file.size > maxSizeBytes) {
      return false;
    }
    return true;
  }

  /// Get human-readable file size
  String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
