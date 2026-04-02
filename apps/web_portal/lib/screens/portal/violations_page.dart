import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class ViolationsPage extends StatefulWidget {
  const ViolationsPage({super.key});

  @override
  State<ViolationsPage> createState() => _ViolationsPageState();
}

class _ViolationsPageState extends State<ViolationsPage> {
  Future<List<Violation>>? _violationsFuture;
  ViolationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  void _loadViolations() {
    final appState = context.read<AppState>();
    final repo = context.read<ViolationRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        if (_filterStatus != null) {
          _violationsFuture = repo.getViolationsByStatus(
            appState.activeCommunityId!,
            _filterStatus!,
          );
        } else {
          _violationsFuture = repo.getViolations(appState.activeCommunityId!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    icon: Icons.list,
                    selected: _filterStatus == null,
                    onSelected: () {
                      setState(() => _filterStatus = null);
                      _loadViolations();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'New',
                    icon: Icons.fiber_new,
                    selectedColor: Colors.orange,
                    selected: _filterStatus == ViolationStatus.newStatus,
                    onSelected: () {
                      setState(() => _filterStatus = ViolationStatus.newStatus);
                      _loadViolations();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Under Review',
                    icon: Icons.hourglass_top,
                    selectedColor: Colors.blue,
                    selected: _filterStatus == ViolationStatus.underReview,
                    onSelected: () {
                      setState(
                          () => _filterStatus = ViolationStatus.underReview);
                      _loadViolations();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Resolved',
                    icon: Icons.check_circle_outline,
                    selectedColor: const Color.fromRGBO(39, 99, 67, 1),
                    selected: _filterStatus == ViolationStatus.resolved,
                    onSelected: () {
                      setState(() => _filterStatus = ViolationStatus.resolved);
                      _loadViolations();
                    },
                  ),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<List<Violation>>(
              future: _violationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(
                      message: 'Loading violations...');
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final violations = snapshot.data ?? [];

                if (violations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No violations reported',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Submit a report to get started'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: violations.length,
                  itemBuilder: (context, index) => _ViolationCard(
                    violation: violations[index],
                    isStaff: appState.isStaff,
                    currentUserId:
                        SupabaseClientManager.instance.auth.currentUser?.id,
                    onUpdated: _loadViolations,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width > 800
          ? FloatingActionButton.extended(
              onPressed: () => _showReportDialog(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Report Violation',
                  style: TextStyle(color: Colors.white)),
            )
          : FloatingActionButton(
              onPressed: () => _showReportDialog(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      floatingActionButtonLocation: MediaQuery.of(context).size.width > 800
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ReportViolationDialog(onReported: _loadViolations),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? color.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16, color: selected ? color : Colors.grey.shade600),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  final Violation violation;
  final bool isStaff;
  final String? currentUserId;
  final VoidCallback onUpdated;

  const _ViolationCard({
    required this.violation,
    required this.isStaff,
    this.currentUserId,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return HOAppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: violation.status),
              const Spacer(),
              Text(
                _formatDate(violation.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            violation.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(violation.body),

          // Display attachments if available
          if (violation.attachments != null &&
              violation.attachments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                // Filter out null values and convert to strings
                final imageUrls = violation.attachments!
                    .where((item) => item != null && item.toString().isNotEmpty)
                    .map((item) => item.toString())
                    .toList();

                if (imageUrls.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    separatorBuilder: (context, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imageUrl = imageUrls[index];
                      return GestureDetector(
                        onTap: () => _showZoomableImage(context, imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],

          // Edit own violation
          if (currentUserId != null &&
              violation.reporterUserId == currentUserId &&
              violation.status == ViolationStatus.newStatus) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Report'),
                onPressed: () => _showEditDialog(context),
              ),
            ),
          ],

          if (isStaff) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () => _confirmDelete(context),
                ),
                const Spacer(),
                if (violation.status != ViolationStatus.resolved)
                  PopupMenuButton<ViolationStatus>(
                    child: Chip(
                      avatar: const Icon(Icons.edit, size: 16),
                      label: const Text('Update Status'),
                    ),
                    onSelected: (status) => _updateStatus(context, status),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: ViolationStatus.underReview,
                        child: Text('Under Review'),
                      ),
                      const PopupMenuItem(
                        value: ViolationStatus.resolved,
                        child: Text('Resolved'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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

  Future<void> _updateStatus(
      BuildContext context, ViolationStatus status) async {
    try {
      final repo = context.read<ViolationRepository>();
      await repo.updateViolation(id: violation.id, status: status);
      onUpdated();
      if (context.mounted) {
        context.read<AppState>().requestBadgeRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Violation'),
        content: Text(
            'Are you sure you want to delete "${violation.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteViolation(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteViolation(BuildContext context) async {
    try {
      final repo = context.read<ViolationRepository>();
      await repo.deleteViolation(violation.id);
      onUpdated();
      if (context.mounted) {
        context.read<AppState>().requestBadgeRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting violation: $e')),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditViolationDialog(
        violation: violation,
        onUpdated: onUpdated,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ViolationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case ViolationStatus.newStatus:
        color = Colors.orange;
        label = 'NEW';
        break;
      case ViolationStatus.underReview:
        color = Colors.blue;
        label = 'UNDER REVIEW';
        break;
      case ViolationStatus.resolved:
        color = Color.fromRGBO(39, 99, 67, 1);
        label = 'RESOLVED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ReportViolationDialog extends StatefulWidget {
  final VoidCallback onReported;

  const _ReportViolationDialog({required this.onReported});

  @override
  State<_ReportViolationDialog> createState() => _ReportViolationDialogState();
}

class _ReportViolationDialogState extends State<_ReportViolationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  final List<String> _uploadedImageUrls = [];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final communityId = context.read<AppState>().activeCommunityId ?? '';
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.report_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text('Report Violation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your identity will remain anonymous to other residents',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Brief description',
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
                  labelText: 'Details',
                  hintText: 'Provide detailed information',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Image upload section
              if (_uploadedImageUrls.length < 5) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Photos (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ImageUploadWidget(
                  bucket: 'violation-photos',
                  folder: communityId.isNotEmpty ? communityId : null,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() {
                        _uploadedImageUrls.add(url);
                      });
                    }
                  },
                ),
              ],
              // Display uploaded images
              if (_uploadedImageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_uploadedImageUrls.length, (index) {
                    final url = _uploadedImageUrls[index];
                    if (url.isEmpty) return const SizedBox.shrink();

                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, size: 40),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _uploadedImageUrls.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_uploadedImageUrls.length}/5 photos uploaded',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleSubmit,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.report_outlined, color: Colors.white),
            label: const Text('Submit Report',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppState>();
    if (appState.activeCommunityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No community selected')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = context.read<ViolationRepository>();

      final title = _titleController.text.trim();
      await repo.createViolation(
        communityId: appState.activeCommunityId!,
        title: title,
        body: _bodyController.text.trim(),
        attachmentUrls:
            _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls : null,
      );

      // Send push notification to community staff
      NotificationService().send(
        communityId: appState.activeCommunityId!,
        heading: 'New Violation Reported',
        content: title,
        data: {'type': 'violation'},
      );

      if (mounted) {
        context.read<AppState>().requestBadgeRefresh();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation reported')),
        );
        widget.onReported();
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

class _EditViolationDialog extends StatefulWidget {
  final Violation violation;
  final VoidCallback onUpdated;

  const _EditViolationDialog({
    required this.violation,
    required this.onUpdated,
  });

  @override
  State<_EditViolationDialog> createState() => _EditViolationDialogState();
}

class _EditViolationDialogState extends State<_EditViolationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final List<String> _uploadedImageUrls;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.violation.title);
    _bodyController = TextEditingController(text: widget.violation.body);
    _uploadedImageUrls = (widget.violation.attachments ?? [])
        .where((item) => item != null && item.toString().isNotEmpty)
        .map((item) => item.toString())
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final communityId = context.read<AppState>().activeCommunityId ?? '';
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text('Edit Violation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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
                  hintText: 'Brief description',
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
                  labelText: 'Details',
                  hintText: 'Provide detailed information',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_uploadedImageUrls.length < 5) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Photos (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ImageUploadWidget(
                  bucket: 'violation-photos',
                  folder: communityId.isNotEmpty ? communityId : null,
                  onUploadComplete: (url) {
                    if (url.isNotEmpty) {
                      setState(() => _uploadedImageUrls.add(url));
                    }
                  },
                ),
              ],
              if (_uploadedImageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_uploadedImageUrls.length, (index) {
                    final url = _uploadedImageUrls[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _uploadedImageUrls.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_uploadedImageUrls.length}/5 photos',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleSave,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(
                    Icons.save_outlined,
                    color: Colors.white,
                  ),
            label: const Text('Save Changes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<ViolationRepository>();

      await repo.updateViolation(
        id: widget.violation.id,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        attachmentUrls: _uploadedImageUrls,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation updated')),
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
