import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _brand = Color(0xff215e3f);

/// Look up max swimmers from the DB-driven [maxPaxMap] (unit-type-name -> max).
/// Falls back to 5 when the unit type is null or not found.
int _resolveMaxPax(String? unitType, Map<String, int> maxPaxMap) {
  if (unitType == null) return 5;
  return maxPaxMap[unitType.toLowerCase()] ?? 5;
}

class PoolAccessScreen extends StatefulWidget {
  const PoolAccessScreen({super.key});

  @override
  State<PoolAccessScreen> createState() => _PoolAccessScreenState();
}

class _PoolAccessScreenState extends State<PoolAccessScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.isStaff) {
      return const _StaffView();
    }
    return const _ResidentView();
  }
}

// ============================================================
// RESIDENT VIEW
// ============================================================

class _ResidentView extends StatefulWidget {
  const _ResidentView();
  @override
  State<_ResidentView> createState() => _ResidentViewState();
}

class _ResidentViewState extends State<_ResidentView> {
  Future<_ResidentData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final appState = context.read<AppState>();
    final repo = context.read<PoolAccessRepository>();
    final communityId = appState.activeCommunityId;
    if (communityId == null) return;

    setState(() {
      _dataFuture = _fetchResidentData(repo, communityId);
    });
  }

  Future<_ResidentData> _fetchResidentData(
    PoolAccessRepository repo,
    String communityId,
  ) async {
    final householdRepo = context.read<HouseholdRepository>();
    final registration = await repo.getMyRegistration(communityId);
    List<PoolSwimmer> swimmers = [];
    if (registration != null) {
      swimmers = await repo.getSwimmers(registration.id);
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    String? unitId;
    String? unitNo;
    String? unitType;
    String? profileName;
    String? profilePhone;
    String? profileEmail;
    OccupantType? profileOccupantType;
    List<String> unitMemberNames = [];

    if (userId != null) {
      final profile = await client
          .from('profiles')
          .select('full_name, phone, email')
          .eq('user_id', userId)
          .eq('community_id', communityId)
          .maybeSingle();
      if (profile != null) {
        profileName = profile['full_name'] as String?;
        profilePhone = profile['phone'] as String?;
        profileEmail = profile['email'] as String?;
      }
      profileEmail ??= client.auth.currentUser?.email;

      final memberRow = await client
          .from('household_members')
          .select('unit_id, member_role, units(unit_no, unit_type)')
          .eq('user_id', userId)
          .eq('community_id', communityId)
          .maybeSingle();

      if (memberRow != null) {
        unitId = memberRow['unit_id'] as String?;
        final role = memberRow['member_role'] as String?;
        if (role == 'tenant') {
          profileOccupantType = OccupantType.tenant;
        } else if (role != null) {
          profileOccupantType = OccupantType.resident;
        }
        final unitData = memberRow['units'] as Map<String, dynamic>?;
        unitNo = unitData?['unit_no'] as String?;
        unitType = unitData?['unit_type'] as String?;

        if (unitId != null) {
          final members = await householdRepo.getHouseholdMembers(unitId);
          unitMemberNames = members
              .map((m) => m.displayName)
              .where((n) => n != 'Unknown')
              .toList();
        }
      }
    }

    final maxPaxMap = await repo.getMaxPaxByUnitType(communityId);

    // Check if unit already has a registration with swimmers (unit-level lock)
    // Uses SECURITY DEFINER function to bypass RLS
    bool unitLocked = false;
    DateTime? unitLockDate;
    List<String> unitSwimmerNames = [];
    if (unitId != null) {
      final lockInfo = await repo.getUnitPoolLock(communityId, unitId);
      final isLocked = lockInfo['locked'] == true;
      final canEdit = lockInfo['can_edit'] as bool? ?? false;
      // Lock the unit only during the 90-day window (not after it expires)
      if (isLocked && !canEdit) {
        unitLocked = true;
        final nextDate = lockInfo['next_editable_date'] as String?;
        unitLockDate = nextDate != null ? DateTime.tryParse(nextDate) : null;
        final swimmers = lockInfo['swimmers'];
        if (swimmers is List) {
          unitSwimmerNames = swimmers
              .map((s) => (s is Map ? s['full_name'] as String? : null) ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        }
      }
    }

    return _ResidentData(
      registration: registration,
      swimmers: swimmers,
      unitId: unitId,
      unitNo: unitNo,
      unitType: unitType,
      profileName: profileName,
      profilePhone: profilePhone,
      profileEmail: profileEmail,
      profileOccupantType: profileOccupantType,
      unitMemberNames: unitMemberNames,
      maxPaxMap: maxPaxMap,
      unitLocked: unitLocked,
      unitLockDate: unitLockDate,
      unitSwimmerNames: unitSwimmerNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pool Access')),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: FutureBuilder<_ResidentData>(
          future: _dataFuture,
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
                        onPressed: _loadData, child: const Text('Retry')),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            if (data.registration == null && data.unitLocked) {
              return _buildUnitLocked(data);
            }
            if (data.registration == null) {
              return _buildNoRegistration(data);
            }
            return _buildRegistrationDetails(data);
          },
        ),
      ),
    );
  }

  Widget _buildUnitLocked(_ResidentData data) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 64, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pool Registration Locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your unit already has registered swimmers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        data.unitLockDate != null
                            ? 'Editing locked until ${dateFormat.format(data.unitLockDate!)}'
                            : 'Editing is currently locked',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                if (data.unitSwimmerNames.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Registered Swimmers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...data.unitSwimmerNames.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNoRegistration(_ResidentData data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pool, size: 80, color: _brand),
            const SizedBox(height: 24),
            const Text(
              'Pool Access Registration',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Register your household for pool access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => _RegistrationFormScreen(
                        unitId: data.unitId,
                        unitNo: data.unitNo,
                        unitType: data.unitType,
                        profileName: data.profileName,
                        profilePhone: data.profilePhone,
                        profileEmail: data.profileEmail,
                        profileOccupantType: data.profileOccupantType,
                        unitMemberNames: data.unitMemberNames,
                        maxPaxMap: data.maxPaxMap,
                      ),
                    ))
                    .then((_) => _loadData());
              },
              icon: const Icon(Icons.app_registration),
              label: const Text('Register Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationDetails(_ResidentData data) {
    final reg = data.registration!;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status card
        Card(
          color: reg.approved
              ? _brand.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  reg.approved ? Icons.check_circle : Icons.pending,
                  size: 40,
                  color: reg.approved ? _brand : Colors.orange,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reg.approved ? 'Approved' : 'Pending Approval',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reg.approved
                            ? 'Your pool access is active'
                            : 'Awaiting staff review',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Unit info
        if (data.unitNo != null) ...[
          _buildInfoCard('Unit', 'Unit ${data.unitNo}', Icons.home),
          const SizedBox(height: 12),
        ],

        // Personal info section
        _buildSectionTitle('Personal Information'),
        _buildInfoTile('Name', reg.fullName),
        _buildInfoTile('Phone', reg.phone),
        _buildInfoTile('Email', reg.email),
        _buildInfoTile(
          'Occupant Type',
          reg.occupantType.name[0].toUpperCase() +
              reg.occupantType.name.substring(1),
        ),
        const SizedBox(height: 16),

        // Swimmers section
        _buildSectionTitle(
            'Registered Swimmers (${data.swimmers.length}/${reg.maxPax})'),
        if (data.swimmers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No swimmers registered.',
                style: TextStyle(color: Colors.grey[500])),
          )
        else
          ...data.swimmers.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _brand.withValues(alpha: 0.1),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              title: Text(s.fullName),
              trailing: s.age != null
                  ? Text('Age ${s.age}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13))
                  : null,
              subtitle: s.birthdate != null
                  ? Text(dateFormat.format(s.birthdate!),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12))
                  : null,
            );
          }),
        const SizedBox(height: 16),

        // Emergency contact
        _buildSectionTitle('Emergency Contact'),
        _buildInfoTile('Name', reg.emergencyContactName),
        _buildInfoTile('Phone', reg.emergencyContactPhone),
        const SizedBox(height: 16),

        // Approval date
        if (reg.approved && reg.approvedAt != null) ...[
          _buildInfoTile('Approved On', dateFormat.format(reg.approvedAt!)),
          const SizedBox(height: 8),
        ],

        // Edit lock (unit-level or 3-month rule)
        if (data.unitLocked || !reg.canEdit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.unitLocked && data.unitLockDate != null
                        ? 'Editing locked until ${dateFormat.format(data.unitLockDate!)}'
                        : 'Edits locked until ${dateFormat.format(reg.nextEditableDate)}',
                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Edit button
        if (!data.unitLocked && reg.canEdit) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => _RegistrationFormScreen(
                        unitId: data.unitId,
                        unitNo: data.unitNo,
                        unitType: data.unitType,
                        unitMemberNames: data.unitMemberNames,
                        maxPaxMap: data.maxPaxMap,
                        existingRegistration: reg,
                        existingSwimmers: data.swimmers,
                      ),
                    ))
                    .then((_) => _loadData());
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Registration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: _brand),
        title: Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(label),
      ),
    );
  }
}

