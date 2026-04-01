import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _subscribeToAnnouncements();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = context.read<AnnouncementRepository>();
      final announcements =
          await repo.getAnnouncements(appState.activeCommunityId!);

      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load announcements: ${e.toString()}')),
        );
      }
    }
  }

  void _subscribeToAnnouncements() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId == null) return;

    final repo = context.read<AnnouncementRepository>();
    _realtimeChannel = repo.subscribeToAnnouncements(
      appState.activeCommunityId!,
      (newAnnouncement) {
        if (mounted) {
          setState(() {
            _announcements.insert(0, newAnnouncement);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New announcement: ${newAnnouncement.title}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.announcement_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No announcements yet',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
            if (isStaff) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateAnnouncementDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create Announcement'),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadAnnouncements(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _announcements.length,
          itemBuilder: (context, index) {
            final announcement = _announcements[index];
            return _AnnouncementCard(
              announcement: announcement,
              onTap: () => _showAnnouncementDetails(announcement),
            );
          },
        ),
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton(
              onPressed: () => _showCreateAnnouncementDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCreateAnnouncementDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CreateAnnouncementSheet(onCreated: _loadAnnouncements),
      ),
    );
  }

  void _showEditAnnouncementSheet(dynamic announcement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditAnnouncementSheet(
          announcement: announcement,
          onUpdated: _loadAnnouncements,
        ),
      ),
    );
  }

  void _showAnnouncementDetails(dynamic announcement) {
    // Mark as read
    _markAsRead(announcement);
    final isStaff = context.read<AppState>().isStaff;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag handle & edit button row
            Padding(
              padding:
                  const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 8),
              child: Row(
                children: [
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  if (isStaff) ...[
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEditAnnouncementSheet(announcement);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit',
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xff215e3f),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, announcement),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  if (announcement.pinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 15, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(
                            announcement.publishAt ?? announcement.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  if (announcement.imageUrl != null &&
                      announcement.imageUrl!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () =>
                          _showZoomableImage(context, announcement.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          announcement.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.grey, size: 40)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    announcement.body,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  // Attachment
                  if (announcement.attachmentUrl != null &&
                      announcement.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildAttachmentChip(announcement.attachmentUrl!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(String url) {
    final fileName = _extractFileName(url);
    final ext = fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final icon = isPdf ? Icons.picture_as_pdf : Icons.description;
    final color = isPdf ? Colors.red[600]! : Colors.blue[600]!;

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ext.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final raw = segments.last;
        final underscoreIdx = raw.indexOf('_');
        if (underscoreIdx > 0 && underscoreIdx < 14) {
          return Uri.decodeComponent(raw.substring(underscoreIdx + 1));
        }
        return Uri.decodeComponent(raw);
      }
    } catch (_) {}
    return 'Document';
  }

  Future<void> _markAsRead(dynamic announcement) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('announcement_reads').upsert({
        'announcement_id': announcement.id,
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes <= 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }

  void _confirmDelete(BuildContext sheetContext, dynamic announcement) {
    showDialog(
      context: this.context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement'),
        content: const Text(
            'Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(sheetContext).pop();
              try {
                final repo = this.context.read<AnnouncementRepository>();
                await repo.deleteAnnouncement(announcement.id);
                _loadAnnouncements();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Announcement deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child:
                      Icon(Icons.broken_image, size: 64, color: Colors.white70),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final dynamic announcement;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.pinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded,
                            size: 13, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Text(
                announcement.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (announcement.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    announcement.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                announcement.body,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(
                        announcement.publishAt ?? announcement.createdAt),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                  if (announcement.attachmentUrl != null &&
                      announcement.attachmentUrl!.isNotEmpty) ...[
                    const Spacer(),
                    Icon(
                      announcement.attachmentUrl!.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf
                          : Icons.description,
                      size: 16,
                      color: announcement.attachmentUrl!
                              .toLowerCase()
                              .endsWith('.pdf')
                          ? Colors.red[400]
                          : Colors.blue[400],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes <= 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }
}

class _EditAnnouncementSheet extends StatefulWidget {
  final dynamic announcement;
  final VoidCallback onUpdated;

  const _EditAnnouncementSheet({
    required this.announcement,
    required this.onUpdated,
  });

  @override
  State<_EditAnnouncementSheet> createState() => _EditAnnouncementSheetState();
}

class _EditAnnouncementSheetState extends State<_EditAnnouncementSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _pinned;
  bool _isLoading = false;
  String? _uploadedImageUrl;
  String? _uploadedAttachmentUrl;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _bodyController = TextEditingController(text: widget.announcement.body);
    _pinned = widget.announcement.pinned;
    _uploadedImageUrl = widget.announcement.imageUrl;
    _uploadedAttachmentUrl = widget.announcement.attachmentUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xff215e3f);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[350],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: brandColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Edit Announcement',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: brandColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: brandColor, width: 1.5),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              // Image upload section
              Text('Image (optional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              if (_uploadedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        _uploadedImageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _uploadedImageUrl = null),
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black54),
                          iconSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ImageUploadWidget(
                  bucket: 'announcement-images',
                  folder: context.read<AppState>().activeCommunityId,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() => _uploadedImageUrl = url);
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Document attachment section
              Text('Document (optional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              if (_uploadedAttachmentUrl != null) ...[
                _buildAttachmentCard(
                  _uploadedAttachmentUrl!,
                  onRemove: () => setState(() => _uploadedAttachmentUrl = null),
                ),
              ] else ...[
                FileUploadWidget(
                  bucket: 'announcement-attachments',
                  folder: context.read<AppState>().activeCommunityId,
                  fileType: FileType.custom,
                  allowedExtensions: const ['pdf', 'doc', 'docx'],
                  maxSizeBytes: 25 * 1024 * 1024,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() => _uploadedAttachmentUrl = url);
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _pinned
                      ? brandColor.withOpacity(0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Pin announcement',
                      style: TextStyle(fontSize: 14)),
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  activeColor: brandColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleUpdate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = context.read<AnnouncementRepository>();
      await repo.updateAnnouncement(
        widget.announcement.id,
        {
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'pinned': _pinned,
          'image_url': _uploadedImageUrl,
          'attachment_url': _uploadedAttachmentUrl,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAttachmentCard(String url, {required VoidCallback onRemove}) {
    final fileName = _extractFileName(url);
    final ext = fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final icon = isPdf ? Icons.picture_as_pdf : Icons.description;
    final color = isPdf ? Colors.red[600]! : Colors.blue[600]!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(ext.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final raw = segments.last;
        final underscoreIdx = raw.indexOf('_');
        if (underscoreIdx > 0 && underscoreIdx < 14) {
          return Uri.decodeComponent(raw.substring(underscoreIdx + 1));
        }
        return Uri.decodeComponent(raw);
      }
    } catch (_) {}
    return 'Document';
  }
}

class _CreateAnnouncementSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateAnnouncementSheet({required this.onCreated});

  @override
  State<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<_CreateAnnouncementSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _pinned = false;
  bool _isLoading = false;
  String? _uploadedImageUrl;
  String? _uploadedAttachmentUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xff215e3f);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[350],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: brandColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Create Announcement',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: brandColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: brandColor, width: 1.5),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              // Image upload section
              Text('Image (optional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              if (_uploadedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        _uploadedImageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _uploadedImageUrl = null),
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black54),
                          iconSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ImageUploadWidget(
                  bucket: 'announcement-images',
                  folder: context.read<AppState>().activeCommunityId,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() => _uploadedImageUrl = url);
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Document attachment section
              Text('Document (optional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 8),
              if (_uploadedAttachmentUrl != null) ...[
                _buildAttachmentCard(
                  _uploadedAttachmentUrl!,
                  onRemove: () => setState(() => _uploadedAttachmentUrl = null),
                ),
              ] else ...[
                FileUploadWidget(
                  bucket: 'announcement-attachments',
                  folder: context.read<AppState>().activeCommunityId,
                  fileType: FileType.custom,
                  allowedExtensions: const ['pdf', 'doc', 'docx'],
                  maxSizeBytes: 25 * 1024 * 1024,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() => _uploadedAttachmentUrl = url);
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _pinned
                      ? brandColor.withOpacity(0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Pin announcement',
                      style: TextStyle(fontSize: 14)),
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  activeColor: brandColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCreate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isLoading ? 'Publishing...' : 'Publish',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<AnnouncementRepository>();
      await repo.createAnnouncement(
        communityId: appState.activeCommunityId!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        pinned: _pinned,
        imageUrl: _uploadedImageUrl,
        attachmentUrl: _uploadedAttachmentUrl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAttachmentCard(String url, {required VoidCallback onRemove}) {
    final fileName = _extractFileName(url);
    final ext = fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final icon = isPdf ? Icons.picture_as_pdf : Icons.description;
    final color = isPdf ? Colors.red[600]! : Colors.blue[600]!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(ext.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final raw = segments.last;
        final underscoreIdx = raw.indexOf('_');
        if (underscoreIdx > 0 && underscoreIdx < 14) {
          return Uri.decodeComponent(raw.substring(underscoreIdx + 1));
        }
        return Uri.decodeComponent(raw);
      }
    } catch (_) {}
    return 'Document';
  }
}
