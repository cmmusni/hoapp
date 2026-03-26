import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _brandColor = Color(0xff215e3f);

/// Determine max swimmers allowed based on unit type name.
int _maxPaxForUnitType(String? unitType) {
  if (unitType == null) return 5;
  final lower = unitType.toLowerCase();
  if (lower.contains('cluster')) return 7;
  if (lower.contains('2') || lower.contains('two')) return 5;
  if (lower.contains('1') || lower.contains('one')) return 3;
  return 5;
}

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
    final registration = await repo.getMyRegistration(communityId);
    List<PoolSwimmer> swimmers = [];
    if (registration != null) {
      swimmers = await repo.getSwimmers(registration.id);
    }

    // Fetch unit info for this user
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
      // Profile
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
      // Fallback to auth email
      profileEmail ??= client.auth.currentUser?.email;

      // Unit info
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

        // Fetch unit members for swimmer autocomplete
        if (unitId != null) {
          final householdRepo = context.read<HouseholdRepository>();
          final members = await householdRepo.getHouseholdMembers(unitId);
          unitMemberNames = members
              .map((m) => m.displayName)
              .where((n) => n != 'Unknown')
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    HOAppButton(
                      label: 'Retry',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;

            if (data.registration == null) {
              return _RegistrationForm(
                unitId: data.unitId,
                unitNo: data.unitNo,
                unitType: data.unitType,
                profileName: data.profileName,
                profilePhone: data.profilePhone,
                profileEmail: data.profileEmail,
                profileOccupantType: data.profileOccupantType,
                unitMemberNames: data.unitMemberNames,
                onSubmitted: _loadData,
              );
            }

            return _RegistrationDetails(
              registration: data.registration!,
              swimmers: data.swimmers,
              unitNo: data.unitNo,
              unitType: data.unitType,
              unitMemberNames: data.unitMemberNames,
              onRefresh: _loadData,
            );
          },
        ),
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
  });
}

// ============================================================
// SWIMMER ENTRY (form helper)
// ============================================================

class _SwimmerEntry {
  final TextEditingController nameController;
  final FocusNode focusNode;
  DateTime? birthdate;

  _SwimmerEntry({String? name, this.birthdate})
      : nameController = TextEditingController(text: name),
        focusNode = FocusNode();

