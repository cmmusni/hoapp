import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

class BetaRequestsPage extends StatefulWidget {
  const BetaRequestsPage({super.key});

  @override
  State<BetaRequestsPage> createState() => _BetaRequestsPageState();
}

class _BetaRequestsPageState extends State<BetaRequestsPage> {
  Future<List<Map<String, dynamic>>>? _requestsFuture;
  String _filter = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    final repo = context.read<CommunityRepository>();
    setState(() {
      _requestsFuture = repo.getBetaAccessRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.science_rounded,
                          color: _brand, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Beta Access Requests',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Review requests and provision communities',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter chips
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('All', 'all'),
                    _filterChip('Pending', 'pending'),
                    _filterChip('Approved', 'approved'),
                    _filterChip('Rejected', 'rejected'),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _requestsFuture,
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
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRequests,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var requests = snapshot.data ?? [];
                if (_filter != 'all') {
                  requests =
                      requests.where((r) => r['status'] == _filter).toList();
                }

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'all'
                              ? 'No beta access requests yet'
                              : 'No $_filter requests',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _BetaRequestCard(
                      request: requests[index],
                      onRefresh: _loadRequests,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: _brand.withOpacity(0.15),
      checkmarkColor: _brand,
      labelStyle: TextStyle(
        color: isSelected ? _brand : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────

class _BetaRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onRefresh;

  const _BetaRequestCard({
    required this.request,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'pending';
    final name = request['name'] as String? ?? '';
    final email = request['email'] as String? ?? '';
    final org = request['organization'] as String?;
    final createdAt = DateTime.tryParse(request['created_at'] ?? '');
    final dateFormat = DateFormat('MMM dd, yyyy · h:mm a');

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(email,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600])),
                    if (org != null && org.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(org,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (createdAt != null)
                    Text(
                      dateFormat.format(createdAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _BetaRequestDetailDialog(
        request: request,
        onRefresh: onRefresh,
      ),
    );
  }
}

// ─── Detail Dialog ────────────────────────────────────────

class _BetaRequestDetailDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onRefresh;

  const _BetaRequestDetailDialog({
    required this.request,
    required this.onRefresh,
  });

  @override
  State<_BetaRequestDetailDialog> createState() =>
      _BetaRequestDetailDialogState();
}

class _BetaRequestDetailDialogState extends State<_BetaRequestDetailDialog> {
  final _communityNameCtrl = TextEditingController();
  final _communitySlugCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProvisioning = false;
  bool _isRejecting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    // Auto-suggest slug from organization name
    final org = widget.request['organization'] as String?;
    if (org != null && org.isNotEmpty) {
      _communityNameCtrl.text = org;
      _communitySlugCtrl.text = _slugify(org);
    }
  }

  @override
  void dispose() {
    _communityNameCtrl.dispose();
    _communitySlugCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.request['status'] as String? ?? 'pending';
    final name = widget.request['name'] as String? ?? '';
    final email = widget.request['email'] as String? ?? '';
    final org = widget.request['organization'] as String?;
    final createdAt = DateTime.tryParse(widget.request['created_at'] ?? '');
    final dateFormat = DateFormat('MMM dd, yyyy · h:mm a');
    final isPending = status == 'pending';

    // Success state
    if (_result != null) {
      return _buildSuccessDialog();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header banner
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
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(email,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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
                    // Request info
                    _infoRow('Name', name),
                    _infoRow('Email', email),
                    if (org != null && org.isNotEmpty)
                      _infoRow('Organization', org),
                    if (createdAt != null)
                      _infoRow(
                          'Requested', dateFormat.format(createdAt.toLocal())),
                    _infoRow('Status',
                        status[0].toUpperCase() + status.substring(1)),

                    if (!isPending) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: status == 'approved'
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status == 'approved'
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          status == 'approved'
                              ? 'This request has been approved and a community has been provisioned.'
                              : 'This request has been rejected.',
                          style: TextStyle(
                            color: status == 'approved'
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    // Provision form (only for pending)
                    if (isPending) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Provision Community',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a community and admin account for this requester.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _communityNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Community Name',
                                hintText: 'e.g. Greenfield Village HOA',
                                prefixIcon: const Icon(Icons.apartment),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (v) {
                                _communitySlugCtrl.text = _slugify(v);
                              },
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _communitySlugCtrl,
                              decoration: InputDecoration(
                                labelText: 'Community Slug',
                                hintText: 'greenfield-village-hoa',
                                prefixIcon: const Icon(Icons.link),
                                helperText:
                                    'URL: hoapp.net/${_communitySlugCtrl.text.isEmpty ? "slug" : _communitySlugCtrl.text}',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-z0-9-]')),
                              ],
                              validator: (v) {
                                if (v?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v!)) {
                                  return 'Only lowercase letters, numbers, hyphens';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: InputDecoration(
                                labelText: 'Initial Password',
                                hintText: 'Temporary password for the user',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              obscureText: true,
                              validator: (v) {
                                if (v?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                if (v!.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 18, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          // Reject button
                          OutlinedButton.icon(
                            onPressed: _isRejecting || _isProvisioning
                                ? null
                                : _rejectRequest,
                            icon: _isRejecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.red),
                                  )
                                : const Icon(Icons.close,
                                    size: 18, color: Colors.red),
                            label: Text(
                              _isRejecting ? 'Rejecting...' : 'Reject',
                              style: const TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Provision button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProvisioning || _isRejecting
                                  ? null
                                  : _provision,
                              icon: _isProvisioning
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.rocket_launch, size: 18),
                              label: Text(_isProvisioning
                                  ? 'Provisioning...'
                                  : 'Provision Community'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    _brand.withOpacity(0.6),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessDialog() {
    final portalUrl = _result!['portal_url'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  size: 52, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            const Text('Community Provisioned!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _result!['message'] as String? ??
                  'Community and user created successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
            ),
            if (portalUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: _brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(portalUrl,
                          style: const TextStyle(fontSize: 13, color: _brand)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: portalUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy URL',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onRefresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProvisioning = true;
      _error = null;
    });

    try {
      final repo = context.read<CommunityRepository>();
      final result = await repo.provisionCommunity(
        requestId: widget.request['id'] as String,
        communityName: _communityNameCtrl.text.trim(),
        communitySlug: _communitySlugCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isProvisioning = false;
        });
      }
    }
  }

  Future<void> _rejectRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Request'),
        content: Text(
            'Reject the beta access request from ${widget.request['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRejecting = true);

    try {
      final repo = context.read<CommunityRepository>();
      await repo.rejectBetaRequest(widget.request['id'] as String);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isRejecting = false;
        });
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
