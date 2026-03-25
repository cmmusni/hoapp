import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';

class PoolAccessPage extends StatefulWidget {
  const PoolAccessPage({super.key});

  @override
  State<PoolAccessPage> createState() => _PoolAccessPageState();
}

class _PoolAccessPageState extends State<PoolAccessPage> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStaff = appState.isStaff;

    if (isStaff) {
      return const _StaffView();
    } else {
      return const _ResidentView();
    }
  }
}

// ============ RESIDENT VIEW ============

class _ResidentView extends StatefulWidget {
  const _ResidentView();

  @override
  State<_ResidentView> createState() => _ResidentViewState();
}

class _ResidentViewState extends State<_ResidentView> {
  Future<PoolAccessRegistration?>? _registrationFuture;

  @override
  void initState() {
    super.initState();
    _loadRegistration();
  }

  void _loadRegistration() {
    final appState = context.read<AppState>();
    final repo = context.read<PoolAccessRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _registrationFuture =
            repo.getMyRegistration(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadRegistration(),
        child: FutureBuilder<PoolAccessRegistration?>(
          future: _registrationFuture,
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
                    HOAppButton(
                      label: 'Retry',
                      onPressed: _loadRegistration,
                    ),
                  ],
                ),
              );
            }

            final registration = snapshot.data;

            if (registration == null) {
              return _RegistrationForm(onSubmitted: _loadRegistration);
            }

            return _RegistrationDetails(
              registration: registration,
              onEdit: _loadRegistration,
            );
          },
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatefulWidget {
  final VoidCallback onSubmitted;

  const _RegistrationForm({required this.onSubmitted});

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<_RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _idDocUrlController = TextEditingController();

  OccupantType _occupantType = OccupantType.resident;
  DateTime? _birthdate;
  bool _acknowledgeRules = false;
  bool _acknowledgeWaiver = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _idDocUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pool Access Registration',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete this form to register for pool access',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Personal Information
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<OccupantType>(
                  value: _occupantType,
                  decoration: const InputDecoration(
                    labelText: 'Occupant Type',
                    border: OutlineInputBorder(),
                  ),
                  items: OccupantType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _occupantType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _birthdate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthdate (Optional)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _birthdate != null
                          ? DateFormat('MMM dd, yyyy').format(_birthdate!)
                          : 'Select date',
                      style: TextStyle(
                        color: _birthdate != null ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Contact
                const Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Document Upload
                const Text(
                  'Document Upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _idDocUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Valid ID URL (Optional)',
                    hintText: 'Upload ID to file storage and paste link',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),

                // Acknowledgements
                const Text(
                  'Acknowledgements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  value: _acknowledgeRules,
                  onChanged: (value) =>
                      setState(() => _acknowledgeRules = value ?? false),
                  title: const Text(
                      'I have read and agree to follow the pool rules'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),

                CheckboxListTile(
                  value: _acknowledgeWaiver,
                  onChanged: (value) =>
                      setState(() => _acknowledgeWaiver = value ?? false),
                  title: const Text('I acknowledge the liability waiver'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After approval, you can only edit this registration after 3 months.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: HOAppButton(
                    label:
                        _isSubmitting ? 'Submitting...' : 'Submit Registration',
                    onPressed: _isSubmitting ||
                            !_acknowledgeRules ||
                            !_acknowledgeWaiver
                        ? null
                        : _submitRegistration,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<PoolAccessRepository>();

      await repo.upsertRegistration(
        communityId: appState.activeCommunityId!,
        occupantType: _occupantType,
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        birthdate: _birthdate,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
        idDocUrl: _idDocUrlController.text.isNotEmpty
            ? _idDocUrlController.text
            : null,
        acknowledgements: {
          'pool_rules': _acknowledgeRules,
          'liability_waiver': _acknowledgeWaiver,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration submitted. Awaiting staff approval.'),
          ),
        );
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _RegistrationDetails extends StatelessWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onEdit;

  const _RegistrationDetails({
    required this.registration,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final canEdit = registration.canEdit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pool Access Registration',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: registration.approved
                          ? Color.fromRGBO(39, 99, 67, 1).withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      registration.approved ? 'APPROVED' : 'PENDING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: registration.approved
                            ? Color.fromRGBO(39, 99, 67, 1)
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoSection(
                title: 'Personal Information',
                children: [
                  _InfoRow(
                    label: 'Occupant Type',
                    value: registration.occupantType.name.toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Full Name',
                    value: registration.fullName,
                  ),
                  _InfoRow(
                    label: 'Phone',
                    value: registration.phone,
                  ),
                  _InfoRow(
                    label: 'Email',
                    value: registration.email,
                  ),
                  if (registration.birthdate != null)
                    _InfoRow(
                      label: 'Birthdate',
                      value: dateFormat.format(registration.birthdate!),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoSection(
                title: 'Emergency Contact',
                children: [
                  _InfoRow(
                    label: 'Name',
                    value: registration.emergencyContactName,
                  ),
                  _InfoRow(
                    label: 'Phone',
                    value: registration.emergencyContactPhone,
                  ),
                ],
              ),
              if (registration.idDocUrl != null) ...[
                const SizedBox(height: 24),
                _InfoSection(
                  title: 'Documents',
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Open ID document URL
                      },
                      icon: const Icon(Icons.badge),
                      label: const Text('View Valid ID'),
                    ),
                  ],
                ),
              ],
              if (registration.approved && registration.approvedAt != null) ...[
                const SizedBox(height: 24),
                _InfoSection(
                  title: 'Approval Details',
                  children: [
                    _InfoRow(
                      label: 'Approved At',
                      value: dateFormat.format(registration.approvedAt!),
                    ),
                  ],
                ),
              ],
              if (!canEdit) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing locked until ${dateFormat.format(registration.nextEditableDate)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canEdit && !registration.approved) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: HOAppButton(
                    label: 'Edit Registration',
                    onPressed: () {
                      // Show edit form
                      _showEditDialog(context);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Edit feature coming soon. Please contact staff for changes.'),
      ),
    );
  }
}

// ============ STAFF VIEW ============

class _StaffView extends StatefulWidget {
  const _StaffView();

  @override
  State<_StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<_StaffView> {
  Future<List<PoolAccessRegistration>>? _registrationsFuture;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  void _loadRegistrations() {
    final appState = context.read<AppState>();
    final repo = context.read<PoolAccessRepository>();

    if (appState.activeCommunityId != null) {
      setState(() {
        _registrationsFuture =
            repo.getRegistrations(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadRegistrations(),
        child: FutureBuilder<List<PoolAccessRegistration>>(
          future: _registrationsFuture,
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
                    HOAppButton(
                      label: 'Retry',
                      onPressed: _loadRegistrations,
                    ),
                  ],
                ),
              );
            }

            final registrations = snapshot.data ?? [];

            if (registrations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pool, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No registrations yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pool access registrations will appear here',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: registrations.length,
              itemBuilder: (context, index) {
                final registration = registrations[index];
                return _RegistrationCard(
                  registration: registration,
                  onRefresh: _loadRegistrations,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationCard({
    required this.registration,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: registration.approved
                    ? Color.fromRGBO(39, 99, 67, 1).withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                child: Icon(
                  registration.approved ? Icons.check : Icons.pending,
                  color: registration.approved
                      ? Color.fromRGBO(39, 99, 67, 1)
                      : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registration.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${registration.occupantType.name.toUpperCase()} • ${registration.phone}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!registration.approved)
                ElevatedButton(
                  onPressed: () => _approveRegistration(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(39, 99, 67, 1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
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
      builder: (context) => _RegistrationDetailsStaffDialog(
        registration: registration,
        onRefresh: onRefresh,
      ),
    );
  }

  Future<void> _approveRegistration(BuildContext context) async {
    try {
      final repo = context.read<PoolAccessRepository>();
      await repo.approveRegistration(registration.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration approved')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _RegistrationDetailsStaffDialog extends StatelessWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationDetailsStaffDialog({
    required this.registration,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.assignment_outlined,
              color: Color(0xff215e3f), size: 24),
          const SizedBox(width: 12),
          const Text('Registration Details',
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: registration.approved
                      ? Color.fromRGBO(39, 99, 67, 1).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  registration.approved ? 'APPROVED' : 'PENDING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: registration.approved
                        ? Color.fromRGBO(39, 99, 67, 1)
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Personal Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Occupant Type',
                value: registration.occupantType.name.toUpperCase(),
              ),
              _InfoRow(label: 'Full Name', value: registration.fullName),
              _InfoRow(label: 'Phone', value: registration.phone),
              _InfoRow(label: 'Email', value: registration.email),
              if (registration.birthdate != null)
                _InfoRow(
                  label: 'Birthdate',
                  value: dateFormat.format(registration.birthdate!),
                ),
              const SizedBox(height: 16),
              const Text(
                'Emergency Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Name',
                value: registration.emergencyContactName,
              ),
              _InfoRow(
                label: 'Phone',
                value: registration.emergencyContactPhone,
              ),
              if (registration.idDocUrl != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.badge),
                  label: const Text('View Valid ID'),
                ),
              ],
              if (registration.approved && registration.approvedAt != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Approval Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Approved At',
                  value: dateFormat.format(registration.approvedAt!),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!registration.approved)
          HOAppButton(
            label: 'Approve',
            onPressed: () async {
              Navigator.of(context).pop();
              await _approveRegistration(context);
            },
          ),
      ],
    );
  }

  Future<void> _approveRegistration(BuildContext context) async {
    try {
      final repo = context.read<PoolAccessRepository>();
      await repo.approveRegistration(registration.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration approved')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ============ SHARED WIDGETS ============

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
