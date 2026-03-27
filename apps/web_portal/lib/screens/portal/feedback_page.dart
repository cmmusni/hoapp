import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const _brand = Color(0xff215e3f);

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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading feedback: $e')));
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
          // Header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feedback',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isStaff
                                ? 'Manage feedback from community members'
                                : 'Share your ideas, report bugs, or suggest improvements',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSubmitDialog(context),
                      icon:
                          const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('Submit Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filters
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('All', 'all', _filterStatus,
                        (v) => setState(() => _filterStatus = v)),
                    _buildFilterChip('Open', 'open', _filterStatus,
                        (v) => setState(() => _filterStatus = v)),
                    if (isStaff) ...[
                      _buildFilterChip('In Review', 'in_review', _filterStatus,
                          (v) => setState(() => _filterStatus = v)),
                      _buildFilterChip('Planned', 'planned', _filterStatus,
                          (v) => setState(() => _filterStatus = v)),
                    ],
                    _buildFilterChip('Resolved', 'resolved', _filterStatus,
                        (v) => setState(() => _filterStatus = v)),
                    _buildFilterChip('Closed', 'closed', _filterStatus,
                        (v) => setState(() => _filterStatus = v)),
                    const SizedBox(width: 8),
                    // Category filter
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterCategory,
                          isDense: true,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All Categories')),
                            DropdownMenuItem(
                                value: 'bug', child: Text('Bug Report')),
                            DropdownMenuItem(
                                value: 'feature_request',
                                child: Text('Feature Request')),
                            DropdownMenuItem(
                                value: 'improvement',
                                child: Text('Improvement')),
                            DropdownMenuItem(
                                value: 'general', child: Text('General')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _filterCategory = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feedback_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _items.isEmpty
                                  ? 'No feedback yet'
                                  : 'No feedback matches your filters',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 16),
                            ),
                            if (_items.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to share your thoughts!',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) =>
                              _buildFeedbackCard(_filtered[i], isStaff),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: _brand.withOpacity(0.15),
      checkmarkColor: _brand,
      side: BorderSide(color: selected ? _brand : Colors.grey.shade300),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? _brand : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> item, bool isStaff) {
    final category = item['category'] as String? ?? 'general';
    final status = item['status'] as String? ?? 'open';
    final subject = item['subject'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final email = item['user_email'] as String? ?? '';
    final adminNotes = item['admin_notes'] as String?;
    final imageUrl = item['image_url'] as String?;
    final createdAt = DateTime.tryParse(item['created_at'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailDialog(context, item, isStaff),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _categoryIcon(category),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _categoryBadge(category),
                  const Spacer(),
                  if (isStaff) ...[
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(email,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(width: 12),
                  ],
                  if (adminNotes != null && adminNotes.isNotEmpty) ...[
                    Icon(Icons.comment_outlined,
                        size: 14, color: Colors.orange.shade400),
                    const SizedBox(width: 4),
                  ],
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    Icon(Icons.image_outlined,
                        size: 14, color: Colors.blue.shade400),
                    const SizedBox(width: 4),
                  ],
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null
                        ? DateFormat('MMM d, yyyy').format(createdAt.toLocal())
                        : '',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(String category) {
    final (IconData icon, Color color) = switch (category) {
      'bug' => (Icons.bug_report, Colors.red.shade600),
      'feature_request' => (Icons.lightbulb_outline, Colors.amber.shade700),
      'improvement' => (Icons.trending_up, Colors.blue.shade600),
      _ => (Icons.chat_bubble_outline, Colors.grey.shade600),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _categoryBadge(String category) {
    final (String label, Color color) = switch (category) {
      'bug' => ('Bug', Colors.red),
      'feature_request' => ('Feature Request', Colors.amber.shade800),
      'improvement' => ('Improvement', Colors.blue),
      _ => ('General', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(String status) {
    final (String label, Color color) = switch (status) {
      'open' => ('Open', Colors.blue),
      'in_review' => ('In Review', Colors.orange),
      'planned' => ('Planned', Colors.purple),
      'resolved' => ('Resolved', Colors.green),
      'closed' => ('Closed', Colors.grey),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ============ SUBMIT FEEDBACK DIALOG ============

  void _showSubmitDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'general';
    String? uploadedImageUrl;
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_brand, Color(0xff2e8b57)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.feedback_outlined,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Submit Feedback',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Help us improve your experience',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category selector
                        const Text('Category',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _dialogCategoryChip(
                                ctx,
                                'Bug Report',
                                'bug',
                                Icons.bug_report,
                                Colors.red,
                                category,
                                (v) => setDialogState(() => category = v)),
                            _dialogCategoryChip(
                                ctx,
                                'Feature',
                                'feature_request',
                                Icons.lightbulb_outline,
                                Colors.amber.shade800,
                                category,
                                (v) => setDialogState(() => category = v)),
                            _dialogCategoryChip(
                                ctx,
                                'Improvement',
                                'improvement',
                                Icons.trending_up,
                                Colors.blue,
                                category,
                                (v) => setDialogState(() => category = v)),
                            _dialogCategoryChip(
                                ctx,
                                'General',
                                'general',
                                Icons.chat_bubble_outline,
                                Colors.grey,
                                category,
                                (v) => setDialogState(() => category = v)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.short_text),
                          ),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description_outlined),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        const Text('Attach Image (optional)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        ImageUploadWidget(
                          bucket: 'feedback-images',
                          folder: context.read<AppState>().activeCommunityId,
                          onUploadComplete: (url) {
                            if (url.isNotEmpty) {
                              setDialogState(() => uploadedImageUrl = url);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate())
                                      return;
                                    setDialogState(() => submitting = true);
                                    try {
                                      final appState = context.read<AppState>();
                                      final repo =
                                          context.read<CommunityRepository>();
                                      await repo.submitFeedback(
                                        communityId:
                                            appState.activeCommunityId!,
                                        category: category,
                                        subject: subjectCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        imageUrl: uploadedImageUrl,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _load();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Feedback submitted! Thank you.'),
                                          backgroundColor: _brand,
                                        ));
                                      }
                                    } catch (e) {
                                      setDialogState(() => submitting = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            label:
                                Text(submitting ? 'Submitting...' : 'Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogCategoryChip(BuildContext ctx, String label, String value,
      IconData icon, Color color, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  // ============ DELETE FEEDBACK ============

  void _confirmDeleteFeedback(BuildContext dialogCtx, String feedbackId) {
    showDialog(
      context: dialogCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text(
            'Are you sure you want to delete this feedback? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // close confirm dialog
              Navigator.pop(dialogCtx); // close detail dialog
              try {
                final repo = context.read<CommunityRepository>();
                await repo.deleteFeedback(feedbackId);
                _load();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Feedback deleted'),
                    backgroundColor: _brand,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting feedback: $e')),
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

  // ============ DETAIL DIALOG ============

  void _showDetailDialog(
      BuildContext context, Map<String, dynamic> item, bool isStaff) {
    final subject = item['subject'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final category = item['category'] as String? ?? 'general';
    final email = item['user_email'] as String? ?? '';
    final adminNotes = item['admin_notes'] as String? ?? '';
    final imageUrl = item['image_url'] as String?;
    final createdAt = DateTime.tryParse(item['created_at'] ?? '');
    String status = item['status'] as String? ?? 'open';
    final notesCtrl = TextEditingController(text: adminNotes);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_brand, Color(0xff2e8b57)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        _categoryIcon(category),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(subject,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _categoryBadge(category),
                                  const SizedBox(width: 8),
                                  _statusBadge(status),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white70),
                          onPressed: () =>
                              _confirmDeleteFeedback(ctx, item['id']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Delete',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meta row
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(email,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13)),
                              const Spacer(),
                              Icon(Icons.schedule,
                                  size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                createdAt != null
                                    ? DateFormat('MMM d, yyyy h:mm a')
                                        .format(createdAt.toLocal())
                                    : '',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Description',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SelectableText(
                              description,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                          // Attached image
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Attached Image',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) {
                                  return Container(
                                    height: 120,
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.broken_image)),
                                  );
                                },
                              ),
                            ),
                          ],
                          // Admin section
                          if (isStaff) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text('Admin Response',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 10),
                            // Status dropdown
                            Row(
                              children: [
                                const Text('Status:',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: status,
                                      isDense: true,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'open', child: Text('Open')),
                                        DropdownMenuItem(
                                            value: 'in_review',
                                            child: Text('In Review')),
                                        DropdownMenuItem(
                                            value: 'planned',
                                            child: Text('Planned')),
                                        DropdownMenuItem(
                                            value: 'resolved',
                                            child: Text('Resolved')),
                                        DropdownMenuItem(
                                            value: 'closed',
                                            child: Text('Closed')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setDialogState(() => status = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: notesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Admin Notes',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Add notes or a response for the user...',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setDialogState(() => saving = true);
                                        try {
                                          final repo = context
                                              .read<CommunityRepository>();
                                          await repo.updateFeedback(
                                            feedbackId: item['id'],
                                            status: status,
                                            adminNotes: notesCtrl.text.trim(),
                                          );
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          _load();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text('Feedback updated'),
                                              backgroundColor: _brand,
                                            ));
                                          }
                                        } catch (e) {
                                          setDialogState(() => saving = false);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('Error: $e')));
                                          }
                                        }
                                      },
                                icon: saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.save,
                                        color: Colors.white),
                                label:
                                    Text(saving ? 'Saving...' : 'Save Changes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brand,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Non-staff: show admin notes if present
                            if (adminNotes.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      size: 16, color: _brand),
                                  const SizedBox(width: 6),
                                  const Text('Admin Response',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _brand.withOpacity(0.2)),
                                ),
                                child: SelectableText(
                                  adminNotes,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.5),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