class _ResidentData {
  final PoolAccessRegistration? registration;
  final List<PoolSwimmer> swimmers;
  final String? unitId;
  final String? unitNo;
  final String? unitType;
  final String? profileName;
  final String? profilePhone;
  final String? profileEmail;
  final OccupantType? profileOccupantType;
  final List<String> unitMemberNames;
  final Map<String, int> maxPaxMap;
  final bool unitLocked;
  final DateTime? unitLockDate;
  final List<String> unitSwimmerNames;

  _ResidentData({
    this.registration,
    this.swimmers = const [],
    this.unitId,
    this.unitNo,
    this.unitType,
    this.profileName,
    this.profilePhone,
    this.profileEmail,
    this.profileOccupantType,
    this.unitMemberNames = const [],
    this.maxPaxMap = const {},
    this.unitLocked = false,
    this.unitLockDate,
    this.unitSwimmerNames = const [],
  });
}

// ============================================================
// SWIMMER ENTRY HELPER
// ============================================================

class _SwimmerEntry {
  final TextEditingController nameController;
  DateTime? birthdate;

  _SwimmerEntry({String? name, this.birthdate})
      : nameController = TextEditingController(text: name);

  void dispose() {
    nameController.dispose();
  }

  int? get age {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      years--;
    }
    return years;
  }
}

