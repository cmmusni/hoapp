import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:intl/intl.dart';

const _brandColor = Color(0xff215e3f);

class SecurityPassPage extends StatefulWidget {
  const SecurityPassPage({super.key});

  @override
  State<SecurityPassPage> createState() => _SecurityPassPageState();
}

class _SecurityPassPageState extends State<SecurityPassPage> {
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
      final userId = SupabaseClientManager.instance.auth.currentUser?.id;

      final futures = await Future.wait([
        _repo.getPassTypes(communityId),
        _repo.getPasses(
          communityId,
          requestedBy: isStaff ? null : userId,
        ),
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
        .where((p) => _statusToString(p.status) == _filterStatus)
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
                // Filter chips — always visible
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      _filterChip('Submitted', 'submitted'),
                      if (isStaff) _filterChip('Pending', 'pending_review'),
                      _filterChip('Approved', 'approved'),
                      _filterChip('Active', 'active'),
                      _filterChip('Used', 'used'),
                      _filterChip('Expired', 'expired'),
                      _filterChip('Rejected', 'rejected'),
                      _filterChip('Revoked', 'revoked'),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filteredPasses.isEmpty
                        ? _buildEmptyState(isGuard)
                        : _buildPassList(isStaff, isGuard),
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
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _buildEmptyState(bool isGuard) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                isGuard ? 'No passes to display' : 'No pass requests yet',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              if (!isGuard) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap "Request Pass" to create one',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassList(bool isStaff, bool isGuard) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _filteredPasses.length,
      itemBuilder: (context, i) => _PassCard(
        pass: _filteredPasses[i],
        isStaff: isStaff,
        isGuard: isGuard,
        onTap: () =>
            _showPassDetails(context, _filteredPasses[i], isStaff, isGuard),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: _brandColor.withOpacity(0.15),
        checkmarkColor: _brandColor,
        onSelected: (_) => setState(() => _filterStatus = value),
      ),
    );
  }

  // ── Create Pass Dialog ──────────────────────────────────────

  void _showCreateDialog(BuildContext context) {
    if (_passTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pass types configured')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _CreatePassDialog(
        passTypes: _passTypes,
        onCreated: _loadData,
      ),
    );
  }

  // ── Pass Details Dialog ─────────────────────────────────────

  void _showPassDetails(
      BuildContext ctx, SecurityPass pass, bool isStaff, bool isGuard) {
    showDialog(
      context: ctx,
      builder: (_) => _PassDetailsDialog(
        pass: pass,
        isStaff: isStaff,
        isGuard: isGuard,
        onUpdated: _loadData,
      ),
    );
  }
}

// ============================================================
// PASS CARD
// ============================================================

class _PassCard extends StatelessWidget {
  final SecurityPass pass;
  final bool isStaff;
  final bool isGuard;
  final VoidCallback onTap;

