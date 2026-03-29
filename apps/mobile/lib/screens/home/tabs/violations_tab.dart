import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViolationsTab extends StatefulWidget {
  const ViolationsTab({super.key});

  @override
  State<ViolationsTab> createState() => _ViolationsTabState();
}

class _ViolationsTabState extends State<ViolationsTab> {
  Future<List<dynamic>>? _violationsFuture;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  void _loadViolations() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null) {
      final repo = context.read<ViolationRepository>();
      setState(() {
        _violationsFuture = repo.getViolations(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    return Scaffold(
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('New', 'new'),
                _buildFilterChip('Under Review', 'under_review'),
                _buildFilterChip('Resolved', 'resolved'),
                _buildFilterChip('Dismissed', 'dismissed'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _violationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadViolations,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final violations = (snapshot.data ?? []).where((v) {
                  if (_filterStatus == 'all') return true;
                  return v.status.toString().contains(_filterStatus);
                }).toList();

                if (violations.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Color(0xff215e3f)),
                        SizedBox(height: 16),
                        Text('No violations found'),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadViolations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: violations.length,
                    itemBuilder: (context, index) {
                      final violation = violations[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(violation.status),
                            child: Icon(
                              _getStatusIcon(violation.status),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(violation.title),
                          subtitle: Text(
                            _formatDate(violation.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Chip(
                            label: Text(
                              _getStatusLabel(violation.status),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _getStatusColor(violation.status)
                                .withOpacity(0.2),
                          ),
                          onTap: () => _showViolationDetails(violation),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportDialog(),
        icon: const Icon(Icons.report),
        label: const Text('Report'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xff215e3f).withOpacity(0.15),
        checkmarkColor: const Color(0xff215e3f),
        onSelected: (_) => setState(() => _filterStatus = value),
      ),
    );
  }

  void _showReportDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _ReportViolationScreen(onReported: _loadViolations),
        fullscreenDialog: true,
      ),
    );
  }

  void _showViolationDetails(Violation violation) {
    final isStaff = context.read<AppState>().isStaff;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnReport =
        currentUserId != null && violation.reporterUserId == currentUserId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(violation.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(_getStatusLabel(violation.status)),
                backgroundColor:
                    _getStatusColor(violation.status).withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(violation.body,
                style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            Text('Reported: ${_formatDate(violation.createdAt)}',
                style: TextStyle(color: Colors.grey[600])),

            // Attachments
            if (violation.attachments != null &&
                violation.attachments!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Attachments',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: violation.attachments!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = violation.attachments![index]?.toString() ?? '';
                    if (url.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => _showZoomableImage(context, url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Staff notes
            if (violation.staffNotes != null &&
                violation.staffNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Staff Notes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(violation.staffNotes!,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ],

            // Edit own violation
            if (isOwnReport &&
                violation.status == ViolationStatus.newStatus) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _editViolation(violation);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Report'),
                ),
              ),
            ],

            // Staff actions
            if (isStaff) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDeleteViolation(violation);
                    },
                  ),
                  const Spacer(),
                  if (violation.status != ViolationStatus.resolved)
                    PopupMenuButton<ViolationStatus>(
                      child: const Chip(
                        avatar: Icon(Icons.edit, size: 16),
                        label: Text('Update Status'),
                      ),
                      onSelected: (status) {
                        Navigator.of(sheetContext).pop();
                        _updateViolationStatus(violation, status);
                      },
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
      ),
    );
  }

  void _confirmDeleteViolation(Violation violation) {
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
              _deleteViolation(violation);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteViolation(Violation violation) async {
    try {
      final repo = context.read<ViolationRepository>();
      await repo.deleteViolation(violation.id);
      _loadViolations();
      if (mounted) {
        context.read<AppState>().requestBadgeRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting violation: $e')),
        );
      }
    }
  }

  Future<void> _updateViolationStatus(
      Violation violation, ViolationStatus status) async {
    try {
      final repo = context.read<ViolationRepository>();
      await repo.updateViolation(id: violation.id, status: status);
      _loadViolations();
      if (mounted) {
        context.read<AppState>().requestBadgeRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return Colors.orange;
    if (statusStr.contains('under')) return Colors.blue;
    if (statusStr.contains('resolved')) return const Color(0xff215e3f);
    if (statusStr.contains('dismissed')) return Colors.grey;
    return Colors.grey;
  }

  IconData _getStatusIcon(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return Icons.fiber_new;
    if (statusStr.contains('under')) return Icons.pending;
    if (statusStr.contains('resolved')) return Icons.check_circle;
    if (statusStr.contains('dismissed')) return Icons.cancel;
    return Icons.report;
  }

  String _getStatusLabel(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('new')) return 'NEW';
    if (statusStr.contains('under')) return 'UNDER REVIEW';
    if (statusStr.contains('resolved')) return 'RESOLVED';
    if (statusStr.contains('dismissed')) return 'DISMISSED';
    return 'UNKNOWN';
  }

  void _editViolation(Violation violation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _EditViolationScreen(
          violation: violation,
          onUpdated: _loadViolations,
        ),
        fullscreenDialog: true,
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

class _ReportViolationScreen extends StatefulWidget {
  final VoidCallback onReported;

  const _ReportViolationScreen({required this.onReported});

  @override
  State<_ReportViolationScreen> createState() => _ReportViolationScreenState();
}

class _ReportViolationScreenState extends State<_ReportViolationScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Violation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your identity will remain anonymous to other residents',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Brief description',
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide details';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Photos (optional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            if (_uploadedImageUrls.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedImageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _uploadedImageUrls[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _uploadedImageUrls.removeAt(index)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_uploadedImageUrls.length < 5)
              ImageUploadWidget(
                bucket: 'violation-photos',
                folder: context.read<AppState>().activeCommunityId,
                onUploadComplete: (url) {
                  if (url.isNotEmpty) {
                    setState(() => _uploadedImageUrls.add(url));
                  }
                },
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<ViolationRepository>();

      await repo.createViolation(
        communityId: appState.activeCommunityId!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        attachmentUrls:
            _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Violation reported successfully')),
        );
        widget.onReported();
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
}

class _EditViolationScreen extends StatefulWidget {
  final Violation violation;
  final VoidCallback onUpdated;

  const _EditViolationScreen({
    required this.violation,
    required this.onUpdated,
  });

  @override
  State<_EditViolationScreen> createState() => _EditViolationScreenState();
}

class _EditViolationScreenState extends State<_EditViolationScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Violation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Brief description',
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide details';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Photos (optional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            if (_uploadedImageUrls.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedImageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _uploadedImageUrls[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _uploadedImageUrls.removeAt(index)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_uploadedImageUrls.length < 5)
              ImageUploadWidget(
                bucket: 'violation-photos',
                folder: context.read<AppState>().activeCommunityId,
                onUploadComplete: (url) {
                  if (url.isNotEmpty) {
                    setState(() => _uploadedImageUrls.add(url));
                  }
                },
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
