import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

class PoolAccessScreen extends StatefulWidget {
  const PoolAccessScreen({super.key});

  @override
  State<PoolAccessScreen> createState() => _PoolAccessScreenState();
}

class _PoolAccessScreenState extends State<PoolAccessScreen> {
  Future<dynamic>? _registrationFuture;

  @override
  void initState() {
    super.initState();
    _loadRegistration();
  }

  void _loadRegistration() {
    final appState = context.read<AppState>();
    if (appState.activeCommunityId != null) {
      final repo = context.read<PoolAccessRepository>();
      setState(() {
        _registrationFuture =
            repo.getMyRegistration(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool Access'),
      ),
      body: FutureBuilder<dynamic>(
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRegistration,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final registration = snapshot.data;

          if (registration == null) {
            return _buildNoRegistration();
          }

          return _buildRegistrationDetails(registration);
        },
      ),
    );
  }

  Widget _buildNoRegistration() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pool, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Pool Access Registration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Register for pool access to enjoy swimming privileges',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const PoolAccessRegistrationForm(),
                      ),
                    )
                    .then((_) => _loadRegistration());
              },
              icon: const Icon(Icons.app_registration),
              label: const Text('Register Now'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationDetails(dynamic registration) {
    final status = registration.status.toString();
    final isApproved = status.contains('approved');
    final isPending = status.contains('pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            color: isApproved
                ? Color.fromRGBO(39, 99, 67, 1).withOpacity(0.1)
                : isPending
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    isApproved
                        ? Icons.check_circle
                        : isPending
                            ? Icons.pending
                            : Icons.cancel,
                    size: 48,
                    color: isApproved
                        ? Color.fromRGBO(39, 99, 67, 1)
                        : isPending
                            ? Colors.orange
                            : Colors.red,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApproved
                              ? 'Active'
                              : isPending
                                  ? 'Pending Approval'
                                  : 'Rejected',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isApproved
                              ? 'Your pool access is active'
                              : isPending
                                  ? 'Awaiting staff review'
                                  : 'Please contact admin',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Registration details
          const Text(
            'Registration Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildInfoRow('Registered On', _formatDate(registration.createdAt)),

          if (isApproved) ...[
            const SizedBox(height: 16),
            _buildInfoRow('Expires On', _formatDate(registration.expiresAt)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Pool Access Guidelines',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Pool hours: 6:00 AM - 9:00 PM daily\n'
                      '• Maximum 2 hours per session\n'
                      '• Children under 12 must be supervised\n'
                      '• No outside food or drinks\n'
                      '• Proper swim attire required',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Pool Access Registration Form with document upload
class PoolAccessRegistrationForm extends StatefulWidget {
  const PoolAccessRegistrationForm({super.key});

  @override
  State<PoolAccessRegistrationForm> createState() =>
      _PoolAccessRegistrationFormState();
}

class _PoolAccessRegistrationFormState
    extends State<PoolAccessRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  OccupantType _occupantType = OccupantType.resident;
  DateTime? _birthdate;
  String? _idDocUrl;
  bool _acknowledgeRules = false;
  bool _acknowledgeLiability = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idDocUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a valid ID document')),
      );
      return;
    }

    if (!_acknowledgeRules || !_acknowledgeLiability) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please acknowledge all terms')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      final repo = context.read<PoolAccessRepository>();

      final acknowledgementsMap = {
        'rules_acknowledged': _acknowledgeRules,
        'liability_acknowledged': _acknowledgeLiability,
        'acknowledged_at': DateTime.now().toIso8601String(),
      };

      await repo.upsertRegistration(
        communityId: appState.activeCommunityId!,
        occupantType: _occupantType,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        birthdate: _birthdate,
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        idDocUrl: _idDocUrl,
        acknowledgements: acknowledgementsMap,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration submitted successfully!'),
            backgroundColor: Color.fromRGBO(39, 99, 67, 1),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pool Access Registration'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Registration Requirements',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Valid government-issued ID\n'
                      '• Emergency contact information\n'
                      '• Acknowledgement of pool rules\n'
                      '• Registration is valid for 1 year',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Occupant Type
            const Text('Occupant Type',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<OccupantType>(
              value: _occupantType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
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

            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Birthdate
            ListTile(
              title: Text(_birthdate == null
                  ? 'Birthdate (Optional)'
                  : 'Birthdate: ${_formatDate(_birthdate!)}'),
              leading: const Icon(Icons.calendar_today),
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().subtract(const Duration(days: 365 * 18)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _birthdate = date);
                }
              },
            ),
            const SizedBox(height: 24),

            // Emergency Contact Section
            const Text(
              'Emergency Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                prefixIcon: Icon(Icons.contact_emergency),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter emergency contact name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Phone',
                prefixIcon: Icon(Icons.phone_in_talk),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter emergency contact phone';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ID Document Upload
            const Text(
              'Valid ID Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ImageUploadWidget(
              bucket: 'pool-access-docs',
              onUploadComplete: (url) {
                setState(() => _idDocUrl = url.isNotEmpty ? url : null);
              },
            ),
            const SizedBox(height: 24),

            // Acknowledgements
            const Text(
              'Acknowledgements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            CheckboxListTile(
              title: const Text(
                  'I acknowledge and agree to follow all pool rules and regulations'),
              value: _acknowledgeRules,
              onChanged: (value) {
                setState(() => _acknowledgeRules = value ?? false);
              },
            ),

            CheckboxListTile(
              title: const Text(
                  'I acknowledge that I use the pool at my own risk and waive liability'),
              value: _acknowledgeLiability,
              onChanged: (value) {
                setState(() => _acknowledgeLiability = value ?? false);
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            HOAppButton(
              label: 'Submit Registration',
              onPressed: _handleSubmit,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