// ============================================================
// REGISTRATION FORM (shared resident + edit)
// ============================================================

class _RegistrationFormScreen extends StatefulWidget {
  final String? unitId;
  final String? unitNo;
  final String? unitType;
  final String? profileName;
  final String? profilePhone;
  final String? profileEmail;
  final OccupantType? profileOccupantType;
  final List<String> unitMemberNames;
  final Map<String, int> maxPaxMap;
  final PoolAccessRegistration? existingRegistration;
  final List<PoolSwimmer>? existingSwimmers;

  const _RegistrationFormScreen({
    this.unitId,
    this.unitNo,
    this.unitType,
    this.profileName,
    this.profilePhone,
    this.profileEmail,
    this.profileOccupantType,
    this.unitMemberNames = const [],
    this.maxPaxMap = const {},
    this.existingRegistration,
    this.existingSwimmers,
  });

  @override
  State<_RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<_RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  OccupantType _occupantType = OccupantType.resident;
  bool _acknowledgeRules = false;
  bool _acknowledgeWaiver = false;
  bool _isSubmitting = false;

  late int _maxPax;
  final List<_SwimmerEntry> _swimmers = [];

  bool get _isEditing => widget.existingRegistration != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final reg = widget.existingRegistration!;
      _fullNameController.text = reg.fullName;
      _phoneController.text = reg.phone;
      _emailController.text = reg.email;
      _emergencyNameController.text = reg.emergencyContactName;
      _emergencyPhoneController.text = reg.emergencyContactPhone;
      _occupantType = reg.occupantType;
      _maxPax = reg.maxPax;
      _acknowledgeRules = true;
      _acknowledgeWaiver = true;

