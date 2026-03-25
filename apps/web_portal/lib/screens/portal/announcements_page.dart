import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  Future<List<Announcement>>? _announcementsFuture;
  String? _lastCommunityId;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.watch<AppState>();

    // Reload announcements if community ID changed
    if (appState.activeCommunityId != null &&
        appState.activeCommunityId != _lastCommunityId) {
      _lastCommunityId = appState.activeCommunityId;
      _loadAnnouncements();
    }
  }

  void _loadAnnouncements() {
    final appState = context.read<AppState>();
    final repo = context.read<AnnouncementRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _announcementsFuture =
            repo.getAnnouncements(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    print('DEBUG: Announcements page - isStaff: $isStaff');
    print('DEBUG: Active community ID: ${appState.activeCommunityId}');
    print('DEBUG: User roles: ${appState.userRoles}');
    print('DEBUG: Active role: ${appState.activeRole?.role}');

    return Scaffold(
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading announcements...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnnouncements,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final announcements = snapshot.data ?? [];

          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 72,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isStaff
                        ? 'Create your first announcement'
                        : 'Check back later for updates',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          // Separate pinned from regular
          final pinned = announcements.where((a) => a.pinned).toList();
          final regular = announcements.where((a) => !a.pinned).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadAnnouncements(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 1200
                    ? 3
                    : width > 800
                        ? 2
                        : 1;

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pinned.isNotEmpty) ...[
                        _buildGrid(pinned, crossAxisCount, isStaff),
                        if (regular.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'Recent',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (regular.isNotEmpty)
                        _buildGrid(regular, crossAxisCount, isStaff),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
            )
          : null,
    );
  }

  Widget _buildGrid(
      List<Announcement> items, int crossAxisCount, bool isStaff) {
    if (crossAxisCount == 1) {
      return Column(
        children: [
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _AnnouncementCard(
                announcement: a,
                isStaff: isStaff,
                onUpdated: _loadAnnouncements,
              ),
            ),
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += crossAxisCount) {
      final rowItems = items.skip(i).take(crossAxisCount).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < crossAxisCount; j++) ...[
                  if (j > 0) const SizedBox(width: 16),
                  Expanded(
                    child: j < rowItems.length
                        ? _AnnouncementCard(
                            announcement: rowItems[j],
                            isStaff: isStaff,
                            onUpdated: _loadAnnouncements,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateAnnouncementDialog(
        onCreated: _loadAnnouncements,
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isStaff;
  final VoidCallback onUpdated;

  const _AnnouncementCard({
    required this.announcement,
    required this.isStaff,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isPinned = announcement.pinned;
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      elevation: isPinned ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isPinned
            ? BorderSide(color: primaryColor.withOpacity(0.3), width: 1)
            : BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned accent bar
          if (isPinned)
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.5)],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned badge row (only if pinned)
                if (isPinned) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 13, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Title row with timestamp + menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  height: 1.3,
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(announcement.publishAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (isStaff) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            onSelected: (value) => _handleMenu(context, value),
                            icon: Icon(Icons.more_vert,
                                size: 20, color: Colors.grey[400]),
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 10),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle_pin',
                                child: Row(
                                  children: [
                                    Icon(
                                      isPinned
                                          ? Icons.push_pin_outlined
                                          : Icons.push_pin,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(isPinned ? 'Unpin' : 'Pin'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Body
                if (announcement.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    announcement.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                  ),
                ],

                // Image
                if (announcement.imageUrl != null &&
                    announcement.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        _showZoomableImage(context, announcement.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        announcement.imageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                              child:
                                  Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                ],

                // Date line
                const SizedBox(height: 14),
                Text(
                  _formatFullDate(announcement.publishAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Convert to local time for comparison
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    // If difference is negative or very small, the time is now or in the future
    if (diff.inMinutes <= 1) {
      return 'Just now';
    }

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${localDate.month}/${localDate.day}/${localDate.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    final localDate = date.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}';
  }

  void _handleMenu(BuildContext context, String value) async {
    final repo = context.read<AnnouncementRepository>();

    switch (value) {
      case 'edit':
        showDialog(
          context: context,
          builder: (context) => _EditAnnouncementDialog(
            announcement: announcement,
            onUpdated: onUpdated,
          ),
        );
        break;

      case 'toggle_pin':
        try {
          await repo.updateAnnouncement(
            announcement.id,
            {'pinned': !announcement.pinned},
          );
          onUpdated();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(announcement.pinned ? 'Unpinned' : 'Pinned'),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 24),
                const SizedBox(width: 12),
                const Text('Delete Announcement',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: const Text(
                'Are you sure you want to delete this announcement?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          try {
            await repo.deleteAnnouncement(announcement.id);
            onUpdated();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcement deleted')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        }
        break;
    }
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
                errorBuilder: (context, error, stack) => const Center(
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

class _CreateAnnouncementDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateAnnouncementDialog({required this.onCreated});

  @override
  State<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<_CreateAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _pinned = false;
  bool _isLoading = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.campaign_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Create Announcement',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter announcement title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter announcement details',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value ?? false),
                title: const Text('Pin to top'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Image (optional)',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              if (_uploadedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.network(
                        _uploadedImageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
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
            ],
          ),
        ),
      ),
      actions: [
        HOAppButton(
          label: 'Create',
          onPressed: _handleCreate,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

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
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement created')),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _EditAnnouncementDialog extends StatefulWidget {
  final Announcement announcement;
  final VoidCallback onUpdated;

  const _EditAnnouncementDialog({
    required this.announcement,
    required this.onUpdated,
  });

  @override
  State<_EditAnnouncementDialog> createState() =>
      _EditAnnouncementDialogState();
}

class _EditAnnouncementDialogState extends State<_EditAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _pinned;
  bool _isLoading = false;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.announcement.title);
    _bodyController = TextEditingController(text: widget.announcement.body);
    _pinned = widget.announcement.pinned;
    _uploadedImageUrl = widget.announcement.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Edit Announcement',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter announcement title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter announcement details',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value ?? false),
                title: const Text('Pin to top'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Image (optional)',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              if (_uploadedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.network(
                        _uploadedImageUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        HOAppButton(
          label: 'Save',
          onPressed: _handleSave,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

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
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement updated')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
