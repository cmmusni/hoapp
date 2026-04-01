import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';
import '../adaptive/adaptive_layout.dart';
import '../widgets/file_upload_widget.dart';

const _brand = Color(0xff215e3f);

/// Shared feedback screen — adaptive for web and mobile.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filterStatus = 'all';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<CommunityRepository>();
      final communityId = appState.activeCommunityId;
      if (communityId != null) {
        final data = await repo.getFeedback(communityId);
        if (mounted) setState(() => _items = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _items.where((item) {
      if (_filterStatus != 'all' && item['status'] != _filterStatus) {
        return false;
      }
      if (_filterCategory != 'all' && item['category'] != _filterCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    return Scaffold(
      body: Column(
        children: [
          // Status filter
          if (screenSizeOf(context) == ScreenSize.mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: DropdownButtonFormField<String>(
                value: _filterStatus,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.filter_list_rounded,
                      size: 20, color: Colors.grey.shade600),
                  labelText: 'Filter by status',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                items: [
                  _dropdownItem('All', 'all', Icons.list_rounded),
                  _dropdownItem('Open', 'open', Icons.lock_open_rounded),
                  if (isStaff) ...[
                    _dropdownItem(
                        'In Review', 'in_review', Icons.rate_review_rounded),
                    _dropdownItem('Planned', 'planned', Icons.schedule_rounded),
                  ],
                  _dropdownItem('Resolved', 'resolved',
                      Icons.check_circle_outline_rounded),
                  _dropdownItem('Closed', 'closed', Icons.lock_rounded),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _filterStatus = v);
                },
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Open', 'open'),
                if (isStaff) ...[
                  _buildFilterChip('In Review', 'in_review'),
                  _buildFilterChip('Planned', 'planned'),
                ],
                _buildFilterChip('Resolved', 'resolved'),
                _buildFilterChip('Closed', 'closed'),
              ]),
            ),
          // Category dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: _filterCategory,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.category_rounded,
                    size: 20, color: Colors.grey.shade600),
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: [
                _dropdownItem('All Categories', 'all', Icons.list_rounded),
                _dropdownItem('Bug Report', 'bug', Icons.bug_report_rounded),
                _dropdownItem('Feature Request', 'feature_request',
                    Icons.lightbulb_rounded),
                _dropdownItem(
                    'Improvement', 'improvement', Icons.trending_up_rounded),
                _dropdownItem('General', 'general', Icons.chat_rounded),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _filterCategory = v);
              },
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(children: [
                                Icon(Icons.feedback_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _items.isEmpty
                                      ? 'No feedback yet'
                                      : 'No matches',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ]),
                            ),
                          ])
                        : AdaptiveBuilder(
                            mobile: (_) => ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) => _FeedbackCard(
                                item: _filtered[i],
                                isStaff: isStaff,
                                onUpdated: _load,
                              ),
                            ),
                            desktop: (_) => GridView.builder(
                              padding: const EdgeInsets.all(24),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 500,
                                childAspectRatio: 1.8,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) => _FeedbackCard(
                                item: _filtered[i],
                                isStaff: isStaff,
                                onUpdated: _load,
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: screenSizeOf(context) == ScreenSize.mobile
          ? FloatingActionButton(
              onPressed: () => _showSubmitSheet(context),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showSubmitSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Submit Feedback'),
            ),
      floatingActionButtonLocation: screenSizeOf(context) == ScreenSize.mobile
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    final isMobile = screenSizeOf(context) == ScreenSize.mobile;
    return Padding(
      padding: EdgeInsets.only(right: isMobile ? 0 : 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: isMobile ? 12 : null)),
        selected: isSelected,
        showCheckmark: !isMobile,
        visualDensity: isMobile ? VisualDensity.compact : null,
        materialTapTargetSize:
            isMobile ? MaterialTapTargetSize.shrinkWrap : null,
        padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
        labelStyle:
            TextStyle(color: isSelected ? Colors.white : Colors.grey[700]),
        backgroundColor: Colors.grey[200],
        selectedColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
        checkmarkColor: Colors.white,
        onSelected: (_) => setState(() => _filterStatus = value),
      ),
    );
  }

  DropdownMenuItem<String> _dropdownItem(
      String label, String value, IconData icon) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  void _showSubmitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SubmitFeedbackSheet(onSubmitted: _load),
      ),
    );
  }
}

