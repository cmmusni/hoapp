import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const _brand = Color(0xff215e3f);

/// Shared security pass screen — works on both web and mobile.
class SecurityPassScreen extends StatefulWidget {
  const SecurityPassScreen({super.key});

  @override
  State<SecurityPassScreen> createState() => _SecurityPassScreenState();
}

class _SecurityPassScreenState extends State<SecurityPassScreen> {
  final _repo = SecurityPassRepository();
  List<SecurityPass> _passes = [];
  List<PassType> _passTypes = [];
  bool _loading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId!;
      final isStaff = appState.isStaff;
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final futures = await Future.wait([
        _repo.getPassTypes(communityId),
        _repo.getPasses(communityId, requestedBy: isStaff ? null : userId),
      ]);

      if (mounted) {
        setState(() {
          _passTypes = futures[0] as List<PassType>;
          _passes = futures[1] as List<SecurityPass>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<SecurityPass> get _filteredPasses {
    if (_filterStatus == 'all') return _passes;
    return _passes
        .where((p) => p.status.toString().split('.').last == _filterStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;
    final isGuard = appState.activeRole?.role == Role.guard;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    _chip('All', 'all'),
                    _chip('Submitted', 'submitted'),
                    if (isStaff) _chip('Pending', 'pending_review'),
                    _chip('Approved', 'approved'),
                    _chip('Active', 'active'),
                    _chip('Used', 'used'),
                    _chip('Expired', 'expired'),
                    _chip('Rejected', 'rejected'),
                    _chip('Revoked', 'revoked'),
                  ]),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filteredPasses.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(children: [
                                Icon(Icons.qr_code_2,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  isGuard
                                      ? 'No passes to display'
                                      : 'No pass requests yet',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade600),
                                ),
                              ]),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filteredPasses.length,
                            itemBuilder: (_, i) {
                              final pass = _filteredPasses[i];
                              return _PassCard(
                                pass: pass,
                                isStaff: isStaff,
                                onTap: () => _showPassDetails(
                                    context, pass, isStaff, isGuard),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: isGuard
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Request Pass'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: _brand.withValues(alpha: 0.15),
        checkmarkColor: _brand,
        onSelected: (_) => setState(() => _filterStatus = value),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    if (_passTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pass types configured')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreatePassSheet(passTypes: _passTypes, onCreated: _loadData),
      ),
    );
  }

  void _showPassDetails(
      BuildContext ctx, SecurityPass pass, bool isStaff, bool isGuard) {
    final isAdmin = ctx.read<AppState>().isAdmin;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PassDetailsSheet(
        pass: pass,
        isStaff: isStaff,
        isGuard: isGuard,
        isAdmin: isAdmin,
        currentUserId: currentUserId,
        onUpdated: _loadData,
      ),
    );
  }
}

// ─── Pass Card ───────────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final SecurityPass pass;
  final bool isStaff;
  final VoidCallback onTap;

  const _PassCard({
    required this.pass,
    required this.isStaff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = pass.status.toString().split('.').last;
    final statusColor = _getStatusColor(statusStr);
    final dateRange =
        '${DateFormat('MMM d').format(pass.validFrom)} – ${DateFormat('MMM d').format(pass.validUntil)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_2, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pass.visitorName ?? 'Unknown Visitor',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pass.purpose ?? 'No purpose',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(dateRange,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(statusStr),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'pending_review' => 'PENDING',
        _ => status.toUpperCase(),
      };

  static Color _getStatusColor(String status) => switch (status) {
        'approved' || 'active' => _brand,
        'pending_review' || 'submitted' => Colors.orange,
        'rejected' || 'revoked' => Colors.red,
        'used' => Colors.blue,
        _ => Colors.grey,
      };
}

// ─── Pass Details Sheet ──────────────────────────────────────────────────────

class _PassDetailsSheet extends StatelessWidget {
  final SecurityPass pass;
  final bool isStaff;
  final bool isGuard;
  final bool isAdmin;
  final String? currentUserId;
  final VoidCallback onUpdated;