  const _PassCard({
    required this.pass,
    required this.isStaff,
    required this.isGuard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM dd, yyyy hh:mm a');
    final typeName = pass.passType?.name ?? 'Pass';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(pass.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _passTypeIcon(pass.passType?.slug),
                  color: _statusColor(pass.status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            typeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        _StatusBadge(status: pass.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (pass.visitorName != null)
                      Text(pass.visitorName!,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    Text(
                      '${dateFmt.format(pass.validFrom.toLocal())} — ${dateFmt.format(pass.validUntil.toLocal())}',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (pass.qrToken != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.qr_code, color: _brandColor, size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final PassStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// CREATE PASS DIALOG
// ============================================================

class _CreatePassDialog extends StatefulWidget {
  final List<PassType> passTypes;
  final VoidCallback onCreated;

  const _CreatePassDialog({required this.passTypes, required this.onCreated});

  @override
  State<_CreatePassDialog> createState() => _CreatePassDialogState();
}

class _CreatePassDialogState extends State<_CreatePassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SecurityPassRepository();

  late PassType _selectedType;
  final _visitorNameCtrl = TextEditingController();
  final _visitorPhoneCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vehicleDescCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _validFrom = DateTime.now();
  DateTime? _validUntil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.passTypes.first;
    _validUntil =
        _validFrom.add(Duration(hours: _selectedType.maxValidityHours));
  }

  @override
  void dispose() {
    _visitorNameCtrl.dispose();
    _visitorPhoneCtrl.dispose();
    _purposeCtrl.dispose();
    _companyCtrl.dispose();
    _plateCtrl.dispose();
    _vehicleDescCtrl.dispose();
    _itemsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final appState = context.read<AppState>();
      await _repo.createPass(
        communityId: appState.activeCommunityId!,
        passTypeId: _selectedType.id,
        visitorName: _visitorNameCtrl.text.trim(),
        visitorPhone: _visitorPhoneCtrl.text.trim().isEmpty
            ? null
            : _visitorPhoneCtrl.text.trim(),
        purpose:
            _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
        companyName:
            _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        plateNumber:
            _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
        vehicleDescription: _vehicleDescCtrl.text.trim().isEmpty
            ? null
            : _vehicleDescCtrl.text.trim(),
        itemsDescription:
            _itemsCtrl.text.trim().isEmpty ? null : _itemsCtrl.text.trim(),
        validFrom: _validFrom,
        validUntil: _validUntil!,
        maxUses: _selectedType.multiUse ? _selectedType.maxUses : 1,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pass request submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : (_validUntil ?? _validFrom),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          isFrom ? _validFrom : (_validUntil ?? _validFrom)),
    );
    if (time == null || !mounted) return;

    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _validFrom = dt;
        _validUntil = dt.add(Duration(hours: _selectedType.maxValidityHours));
      } else {
        _validUntil = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM dd, yyyy hh:mm a');
    final isGatePass = _selectedType.slug == 'gate';
    final isContractor =
        _selectedType.slug == 'contractor' || _selectedType.slug == 'service';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  colors: [_brandColor, Color(0xff2e8b57)],
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
                    child: const Icon(Icons.badge_outlined,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request a Pass',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Fill in the details below',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pass type selector
                      DropdownButtonFormField<PassType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Pass Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: widget.passTypes.map((pt) {
                          return DropdownMenuItem(
                            value: pt,
                            child: Text(pt.name),
                          );
                        }).toList(),
                        onChanged: (pt) {
                          if (pt != null) {
                            setState(() {
                              _selectedType = pt;
                              _validUntil = _validFrom
                                  .add(Duration(hours: pt.maxValidityHours));
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Visitor name
                      TextFormField(
                        controller: _visitorNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Visitor / Person Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Phone
                      TextFormField(
                        controller: _visitorPhoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      // Purpose
                      TextFormField(
                        controller: _purposeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Purpose of Visit',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      // Contractor fields
                      if (isContractor) ...[
                        TextFormField(
                          controller: _companyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Vehicle fields
                      if (_selectedType.vehicleRequired) ...[
                        TextFormField(
                          controller: _plateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Plate Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.directions_car_outlined),
                          ),
                          validator: (v) => _selectedType.vehicleRequired &&
                                  (v?.isEmpty ?? true)
                              ? 'Required for this pass type'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _vehicleDescCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Description (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Gate pass — items
                      if (isGatePass) ...[
                        TextFormField(
                          controller: _itemsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Items Description',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_outlined),
                          ),
                          validator: (v) => isGatePass && (v?.isEmpty ?? true)
                              ? 'Required for gate pass'
                              : null,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Date/time pickers
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDateTime(true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Valid From',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined),
                                ),
                                child: Text(
                                  dateFmt.format(_validFrom),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDateTime(false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Valid Until',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_outlined),
                                ),
                                child: Text(
                                  _validUntil != null
                                      ? dateFmt.format(_validUntil!)
                                      : '—',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, color: Colors.white),
                          label: Text(
                              _saving ? 'Submitting...' : 'Submit Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandColor,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PASS DETAILS DIALOG (view, approve/reject, QR view)
// ============================================================

class _PassDetailsDialog extends StatefulWidget {
  final SecurityPass pass;
  final bool isStaff;
  final bool isGuard;
  final VoidCallback onUpdated;

  const _PassDetailsDialog({
    required this.pass,
    required this.isStaff,
    required this.isGuard,
    required this.onUpdated,
  });

  @override
  State<_PassDetailsDialog> createState() => _PassDetailsDialogState();
}

class _PassDetailsDialogState extends State<_PassDetailsDialog> {
  final _repo = SecurityPassRepository();
  bool _processing = false;
  final _rejectReasonCtrl = TextEditingController();
  String? _rejectError;

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await _repo.reviewPass(passId: widget.pass.id, action: 'approve');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pass approved — QR code generated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject() async {
    final reason = _rejectReasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _rejectError = 'Please enter a rejection reason');
      return;
    }
    setState(() => _rejectError = null);
    setState(() => _processing = true);
    try {
      await _repo.reviewPass(
          passId: widget.pass.id, action: 'reject', rejectionReason: reason);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pass rejected')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _revoke() async {
    setState(() => _processing = true);
    try {
      await _repo.revokePass(widget.pass.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pass revoked')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pass'),
        content: const Text(
            'Are you sure you want to permanently delete this pass? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await _repo.deletePass(widget.pass.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pass deleted')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pass = widget.pass;
    final dateFmt = DateFormat('MMM dd, yyyy hh:mm a');
    final typeName = pass.passType?.name ?? 'Pass';
    final canReview = widget.isStaff &&
        (pass.status == PassStatus.submitted ||
            pass.status == PassStatus.pendingReview);
    final canRevoke = !widget.isGuard &&
        (pass.status == PassStatus.approved ||
            pass.status == PassStatus.active);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
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
                    child: Icon(
                      _passTypeIcon(pass.passType?.slug),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        _StatusBadge(status: pass.status),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                    // QR Code section
                    if (pass.qrToken != null &&
                        (pass.status == PassStatus.approved ||
                            pass.status == PassStatus.active)) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              // Simple QR representation using the token
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2,
                                          size: 100, color: _brandColor),
                                      const SizedBox(height: 4),
                                      Text(
                                        pass.qrToken!.substring(
                                            0,
                                            pass.qrToken!.length > 12
                                                ? 12
                                                : pass.qrToken!.length),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Show this QR code at the gate',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                              if (pass.maxUses > 1)
                                Text(
                                  'Uses: ${pass.useCount} / ${pass.maxUses}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Info rows
                    _infoRow('Visitor', pass.visitorName),
                    _infoRow('Phone', pass.visitorPhone),
                    _infoRow('Purpose', pass.purpose),
                    _infoRow('Company', pass.companyName),
                    _infoRow('Plate #', pass.plateNumber),
                    _infoRow('Vehicle', pass.vehicleDescription),
                    _infoRow('Items', pass.itemsDescription),
                    _infoRow(
                        'Valid From', dateFmt.format(pass.validFrom.toLocal())),
                    _infoRow('Valid Until',
                        dateFmt.format(pass.validUntil.toLocal())),
                    _infoRow('Notes', pass.notes),
                    if (pass.rejectionReason != null)
                      _infoRow('Rejection Reason', pass.rejectionReason),

                    // Approve/Reject section for staff
                    if (canReview) ...[
                      const Divider(height: 24),
                      const Text('Review',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _rejectReasonCtrl,
                        decoration: InputDecoration(
                          labelText: 'Rejection reason',
                          border: const OutlineInputBorder(),
                          errorText: _rejectError,
                        ),
                        maxLines: 2,
                        onChanged: (_) {
                          if (_rejectError != null) {
                            setState(() => _rejectError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _processing ? null : _approve,
                              icon: _processing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check,
                                      color: Colors.white),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _processing ? null : _reject,
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Revoke button
                    if (canRevoke) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _processing ? null : _revoke,
                          icon: const Icon(Icons.block, color: Colors.red),
                          label: const Text('Revoke Pass',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],

                    // Delete button (staff only)
                    if (widget.isStaff) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _processing ? null : _delete,
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          label: const Text('Delete Pass',
                              style: TextStyle(color: Colors.red)),
                        ),
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

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String _statusToString(PassStatus s) => const {
      PassStatus.draft: 'draft',
      PassStatus.submitted: 'submitted',
      PassStatus.pendingReview: 'pending_review',
      PassStatus.approved: 'approved',
      PassStatus.active: 'active',
      PassStatus.used: 'used',
      PassStatus.expired: 'expired',
      PassStatus.revoked: 'revoked',
      PassStatus.rejected: 'rejected',
    }[s]!;

String _statusLabel(PassStatus s) => const {
      PassStatus.draft: 'Draft',
      PassStatus.submitted: 'Submitted',
      PassStatus.pendingReview: 'Pending Review',
      PassStatus.approved: 'Approved',
      PassStatus.active: 'Active',
      PassStatus.used: 'Used',
      PassStatus.expired: 'Expired',
      PassStatus.revoked: 'Revoked',
      PassStatus.rejected: 'Rejected',
    }[s]!;

Color _statusColor(PassStatus s) {
  switch (s) {
    case PassStatus.draft:
      return Colors.grey;
    case PassStatus.submitted:
      return Colors.blue;
    case PassStatus.pendingReview:
      return Colors.orange;
    case PassStatus.approved:
      return const Color(0xff215e3f);
    case PassStatus.active:
      return Colors.green;
    case PassStatus.used:
      return Colors.teal;
    case PassStatus.expired:
      return Colors.grey;
    case PassStatus.revoked:
      return Colors.red.shade800;
    case PassStatus.rejected:
      return Colors.red;
  }
}

IconData _passTypeIcon(String? slug) {
  switch (slug) {
    case 'visitor':
      return Icons.person_outline;
    case 'gate':
      return Icons.door_front_door_outlined;
    case 'contractor':
    case 'service':
      return Icons.engineering_outlined;
    case 'delivery':
      return Icons.local_shipping_outlined;
    default:
      return Icons.badge_outlined;
  }
}