// ─── Feedback Card ───────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isStaff;
  final VoidCallback onUpdated;

  const _FeedbackCard({
    required this.item,
    required this.isStaff,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final category = item['category'] as String? ?? 'general';
    final status = item['status'] as String? ?? 'open';
    final subject = item['subject'] as String? ?? 'No subject';
    final description = item['description'] as String? ?? '';
    final imageUrl = item['image_url'] as String?;
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_categoryIcon(category),
                    size: 18, color: _categoryColor(category)),
                const SizedBox(width: 6),
                Text(category.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _categoryColor(category))),
                const Spacer(),
                Chip(
                  label: Text(status.toUpperCase(),
                      style: const TextStyle(fontSize: 10)),
                  backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
              const SizedBox(height: 8),
              Text(subject,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.image_outlined,
                      size: 14, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text('Image attached',
                      style:
                          TextStyle(fontSize: 12, color: Colors.blue.shade400)),
                ]),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(DateFormat('MMM d, yyyy').format(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final adminNotes = item['admin_notes'] as String?;
    final description = item['description'] as String? ?? '';
    final imageUrl = item['image_url'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, sc) => ListView(
          controller: sc,
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
            Text(item['subject'] ?? 'No subject',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(height: 1.5)),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Attached Image',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ],
            if (adminNotes != null && adminNotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _brand.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin Response',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(adminNotes),
                  ],
                ),
              ),
            ],
            if (isStaff) ...[
              const SizedBox(height: 20),
              _AdminActions(
                item: item,
                onUpdated: () {
                  Navigator.of(context).pop();
                  onUpdated();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String c) => switch (c) {
        'bug' => Icons.bug_report,
        'feature_request' => Icons.lightbulb,
        'improvement' => Icons.trending_up,
        _ => Icons.chat,
      };

  Color _categoryColor(String c) => switch (c) {
        'bug' => Colors.red,
        'feature_request' => Colors.blue,
        'improvement' => Colors.orange,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => Colors.orange,
        'in_review' => Colors.blue,
        'planned' => Colors.purple,
        'resolved' => _brand,
        _ => Colors.grey,
      };
}

// ─── Admin Actions ───────────────────────────────────────────────────────────

class _AdminActions extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onUpdated;
  const _AdminActions({required this.item, required this.onUpdated});

  @override
  State<_AdminActions> createState() => _AdminActionsState();
}

class _AdminActionsState extends State<_AdminActions> {
  late String _status;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item['status'] ?? 'open';
    _notesCtrl.text = widget.item['admin_notes'] ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Admin Actions',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: InputDecoration(
              labelText: 'Status',
              prefixIcon: const Icon(Icons.flag_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brand, width: 1.5),
              )),
          items: const [
            DropdownMenuItem(value: 'open', child: Text('Open')),
            DropdownMenuItem(value: 'in_review', child: Text('In Review')),
            DropdownMenuItem(value: 'planned', child: Text('Planned')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
            DropdownMenuItem(value: 'closed', child: Text('Closed')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _status = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Admin Notes',
            prefixIcon: const Icon(Icons.notes_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brand, width: 1.5),
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _handleSave,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Changes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _handleDelete(context),
          ),
        ]),
      ],
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      final repo = context.read<CommunityRepository>();
      await repo.updateFeedback(
        feedbackId: widget.item['id'],
        status: _status,
        adminNotes: _notesCtrl.text.trim(),
      );
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final repo = context.read<CommunityRepository>();
        await repo.deleteFeedback(widget.item['id']);
        widget.onUpdated();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ─── Submit Feedback Sheet ───────────────────────────────────────────────────

class _SubmitFeedbackSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _SubmitFeedbackSheet({required this.onSubmitted});

  @override
  State<_SubmitFeedbackSheet> createState() => _SubmitFeedbackSheetState();
}

class _SubmitFeedbackSheetState extends State<_SubmitFeedbackSheet> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'general';
  String? _uploadedImageUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit Feedback',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Category'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _catChip('General', 'general'),
              _catChip('Bug Report', 'bug'),
              _catChip('Feature Request', 'feature_request'),
              _catChip('Improvement', 'improvement'),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: const Icon(Icons.subject_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.5),
                  )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                prefixIcon: const Icon(Icons.description_outlined, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Attach Image (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            ImageUploadWidget(
              bucket: 'feedback-images',
              folder: context.read<AppState>().activeCommunityId,
              onUploadComplete: (url) {
                if (url.isNotEmpty) {
                  setState(() => _uploadedImageUrl = url);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSubmit,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Submit',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _category == value,
      selectedColor: _brand.withValues(alpha: 0.15),
      onSelected: (_) => setState(() => _category = value),
    );
  }

  Future<void> _handleSubmit() async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and description are required')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = context.read<CommunityRepository>();
      await repo.submitFeedback(
        communityId: appState.activeCommunityId!,
        category: _category,
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageUrl: _uploadedImageUrl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
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
