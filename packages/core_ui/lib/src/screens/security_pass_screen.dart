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
              backgroundColor: _brand,
              foregroundColor: Colors.white,
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreatePassSheet(passTypes: _passTypes, onCreated: _loadData),
      ),
    );
  }

  void _showPassDetails(
      BuildContext ctx, SecurityPass pass, bool isStaff, bool isGuard) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _PassDetailsSheet(
        pass: pass,
        isStaff: isStaff,
        isGuard: isGuard,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.qr_code, color: statusColor, size: 20),
        ),
        title: Text(pass.visitorName ?? 'Unknown Visitor'),
        subtitle: Text(
          '${pass.purpose ?? 'No purpose'} • ${statusStr.toUpperCase()}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Chip(
          label: Text(statusStr.toUpperCase(),
              style: const TextStyle(fontSize: 10)),
          backgroundColor: statusColor.withValues(alpha: 0.15),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

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
  final VoidCallback onUpdated;

  const _PassDetailsSheet({
    required this.pass,
    required this.isStaff,
    required this.isGuard,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = pass.status.toString().split('.').last;

    return DraggableScrollableSheet(
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
          // QR placeholder
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2, size: 60, color: _brand),
                  const SizedBox(height: 4),
                  Text(pass.qrToken?.substring(0, 8) ?? 'N/A',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(pass.visitorName ?? 'Unknown Visitor',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _DetailRow(label: 'Status', value: statusStr.toUpperCase()),
          _DetailRow(label: 'Purpose', value: pass.purpose ?? 'N/A'),
          if (pass.visitorPhone != null)
            _DetailRow(label: 'Phone', value: pass.visitorPhone!),
          if (pass.companyName != null)
            _DetailRow(label: 'Company', value: pass.companyName!),
          if (pass.plateNumber != null)
            _DetailRow(label: 'Plate #', value: pass.plateNumber!),
          _DetailRow(
              label: 'Valid From',
              value: DateFormat('MMM d, yyyy HH:mm').format(pass.validFrom)),
          _DetailRow(
              label: 'Valid Until',
              value: DateFormat('MMM d, yyyy HH:mm').format(pass.validUntil)),
          if (pass.notes != null)
            _DetailRow(label: 'Notes', value: pass.notes!),
          const SizedBox(height: 20),

          // Staff review actions
          if (isStaff &&
              (statusStr == 'submitted' || statusStr == 'pending_review')) ...[
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
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _brand, foregroundColor: Colors.white),
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
                  icon: const Icon(Icons.close, color: Colors.red),
                  label:
                      const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
              ),
            ]),
          ],

          // Revoke if active
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value)),
      ]),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Request Security Pass',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<PassType>(
              value: _selectedType,
              decoration: const InputDecoration(
                  labelText: 'Pass Type', border: OutlineInputBorder()),
              items: widget.passTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _visitorNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Visitor Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _visitorPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Visitor Phone (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purposeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Purpose', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Company (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateCtrl,
              decoration: const InputDecoration(
                  labelText: 'Plate Number (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                  'From: ${DateFormat('MMM d, HH:mm').format(_validFrom)}'),
              onTap: () => _pickDateTime(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(
                  'Until: ${DateFormat('MMM d, HH:mm').format(_validUntil)}'),
              onTap: () => _pickDateTime(false),
            ),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Request'),
              ),
            ),
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