      if (widget.existingSwimmers != null) {
        for (final s in widget.existingSwimmers!) {
          _swimmers
              .add(_SwimmerEntry(name: s.fullName, birthdate: s.birthdate));
        }
      }
    } else {
      _maxPax = _resolveMaxPax(widget.unitType, widget.maxPaxMap);
      if (widget.profileName != null) {
        _fullNameController.text = widget.profileName!;
      }
      if (widget.profilePhone != null) {
        _phoneController.text = widget.profilePhone!;
      }
      if (widget.profileEmail != null) {
        _emailController.text = widget.profileEmail!;
      }
      if (widget.profileOccupantType != null) {
        _occupantType = widget.profileOccupantType!;
      }
      _swimmers.add(_SwimmerEntry());
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    for (final s in _swimmers) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSwimmer() {
    if (_swimmers.length >= _maxPax) return;
    setState(() => _swimmers.add(_SwimmerEntry()));
  }

  void _removeSwimmer(int index) {
    if (_swimmers.length <= 1) return;
    setState(() {
      _swimmers[index].dispose();
      _swimmers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final validSwimmers = _swimmers
        .where((s) => s.nameController.text.trim().isNotEmpty)
        .toList();
    if (validSwimmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one swimmer.')),
      );
      return;
    }

    if (!_acknowledgeRules || !_acknowledgeWaiver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please acknowledge all terms.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<PoolAccessRepository>();

      final regId = await repo.upsertRegistration(
        id: widget.existingRegistration?.id,
        communityId: appState.activeCommunityId!,
        unitId: widget.unitId,
        occupantType: _occupantType,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        maxPax: _maxPax,
        acknowledgements: {
          'pool_rules': _acknowledgeRules,
          'liability_waiver': _acknowledgeWaiver,
        },
      );

      await repo.saveSwimmers(
        registrationId: regId,
        swimmers: validSwimmers.map((s) {
          return {
            'full_name': s.nameController.text.trim(),
            if (s.birthdate != null)
              'birthdate': s.birthdate!.toIso8601String(),
          };
        }).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Registration updated.'
                : 'Registration submitted. Awaiting approval.'),
            backgroundColor: _brand,
          ),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Registration' : 'Pool Registration'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Unit info
            if (widget.unitNo != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.home, color: _brand),
                  title: Text('Unit ${widget.unitNo}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Max $_maxPax',
                        style: const TextStyle(
                            color: _brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Personal info
            const Text('Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<OccupantType>(
              initialValue: _occupantType,
              decoration: const InputDecoration(
                labelText: 'Occupant Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: OccupantType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child:
                      Text(type.name[0].toUpperCase() + type.name.substring(1)),
                );
              }).toList(),
              onChanged: widget.profileOccupantType != null
                  ? null
                  : (value) {
                      if (value != null) setState(() => _occupantType = value);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              enabled:
                  widget.profileName == null || widget.profileName!.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Owner / Tenant Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              enabled:
                  widget.profilePhone == null || widget.profilePhone!.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              enabled:
                  widget.profileEmail == null || widget.profileEmail!.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (!v!.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Swimmers section
            Row(
              children: [
                const Icon(Icons.pool, color: _brand, size: 20),
                const SizedBox(width: 8),
                const Text('Registered Swimmers',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_swimmers.length}/$_maxPax',
                    style: TextStyle(
                      color: _swimmers.length >= _maxPax
                          ? Colors.red
                          : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 12),

            ...List.generate(_swimmers.length, (index) {
              final entry = _swimmers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _brand.withValues(alpha: 0.1),
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    color: _brand,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Autocomplete<String>(
                              initialValue: TextEditingValue(
                                  text: entry.nameController.text),
                              optionsBuilder: (textEditingValue) {
                                final query =
                                    textEditingValue.text.toLowerCase();
                                if (query.isEmpty) return const [];
                                return widget.unitMemberNames.where(
                                  (name) => name.toLowerCase().contains(query),
                                );
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                // Sync the external controller
                                controller.addListener(() {
                                  entry.nameController.text = controller.text;
                                });
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Swimmer Name',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) =>
                                      (v?.isEmpty ?? true) ? 'Required' : null,
                                );
                              },
                              onSelected: (value) {
                                entry.nameController.text = value;
                              },
                            ),
                          ),
                          if (_swimmers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 22),
                              onPressed: () => _removeSwimmer(index),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 38),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: entry.birthdate ??
                                      DateTime.now().subtract(
                                          const Duration(days: 365 * 18)),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => entry.birthdate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Birthday',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon:
                                      Icon(Icons.calendar_today, size: 18),
                                ),
                                child: Text(
                                  entry.birthdate != null
                                      ? dateFormat.format(entry.birthdate!)
                                      : '',
                                  style: TextStyle(
                                    color: entry.birthdate != null
                                        ? null
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            child: Text(
                              entry.age != null ? 'Age ${entry.age}' : '',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (_swimmers.length < _maxPax)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _addSwimmer,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Swimmer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Emergency contact
            const Text('Emergency Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Acknowledgements
            const Text('Acknowledgements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acknowledgeRules,
              onChanged: (v) => setState(() => _acknowledgeRules = v ?? false),
              title: const Text(
                  'I have read and agree to follow the pool rules and regulations.'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: _brand,
            ),
            CheckboxListTile(
              value: _acknowledgeWaiver,
              onChanged: (v) => setState(() => _acknowledgeWaiver = v ?? false),
              title: const Text(
                  'I acknowledge that use of the pool is at my own risk and liability.'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: _brand,
            ),
            const SizedBox(height: 12),

            // 3-month info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Registration is valid for 3 months. After approval, edits are locked until the renewal period.',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            HOAppButton(
              label: _isEditing ? 'Update Registration' : 'Submit Registration',
              isLoading: _isSubmitting,
              onPressed:
                  _isSubmitting || !_acknowledgeRules || !_acknowledgeWaiver
                      ? null
                      : _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STAFF VIEW
// ============================================================

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

  void _openStaffRegistration() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => _StaffRegistrationScreen(
            onRegistered: _loadRegistrations,
          ),
        ))
        .then((_) => _loadRegistrations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool Access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Max Swimmers Settings',
            onPressed: () => _showMaxPaxSettings(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openStaffRegistration,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Register'),
      ),
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
                    ElevatedButton(
                      onPressed: _loadRegistrations,
                      child: const Text('Retry'),
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
                    const Text('No registrations yet',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('Tap + to register swimmers for a unit',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: registrations.length,
              itemBuilder: (context, index) {
                final reg = registrations[index];
                return _RegistrationCard(
                  registration: reg,
                  onRefresh: _loadRegistrations,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showMaxPaxSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _MaxPaxSettingsScreen(),
    ));
  }
}

// ============================================================
// REGISTRATION CARD (staff list item)
// ============================================================

class _RegistrationCard extends StatelessWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationCard({
    required this.registration,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final reg = registration;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _RegistrationDetailScreen(
              registration: reg,
              onRefresh: onRefresh,
            ),
          ));
        },
        leading: CircleAvatar(
          backgroundColor: reg.approved
              ? _brand.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          child: Icon(
            reg.approved ? Icons.check : Icons.pending,
            color: reg.approved ? _brand : Colors.orange,
          ),
        ),
        title: Text(
          reg.unitNo != null ? 'Unit ${reg.unitNo}' : reg.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${reg.occupantType.name[0].toUpperCase()}${reg.occupantType.name.substring(1)} · ${reg.fullName}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: reg.approved
            ? null
            : _ApproveButton(registrationId: reg.id, onApproved: onRefresh),
      ),
    );
  }
}

class _ApproveButton extends StatefulWidget {
  final String registrationId;
  final VoidCallback onApproved;

  const _ApproveButton({
    required this.registrationId,
    required this.onApproved,
  });

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return TextButton(
      onPressed: () async {
        setState(() => _loading = true);
        try {
          final repo = context.read<PoolAccessRepository>();
          await repo.approveRegistration(widget.registrationId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration approved')),
            );
            widget.onApproved();
          }
        } catch (e) {
          if (context.mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
      style: TextButton.styleFrom(foregroundColor: _brand),
      child: const Text('Approve'),
    );
  }
}

// ============================================================
// REGISTRATION DETAIL SCREEN (staff)
// ============================================================

class _RegistrationDetailScreen extends StatefulWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationDetailScreen({
    required this.registration,
    required this.onRefresh,
  });

  @override
  State<_RegistrationDetailScreen> createState() =>
      _RegistrationDetailScreenState();
}

class _RegistrationDetailScreenState extends State<_RegistrationDetailScreen> {
  List<PoolSwimmer>? _swimmers;
  bool _loadingSwimmers = true;
  bool _isApproving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadSwimmers();
  }

  Future<void> _loadSwimmers() async {
    try {
      final repo = context.read<PoolAccessRepository>();
      final swimmers = await repo.getSwimmers(widget.registration.id);
      if (mounted) {
        setState(() {
          _swimmers = swimmers;
          _loadingSwimmers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSwimmers = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _isApproving = true);
    try {
      final repo = context.read<PoolAccessRepository>();
      await repo.approveRegistration(widget.registration.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration approved')),
        );
        widget.onRefresh();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApproving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final repo = context.read<PoolAccessRepository>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Registration'),
        content: Text(
            'Delete pool registration for ${widget.registration.fullName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await repo.deleteRegistration(widget.registration.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration deleted')),
        );
        widget.onRefresh();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = widget.registration;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(reg.unitNo != null ? 'Unit ${reg.unitNo}' : reg.fullName),
        actions: [
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red)),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          Card(
            color: reg.approved
                ? _brand.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    reg.approved ? Icons.check_circle : Icons.pending,
                    color: reg.approved ? _brand : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    reg.approved ? 'APPROVED' : 'PENDING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: reg.approved ? _brand : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact info
          const Text('Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _infoRow('Name', reg.fullName),
          _infoRow('Phone', reg.phone),
          _infoRow('Email', reg.email),
          _infoRow(
              'Type',
              reg.occupantType.name[0].toUpperCase() +
                  reg.occupantType.name.substring(1)),
          const SizedBox(height: 16),

          // Emergency
          const Text('Emergency Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _infoRow('Name', reg.emergencyContactName),
          _infoRow('Phone', reg.emergencyContactPhone),
          const SizedBox(height: 16),

          // Swimmers
          Row(
            children: [
              const Text('Registered Swimmers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_swimmers != null)
                Text('${_swimmers!.length}/${reg.maxPax}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingSwimmers)
            const Center(child: CircularProgressIndicator())
          else if (_swimmers == null || _swimmers!.isEmpty)
            Text('No swimmers registered.',
                style: TextStyle(color: Colors.grey[500]))
          else
            ...(_swimmers!.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: _brand.withValues(alpha: 0.1),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: _brand,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                title: Text(s.fullName),
                subtitle: s.birthdate != null
                    ? Text(dateFormat.format(s.birthdate!),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                    : null,
                trailing: s.age != null
                    ? Text('Age ${s.age}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13))
                    : null,
              );
            })),
          const SizedBox(height: 16),

          // Approval info
          if (reg.approved && reg.approvedAt != null) ...[
            _infoRow('Approved', dateFormat.format(reg.approvedAt!)),
            const SizedBox(height: 16),
          ],

          // Approve button
          if (!reg.approved) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isApproving ? null : _approve,
                icon: _isApproving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(
                    _isApproving ? 'Approving...' : 'Approve Registration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STAFF REGISTRATION SCREEN (register on behalf of unit)
// ============================================================

class _StaffRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistered;

  const _StaffRegistrationScreen({required this.onRegistered});

  @override
  State<_StaffRegistrationScreen> createState() =>
      _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState extends State<_StaffRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  List<Unit> _availableUnits = [];
  Unit? _selectedUnit;
  OccupantType _occupantType = OccupantType.resident;
  bool _isLoadingUnits = true;
  bool _isSubmitting = false;
  String? _loadError;

  late int _maxPax;
  final List<_SwimmerEntry> _swimmers = [_SwimmerEntry()];
  List<String> _unitMemberNames = [];
  Map<String, int> _maxPaxMap = {};

  @override
  void initState() {
    super.initState();
    _maxPax = 5;
    _loadUnits();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    for (final s in _swimmers) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final appState = context.read<AppState>();
      final communityId = appState.activeCommunityId;
      if (communityId == null) throw Exception('No community selected');

      final householdRepo = context.read<HouseholdRepository>();
      final poolRepo = context.read<PoolAccessRepository>();

      final allUnits = await householdRepo.getUnits(communityId);
      final registrations = await poolRepo.getRegistrations(communityId);
      final maxPaxMap = await poolRepo.getMaxPaxByUnitType(communityId);

      final registeredUnitIds = registrations
          .where((r) => r.unitId != null)
          .map((r) => r.unitId)
          .toSet();

      if (mounted) {
        setState(() {
          _availableUnits =
              allUnits.where((u) => !registeredUnitIds.contains(u.id)).toList();
          _maxPaxMap = maxPaxMap;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingUnits = false;
        });
      }
    }
  }

  Future<void> _onUnitSelected(Unit? unit) async {
    setState(() {
      _selectedUnit = unit;
      _unitMemberNames = [];
    });
    if (unit == null) return;

    _maxPax = _resolveMaxPax(unit.unitType, _maxPaxMap);
    while (_swimmers.length > _maxPax) {
      _swimmers.last.dispose();
      _swimmers.removeLast();
    }

    try {
      final householdRepo = context.read<HouseholdRepository>();
      final members = await householdRepo.getHouseholdMembers(unit.id);
      if (mounted) {
        setState(() {
          _unitMemberNames = members
              .map((m) => m.displayName)
              .where((n) => n != 'Unknown')
              .toList();
        });
      }
    } catch (_) {}
    setState(() {});
  }

  void _addSwimmer() {
    if (_swimmers.length >= _maxPax) return;
    setState(() => _swimmers.add(_SwimmerEntry()));
  }

  void _removeSwimmer(int index) {
    if (_swimmers.length <= 1) return;
    setState(() {
      _swimmers[index].dispose();
      _swimmers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit.')),
      );
      return;
    }

    final validSwimmers = _swimmers
        .where((s) => s.nameController.text.trim().isNotEmpty)
        .toList();
    if (validSwimmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one swimmer.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<PoolAccessRepository>();

      final regId = await repo.staffCreateRegistration(
        communityId: appState.activeCommunityId!,
        unitId: _selectedUnit!.id,
        occupantType: _occupantType,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        maxPax: _maxPax,
      );

      await repo.saveSwimmers(
        registrationId: regId,
        swimmers: validSwimmers.map((s) {
          return {
            'full_name': s.nameController.text.trim(),
            if (s.birthdate != null)
              'birthdate': s.birthdate!.toIso8601String(),
          };
        }).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Swimmers registered for Unit ${_selectedUnit!.unitNo}'),
            backgroundColor: _brand,
          ),
        );
        widget.onRegistered();
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Register Swimmers')),
      body: _isLoadingUnits
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error: $_loadError'),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Unit selector
                      const Text('Select Unit',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_availableUnits.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'All units already have pool registrations.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<Unit>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          items: _availableUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(
                                  'Unit ${unit.unitNo}${unit.unitType != null ? ' (${unit.unitType})' : ''}'),
                            );
                          }).toList(),
                          onChanged: _onUnitSelected,
                          validator: (v) =>
                              v == null ? 'Please select a unit' : null,
                        ),
                        if (_selectedUnit != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Max $_maxPax swimmers allowed',
                              style: const TextStyle(
                                  color: _brand, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),

                      // Registrant info
                      const Text('Registrant Information',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<OccupantType>(
                        initialValue: _occupantType,
                        decoration: const InputDecoration(
                          labelText: 'Occupant Type',
                          border: OutlineInputBorder(),
                        ),
                        items: OccupantType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name[0].toUpperCase() +
                                type.name.substring(1)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _occupantType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Owner / Tenant Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Required';
                          if (!v!.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Swimmers
                      Row(
                        children: [
                          const Icon(Icons.pool, color: _brand, size: 20),
                          const SizedBox(width: 8),
                          const Text('Swimmers',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${_swimmers.length}/$_maxPax',
                              style: TextStyle(
                                color: _swimmers.length >= _maxPax
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...List.generate(_swimmers.length, (index) {
                        final entry = _swimmers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor:
                                          _brand.withValues(alpha: 0.1),
                                      child: Text('${index + 1}',
                                          style: const TextStyle(
                                              color: _brand,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Autocomplete<String>(
                                        initialValue: TextEditingValue(
                                            text: entry.nameController.text),
                                        optionsBuilder: (textEditingValue) {
                                          final query = textEditingValue.text
                                              .toLowerCase();
                                          if (query.isEmpty) return const [];
                                          return _unitMemberNames.where(
                                            (name) => name
                                                .toLowerCase()
                                                .contains(query),
                                          );
                                        },
                                        fieldViewBuilder: (context, controller,
                                            focusNode, onFieldSubmitted) {
                                          controller.addListener(() {
                                            entry.nameController.text =
                                                controller.text;
                                          });
                                          return TextFormField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            decoration: const InputDecoration(
                                              labelText: 'Swimmer Name',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            validator: (v) =>
                                                (v?.isEmpty ?? true)
                                                    ? 'Required'
                                                    : null,
                                          );
                                        },
                                        onSelected: (value) {
                                          entry.nameController.text = value;
                                        },
                                      ),
                                    ),
                                    if (_swimmers.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                            size: 22),
                                        onPressed: () => _removeSwimmer(index),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 38),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: entry.birthdate ??
                                                DateTime.now().subtract(
                                                    const Duration(
                                                        days: 365 * 18)),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (date != null) {
                                            setState(
                                                () => entry.birthdate = date);
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Birthday',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            suffixIcon: Icon(
                                                Icons.calendar_today,
                                                size: 18),
                                          ),
                                          child: Text(
                                            entry.birthdate != null
                                                ? dateFormat
                                                    .format(entry.birthdate!)
                                                : '',
                                            style: TextStyle(
                                              color: entry.birthdate != null
                                                  ? null
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        entry.age != null
                                            ? 'Age ${entry.age}'
                                            : '',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      if (_swimmers.length < _maxPax)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton.icon(
                            onPressed: _addSwimmer,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Swimmer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _brand,
                              side: const BorderSide(color: _brand),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Emergency contact
                      const Text('Emergency Contact',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emergencyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emergencyPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This registration will be automatically approved since it is created by staff.',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      HOAppButton(
                        label: 'Register Swimmers',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || _selectedUnit == null
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

// ============================================================
// MAX PAX SETTINGS SCREEN (mobile)
// ============================================================

class _MaxPaxSettingsScreen extends StatefulWidget {
  const _MaxPaxSettingsScreen();

  @override
  State<_MaxPaxSettingsScreen> createState() => _MaxPaxSettingsScreenState();
}

class _MaxPaxSettingsScreenState extends State<_MaxPaxSettingsScreen> {
  List<UnitType>? _unitTypes;
  bool _isLoading = true;
  String? _error;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadUnitTypes();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnitTypes() async {
    try {
      final appState = context.read<AppState>();
      final repo = context.read<HouseholdRepository>();
      final types = await repo.getUnitTypes(appState.activeCommunityId!);
      if (mounted) {
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        setState(() {
          _unitTypes = types;
          _isLoading = false;
          for (final t in types) {
            _controllers[t.id] =
                TextEditingController(text: t.maxPax.toString());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save(UnitType ut) async {
    final controller = _controllers[ut.id];
    if (controller == null) return;
    final newValue = int.tryParse(controller.text.trim());
    if (newValue == null || newValue < 1 || newValue > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number between 1 and 20.')),
      );
      return;
    }
    if (newValue == ut.maxPax) return;

    setState(() => _saving.add(ut.id));
    try {
      final repo = context.read<HouseholdRepository>();
      await repo.updateUnitType(id: ut.id, maxPax: newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${ut.name} updated to max $newValue swimmers.')),
        );
        _loadUnitTypes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(ut.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Max Swimmers Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _unitTypes == null || _unitTypes!.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No unit types configured.\n'
                          'Add unit types in Household management first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Set the maximum number of registered swimmers per unit type.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ..._unitTypes!.map((ut) {
                          final controller = _controllers[ut.id]!;
                          final isSaving = _saving.contains(ut.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(ut.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        if (ut.description != null &&
                                            ut.description!.isNotEmpty)
                                          Text(ut.description!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 64,
                                    child: TextFormField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : IconButton(
                                          icon: Icon(Icons.check_circle,
                                              color: _brand),
                                          onPressed: () => _save(ut),
                                          tooltip: 'Save',
                                        ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}