  const _PassDetailsSheet({
    required this.pass,
    required this.isStaff,
    required this.isGuard,
    this.isAdmin = false,
    this.currentUserId,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = pass.status.toString().split('.').last;
    final statusColor = _PassCard._getStatusColor(statusStr);
    final statusLabel = _PassCard._statusLabel(statusStr);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sc) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Status pill
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // QR placeholder
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.04),
                  border: Border.all(
                      color: _brand.withValues(alpha: 0.15), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2, size: 64, color: _brand),
                    const SizedBox(height: 6),
                    Text(
                      pass.qrToken?.substring(0, 8) ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Visitor name
            Text(
              pass.visitorName ?? 'Unknown Visitor',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (pass.purpose != null) ...[
              const SizedBox(height: 4),
              Text(
                pass.purpose!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // Details card
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (pass.visitorPhone != null)
                    _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: pass.visitorPhone!),
                  if (pass.companyName != null)
                    _DetailRow(
                        icon: Icons.business_outlined,
                        label: 'Company',
                        value: pass.companyName!),
                  if (pass.plateNumber != null)
                    _DetailRow(
                        icon: Icons.directions_car_outlined,
                        label: 'Plate #',
                        value: pass.plateNumber!),
                  _DetailRow(
                    icon: Icons.login,
                    label: 'Valid From',
                    value: DateFormat('MMM d, yyyy  h:mm a')
                        .format(pass.validFrom),
                  ),
                  _DetailRow(
                    icon: Icons.logout,
                    label: 'Valid Until',
                    value: DateFormat('MMM d, yyyy  h:mm a')
                        .format(pass.validUntil),
                    showDivider: pass.notes != null,
                  ),
                  if (pass.notes != null)
                    _DetailRow(
                      icon: Icons.notes,
                      label: 'Notes',
                      value: pass.notes!,
                      showDivider: false,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Staff review actions
            if (isStaff &&
                (statusStr == 'submitted' ||
                    statusStr == 'pending_review')) ...[
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final repo = SecurityPassRepository();
                      await repo.reviewPass(passId: pass.id, action: 'approve');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onUpdated();
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final repo = SecurityPassRepository();
                      await repo.reviewPass(passId: pass.id, action: 'reject');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onUpdated();
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ],

            // Revoke if active (staff)
            if (isStaff &&
                (statusStr == 'active' || statusStr == 'approved')) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final repo = SecurityPassRepository();
                    await repo.revokePass(pass.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      onUpdated();
                    }
                  },
                  icon: const Icon(Icons.block, color: Colors.red),
                  label: const Text('Revoke Pass',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            // Delete: admin can delete any pass; owner can delete own submitted pass
            if (isAdmin ||
                (currentUserId != null &&
                    pass.requestedBy == currentUserId &&
                    statusStr == 'submitted')) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Pass'),
                        content: Text(
                          'Are you sure you want to permanently delete the pass for "${pass.visitorName ?? 'Unknown Visitor'}"? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final repo = SecurityPassRepository();
                      await repo.deletePass(pass.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onUpdated();
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete Pass',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final bool showDivider;
  const _DetailRow({
    this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 10),
            ],
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.end),
            ),
          ]),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

// ─── Create Pass Sheet ───────────────────────────────────────────────────────

class _CreatePassSheet extends StatefulWidget {
  final List<PassType> passTypes;
  final VoidCallback onCreated;
  const _CreatePassSheet({required this.passTypes, required this.onCreated});

  @override
  State<_CreatePassSheet> createState() => _CreatePassSheetState();
}

class _CreatePassSheetState extends State<_CreatePassSheet> {
  late PassType _selectedType;
  final _visitorNameCtrl = TextEditingController();
  final _visitorPhoneCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(hours: 24));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.passTypes.first;
  }

  @override
  void dispose() {
    _visitorNameCtrl.dispose();
    _visitorPhoneCtrl.dispose();
    _purposeCtrl.dispose();
    _companyCtrl.dispose();
    _plateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with icon
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.badge_outlined, color: _brand, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request Security Pass',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Fill in visitor details below',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pass type
            DropdownButtonFormField<PassType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Pass Type',
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
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
              ),
              items: widget.passTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 14),

            // Visitor info section
            _sectionLabel('Visitor Information'),
            const SizedBox(height: 10),
            _styledField(
              controller: _visitorNameCtrl,
              label: 'Visitor Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _styledField(
              controller: _visitorPhoneCtrl,
              label: 'Visitor Phone (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _styledField(
              controller: _purposeCtrl,
              label: 'Purpose of Visit',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: 12),
            _styledField(
              controller: _companyCtrl,
              label: 'Company (optional)',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            _styledField(
              controller: _plateCtrl,
              label: 'Plate Number (optional)',
              icon: Icons.directions_car_outlined,
            ),
            const SizedBox(height: 20),

            // Schedule section
            _sectionLabel('Schedule'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dateCard(
                    label: 'FROM',
                    dateTime: _validFrom,
                    onTap: () => _pickDateTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateCard(
                    label: 'UNTIL',
                    dateTime: _validUntil,
                    onTap: () => _pickDateTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _styledField(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              icon: Icons.notes,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleCreate,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Request',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brand, width: 1.5),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _dateCard({
    required String label,
    required DateTime dateTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(DateFormat('MMM d, yyyy').format(dateTime),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(DateFormat('h:mm a').format(dateTime),
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final initial = isFrom ? _validFrom : _validUntil;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (t != null && mounted) {
        setState(() {
          final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
          if (isFrom) {
            _validFrom = dt;
          } else {
            _validUntil = dt;
          }
        });
      }
    }
  }

  Future<void> _handleCreate() async {
    if (_visitorNameCtrl.text.trim().isEmpty ||
        _purposeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor name and purpose are required')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final repo = SecurityPassRepository();
      await repo.createPass(
        communityId: appState.activeCommunityId!,
        passTypeId: _selectedType.id,
        visitorName: _visitorNameCtrl.text.trim(),
        visitorPhone: _visitorPhoneCtrl.text.trim().isEmpty
            ? null
            : _visitorPhoneCtrl.text.trim(),
        purpose: _purposeCtrl.text.trim(),
        companyName:
            _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        plateNumber:
            _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
        validFrom: _validFrom,
        validUntil: _validUntil,
        maxUses: 1,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
}