  void dispose() {
    nameController.dispose();
    focusNode.dispose();
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
// REGISTRATION FORM
// ============================================================

class _RegistrationForm extends StatefulWidget {
  final String? unitId;
  final String? unitNo;
  final String? unitType;
  final String? profileName;
  final String? profilePhone;
  final String? profileEmail;
  final OccupantType? profileOccupantType;
  final List<String> unitMemberNames;
  final PoolAccessRegistration? existingRegistration;
  final List<PoolSwimmer>? existingSwimmers;
  final VoidCallback onSubmitted;

  const _RegistrationForm({
    this.unitId,
    this.unitNo,
    this.unitType,
    this.profileName,
    this.profilePhone,
    this.profileEmail,
    this.profileOccupantType,
    this.unitMemberNames = const [],
    this.existingRegistration,
    this.existingSwimmers,
    required this.onSubmitted,
  });

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

      // Load existing swimmers
      if (widget.existingSwimmers != null) {
        for (final s in widget.existingSwimmers!) {
          _swimmers.add(_SwimmerEntry(
            name: s.fullName,
            birthdate: s.birthdate,
          ));
        }
      }
    } else {
      _maxPax = _maxPaxForUnitType(widget.unitType);
      // Prefill from profile
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
      // Start with one empty swimmer row
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== BANNER HEADER =====
                _buildBanner(),
                const SizedBox(height: 24),

                // ===== UNIT INFO CARD =====
                if (widget.unitNo != null) ...[
                  _buildUnitInfoCard(),
                  const SizedBox(height: 24),
                ],

                // ===== PERSONAL INFORMATION =====
                _sectionHeader('Personal Information', Icons.person),
                const SizedBox(height: 12),
                DropdownButtonFormField<OccupantType>(
                  value: _occupantType,
                  decoration: InputDecoration(
                    labelText: 'Occupant Type',
                    border: const OutlineInputBorder(),
                    filled: widget.profileOccupantType != null,
                    fillColor: Colors.grey.shade100,
                  ),
                  items: OccupantType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                          type.name[0].toUpperCase() + type.name.substring(1)),
                    );
                  }).toList(),
                  onChanged: widget.profileOccupantType != null
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _occupantType = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameController,
                  enabled:
                      widget.profileName == null || widget.profileName!.isEmpty,
                  decoration: InputDecoration(
                    labelText: 'Owner / Tenant Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    filled: widget.profileName != null &&
                        widget.profileName!.isNotEmpty,
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  enabled: widget.profilePhone == null ||
                      widget.profilePhone!.isEmpty,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                    filled: widget.profilePhone != null &&
                        widget.profilePhone!.isNotEmpty,
                    fillColor: Colors.grey.shade100,
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  enabled: widget.profileEmail == null ||
                      widget.profileEmail!.isEmpty,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                    filled: widget.profileEmail != null &&
                        widget.profileEmail!.isNotEmpty,
                    fillColor: Colors.grey.shade100,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Required';
                    if (!v!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ===== REGISTERED SWIMMERS =====
                _sectionHeader('Registered Swimmers', Icons.pool),
                const SizedBox(height: 4),
                Text(
                  '${_swimmers.length} of $_maxPax swimmers',
                  style: TextStyle(
                    color: _swimmers.length >= _maxPax
                        ? Colors.red
                        : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildSwimmerRows(),
                const SizedBox(height: 8),
                if (_swimmers.length < _maxPax)
                  OutlinedButton.icon(
                    onPressed: _addSwimmer,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Swimmer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandColor,
                      side: const BorderSide(color: _brandColor),
                    ),
                  ),
                const SizedBox(height: 24),

                // ===== EMERGENCY CONTACT =====
                _sectionHeader('Emergency Contact', Icons.emergency),
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

                // ===== ACKNOWLEDGEMENTS =====
                _sectionHeader('Acknowledgements', Icons.verified_user),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _acknowledgeRules,
                  onChanged: (v) =>
                      setState(() => _acknowledgeRules = v ?? false),
                  title: const Text(
                    'I have read and agree to follow the pool rules and regulations.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _brandColor,
                ),
                CheckboxListTile(
                  value: _acknowledgeWaiver,
                  onChanged: (v) =>
                      setState(() => _acknowledgeWaiver = v ?? false),
                  title: const Text(
                    'I acknowledge that use of the pool is at my own risk and liability.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _brandColor,
                ),
                const SizedBox(height: 12),

                // 3-month info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
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

                // ===== SUBMIT =====
                SizedBox(
                  width: double.infinity,
                  child: HOAppButton(
                    label: _isEditing
                        ? 'Update Registration'
                        : 'Submit Registration',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ||
                            !_acknowledgeRules ||
                            !_acknowledgeWaiver
                        ? null
                        : _submitRegistration,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Banner ----------
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandColor, Color(0xff2e8b57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pool, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Pool Registration' : 'Pool Registration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Update your swimmers and information'
                      : 'Register your household for pool access',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Unit Info Card ----------
  Widget _buildUnitInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home, color: _brandColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${widget.unitNo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.unitType != null)
                    Text(
                      widget.unitType!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Max $_maxPax swimmers',
                style: const TextStyle(
                  color: _brandColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Swimmer Rows ----------
  List<Widget> _buildSwimmerRows() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return List.generate(_swimmers.length, (index) {
      final entry = _swimmers[index];
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Number badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _brandColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _brandColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name with unit member autocomplete
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return RawAutocomplete<String>(
                      textEditingController: entry.nameController,
                      focusNode: entry.focusNode,
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text.toLowerCase();
                        if (query.isEmpty) return const [];
                        return widget.unitMemberNames.where(
                          (name) => name.toLowerCase().contains(query),
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            errorStyle: TextStyle(height: 0.5),
                          ),
                          validator: (v) =>
                              (v?.isEmpty ?? true) ? 'Required' : null,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 200,
                                maxWidth: constraints.maxWidth,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, i) {
                                  final option = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person_outline,
                                        size: 18),
                                    title: Text(option,
                                        style: const TextStyle(fontSize: 14)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Birthday
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: entry.birthdate ??
                          DateTime.now()
                              .subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => entry.birthdate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthday',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      entry.birthdate != null
                          ? dateFormat.format(entry.birthdate!)
                          : '',
                      style: TextStyle(
                        color: entry.birthdate != null ? null : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Age
              SizedBox(
                width: 48,
                child: Text(
                  entry.age != null ? 'Age ${entry.age}' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Remove
              if (_swimmers.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red, size: 22),
                  onPressed: () => _removeSwimmer(index),
                  tooltip: 'Remove',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ---------- Submit ----------
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one swimmer has a name
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

      // Save swimmers
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
                ? 'Registration updated successfully.'
                : 'Registration submitted. Awaiting staff approval.'),
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

  // ---------- Section Header ----------
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _brandColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// REGISTRATION DETAILS (resident view of existing registration)
// ============================================================

class _RegistrationDetails extends StatelessWidget {
  final PoolAccessRegistration registration;
  final List<PoolSwimmer> swimmers;
  final String? unitNo;
  final String? unitType;
  final List<String> unitMemberNames;
  final VoidCallback onRefresh;

  const _RegistrationDetails({
    required this.registration,
    required this.swimmers,
    this.unitNo,
    this.unitType,
    this.unitMemberNames = const [],
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final canEdit = registration.canEdit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== BANNER =====
              _buildBanner(),
              const SizedBox(height: 24),

              // ===== UNIT INFO =====
              if (unitNo != null) ...[
                _buildUnitCard(),
                const SizedBox(height: 20),
              ],

              // ===== PERSONAL INFORMATION =====
              _buildSection('Personal Information', Icons.person, [
                _InfoRow(
                  label: 'Occupant Type',
                  value: registration.occupantType.name[0].toUpperCase() +
                      registration.occupantType.name.substring(1),
                ),
                _InfoRow(label: 'Name', value: registration.fullName),
                _InfoRow(label: 'Phone', value: registration.phone),
                _InfoRow(label: 'Email', value: registration.email),
              ]),
              const SizedBox(height: 20),

              // ===== SWIMMERS TABLE =====
              _buildSwimmersSection(dateFormat),
              const SizedBox(height: 20),

              // ===== EMERGENCY CONTACT =====
              _buildSection('Emergency Contact', Icons.emergency, [
                _InfoRow(
                    label: 'Name', value: registration.emergencyContactName),
                _InfoRow(
                    label: 'Phone', value: registration.emergencyContactPhone),
              ]),

              // ===== APPROVAL =====
              if (registration.approved && registration.approvedAt != null) ...[
                const SizedBox(height: 20),
                _buildSection('Approval', Icons.check_circle, [
                  _InfoRow(
                    label: 'Approved At',
                    value: dateFormat.format(registration.approvedAt!),
                  ),
                ]),
              ],

              // ===== EDIT LOCK =====
              if (!canEdit) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                              fontSize: 13, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ===== EDIT BUTTON =====
              if (canEdit) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: HOAppButton(
                    label: 'Edit Registration',
                    icon: Icons.edit,
                    onPressed: () => _showEditForm(context),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandColor, Color(0xff2e8b57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pool, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Pool Registration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              registration.approved ? 'APPROVED' : 'PENDING',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home, color: _brandColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit $unitNo',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if (unitType != null)
                    Text(unitType!,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${swimmers.length} / ${registration.maxPax} swimmers',
                style: const TextStyle(
                  color: _brandColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwimmersSection(DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pool, color: _brandColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Registered Swimmers',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${swimmers.length} of ${registration.maxPax}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (swimmers.isEmpty)
          Text('No swimmers registered.',
              style: TextStyle(color: Colors.grey[500]))
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // Header row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 32,
                          child: Text('#',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 3,
                          child: Text('Name',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text('Birthday',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(
                          width: 60,
                          child: Text('Age',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Data rows
                ...swimmers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: i < swimmers.length - 1
                          ? Border(
                              bottom: BorderSide(color: Colors.grey.shade200))
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 32,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                        Expanded(
                            flex: 3,
                            child: Text(s.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                        Expanded(
                          flex: 2,
                          child: Text(
                            s.birthdate != null
                                ? dateFormat.format(s.birthdate!)
                                : '—',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            s.age != null ? '${s.age}' : '—',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _brandColor, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  void _showEditForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Edit Registration'),
            backgroundColor: _brandColor,
            foregroundColor: Colors.white,
          ),
          body: MultiProvider(
            providers: [
              Provider.value(value: context.read<PoolAccessRepository>()),
              Provider.value(value: context.read<AppState>()),
            ],
            child: _RegistrationForm(
              unitId: registration.unitId,
              unitNo: unitNo,
              unitType: unitType,
              unitMemberNames: unitMemberNames,
              existingRegistration: registration,
              existingSwimmers: swimmers,
              onSubmitted: () {
                Navigator.of(context).pop();
                onRefresh();
              },
            ),
          ),
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
                return _RegistrationCard(
                  registration: registrations[index],
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

// ============================================================
// REGISTRATION CARD (staff list item)
// ============================================================

class _RegistrationCard extends StatefulWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationCard({
    required this.registration,
    required this.onRefresh,
  });

  @override
  State<_RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<_RegistrationCard> {
  bool _isApproving = false;

  @override
  Widget build(BuildContext context) {
    final reg = widget.registration;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: reg.approved
                    ? _brandColor.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                child: Icon(
                  reg.approved ? Icons.check : Icons.pending,
                  color: reg.approved ? _brandColor : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reg.unitNo != null ? 'Unit ${reg.unitNo}' : reg.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reg.occupantType.name[0].toUpperCase()}${reg.occupantType.name.substring(1)} · ${reg.fullName} · ${reg.phone}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!reg.approved)
                _isApproving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandColor,
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

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _RegistrationDetailDialog(
        registration: widget.registration,
        onRefresh: widget.onRefresh,
      ),
    );
  }
}

// ============================================================
// REGISTRATION DETAIL DIALOG (staff)
// ============================================================

class _RegistrationDetailDialog extends StatefulWidget {
  final PoolAccessRegistration registration;
  final VoidCallback onRefresh;

  const _RegistrationDetailDialog({
    required this.registration,
    required this.onRefresh,
  });

  @override
  State<_RegistrationDetailDialog> createState() =>
      _RegistrationDetailDialogState();
}

class _RegistrationDetailDialogState extends State<_RegistrationDetailDialog> {
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

  @override
  Widget build(BuildContext context) {
    final reg = widget.registration;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
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
                  const Icon(Icons.pool, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reg.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${reg.occupantType.name[0].toUpperCase()}${reg.occupantType.name.substring(1)} · ${reg.phone}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reg.approved ? 'APPROVED' : 'PENDING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                    // Personal
                    const Text('Contact',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Email', value: reg.email),
                    _InfoRow(label: 'Phone', value: reg.phone),
                    const SizedBox(height: 16),

                    // Emergency
                    const Text('Emergency Contact',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Name', value: reg.emergencyContactName),
                    _InfoRow(label: 'Phone', value: reg.emergencyContactPhone),
                    const SizedBox(height: 16),

                    // Swimmers
                    Row(
                      children: [
                        const Text('Registered Swimmers',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        if (_swimmers != null)
                          Text(
                            '${_swimmers!.length} / ${reg.maxPax}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSwimmersTable(dateFormat),

                    // Approval info
                    if (reg.approved && reg.approvedAt != null) ...[
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Approved',
                        value: dateFormat.format(reg.approvedAt!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  // Delete button
                  OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                    label: Text(
                      _isDeleting ? 'Deleting...' : 'Delete',
                      style: const TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Approve button
                  if (!reg.approved)
                    Expanded(
                      child: HOAppButton(
                        label: 'Approve Registration',
                        isLoading: _isApproving,
                        onPressed: _isApproving ? null : _approveRegistration,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwimmersTable(DateFormat dateFormat) {
    if (_loadingSwimmers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_swimmers == null || _swimmers!.isEmpty) {
      return Text('No swimmers registered.',
          style: TextStyle(color: Colors.grey[500]));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text('#',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(
                    flex: 3,
                    child: Text('Name',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('Birthday',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(
                    width: 48,
                    child: Text('Age',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
          ),
          ..._swimmers!.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: i < _swimmers!.length - 1
                    ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 28,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 13))),
                  Expanded(
                      flex: 3,
                      child: Text(s.fullName,
                          style: const TextStyle(fontSize: 13))),
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.birthdate != null
                          ? dateFormat.format(s.birthdate!)
                          : '—',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      s.age != null ? '${s.age}' : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _approveRegistration() async {
    setState(() => _isApproving = true);
    try {
      final repo = context.read<PoolAccessRepository>();
      await repo.approveRegistration(widget.registration.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration approved')),
        );
        widget.onRefresh();
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Registration'),
        content: Text(
          'Are you sure you want to delete the pool access registration for ${widget.registration.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRegistration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRegistration() async {
    setState(() => _isDeleting = true);
    try {
      final repo = context.read<PoolAccessRepository>();
      await repo.deleteRegistration(widget.registration.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration deleted')),
        );
        widget.onRefresh();
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
}

// ============================================================
// SHARED WIDGETS
// ============================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
