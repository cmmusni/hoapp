import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A reusable widget for file uploads with preview
class FileUploadWidget extends StatefulWidget {
  final String bucket;
  final String? folder;
  final List<String>? allowedExtensions;
  final FileType fileType;
  final int maxSizeBytes;
  final Function(String url) onUploadComplete;
  final String? initialUrl;

  const FileUploadWidget({
    super.key,
    required this.bucket,
    this.folder,
    this.allowedExtensions,
    this.fileType = FileType.any,
    this.maxSizeBytes = 5 * 1024 * 1024, // 5MB default
    required this.onUploadComplete,
    this.initialUrl,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  PlatformFile? _selectedFile;
  String? _uploadedUrl;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _uploadedUrl = widget.initialUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload button
        if (_uploadedUrl == null) ...[
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Choose File'),
          ),
          const SizedBox(height: 8),
          Text(
            'Max size: ${_formatBytes(widget.maxSizeBytes)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          if (widget.allowedExtensions != null)
            Text(
              'Allowed: ${widget.allowedExtensions!.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
        ],

        // Preview/Status
        if (_selectedFile != null && _uploadedUrl == null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(_selectedFile!.name),
              subtitle: Text(_formatBytes(_selectedFile!.size)),
            ),
          ),
        ],

        if (_uploadedUrl != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Color.fromRGBO(39, 99, 67, 1),
            child: ListTile(
              leading: const Icon(Icons.check_circle,
                  color: Color.fromRGBO(39, 99, 67, 1)),
              title: const Text('File uploaded successfully'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _uploadedUrl = null;
                    _selectedFile = null;
                  });
                },
              ),
            ),
          ),
        ],

        // Error
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: Text(_error!),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _error = null;
    });

    try {
      final storageService = StorageService(Supabase.instance.client);

      // Pick file
      final file = await storageService.pickFile(
        type: widget.fileType,
        allowedExtensions: widget.allowedExtensions,
      );

      if (file == null) return; // User cancelled

      // Validate size
      if (!storageService.validateFileSize(file, widget.maxSizeBytes)) {
        setState(() {
          _error = 'File too large. Max ${_formatBytes(widget.maxSizeBytes)}';
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        _isUploading = true;
      });

      // Upload
      final url = await storageService.uploadFile(
        bucket: widget.bucket,
        file: file,
        folder: widget.folder,
      );

      setState(() {
        _uploadedUrl = url;
        _isUploading = false;
      });

      widget.onUploadComplete(url);
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        _isUploading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Simple image upload widget with preview
class ImageUploadWidget extends StatefulWidget {
  final String bucket;
  final String? folder;
  final int maxSizeBytes;
  final Function(String url) onUploadComplete;
  final String? initialUrl;

  const ImageUploadWidget({
    super.key,
    required this.bucket,
    this.folder,
    this.maxSizeBytes = 5 * 1024 * 1024, // 5MB default
    required this.onUploadComplete,
    this.initialUrl,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.broken_image)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickAndUpload,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_imageUrl == null ? Icons.upload : Icons.change_circle),
          label: Text(_isUploading
              ? 'Uploading...'
              : _imageUrl == null
                  ? 'Upload Image'
                  : 'Change Image'),
        ),
        const SizedBox(height: 4),
        Text(
          'Max size: ${_formatBytes(widget.maxSizeBytes)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickAndUpload() async {
    try {
      setState(() => _isUploading = true);

      final storageService = StorageService(Supabase.instance.client);
      final file = await storageService.pickImage();

      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      if (!storageService.validateFileSize(file, widget.maxSizeBytes)) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image too large. Max ${_formatBytes(widget.maxSizeBytes)}')),
          );
        }
        return;
      }

      final url = await storageService.uploadImage(
        bucket: widget.bucket,
        file: file,
        folder: widget.folder,
      );

      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });

      widget.onUploadComplete(url);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}
