import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  final String? inviteToken;
  final String? communitySlug;
  final String? inviteEmail;

  const SignupPage(
      {super.key, this.inviteToken, this.communitySlug, this.inviteEmail});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _emailLocked = false;
  bool _signupComplete = false;

  // Unit selection
  List<String> _availableUnits = [];
  String? _selectedUnit;
  bool _loadingUnits = false;

  @override
  void initState() {
    super.initState();
    if (widget.inviteEmail != null) {
      _emailController.text = widget.inviteEmail!;
      _emailLocked = true;
    }
    // Load available units for community signup after frame is built
    if (widget.communitySlug != null && widget.inviteToken == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAvailableUnits();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUnits() async {
    setState(() => _loadingUnits = true);
    try {
      debugPrint('Loading units for community: ${widget.communitySlug}');
      final communityRepo = context.read<CommunityRepository>();
      final community =
          await communityRepo.getCommunityBySlug(widget.communitySlug!);

      if (community != null) {
        debugPrint('Community found: ${community.name} (${community.id})');
        final client = Supabase.instance.client;

        debugPrint('Querying units table for community_id: ${community.id}');
        final units = await client
            .from('units')
            .select('unit_no')
            .eq('community_id', community.id)
            .order('unit_no');

        debugPrint('Units query response: $units');
        debugPrint('Found ${(units as List).length} units');

        if (mounted) {
          setState(() {
            _availableUnits =
                (units as List).map((u) => u['unit_no'] as String).toList();
            _loadingUnits = false;
          });

          if (_availableUnits.isEmpty) {
            debugPrint(
                'WARNING: No units found for community ${community.name}');
          }
        }
      } else {
        // Community not found
        debugPrint('ERROR: Community ${widget.communitySlug} not found');
        if (mounted) {
          setState(() => _loadingUnits = false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR loading units: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loadingUnits = false);
      }
    }
  }

  String _formatCommunityName(String slug) {
    // Convert "eleve-homes" to "Eleve Homes"
    return slug
        .split('-')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final client = Supabase.instance.client;
      // Query auth.users table to check if email exists
      // Note: This requires a database function or RPC call
      // Alternative: try to sign in and catch the error
      final response = await client.rpc('check_email_exists', params: {
        'email_address': email,
      });
      return response == true;
    } catch (e) {
      // If RPC doesn't exist, return false to allow signup attempt
      // The actual signup will catch duplicate email errors
      debugPrint('Email check failed (RPC may not exist): $e');
      return false;
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = context.read<AuthRepository>();

      // Check if email already exists
      final emailExists = await _checkEmailExists(_emailController.text.trim());
      if (emailExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'This email is already registered. Please login instead.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final metadata = <String, dynamic>{
        'full_name': _nameController.text.trim(),
      };
      // Persist invite context in user_metadata so it survives email verification
      if (widget.inviteToken != null) {
        metadata['invite_token'] = widget.inviteToken;
      }
      if (widget.communitySlug != null) {
        metadata['community_slug'] = widget.communitySlug;
      }
      // Store unit number for community signups (will be used after email confirmation)
      if (widget.communitySlug != null && _selectedUnit != null) {
        metadata['unit_number'] = _selectedUnit;
        debugPrint('Signup: Storing unit_number in metadata: $_selectedUnit');
      }

      debugPrint('Signup: Full metadata being sent: $metadata');

      final response = await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        metadata: metadata,
      );

      // full_name is stored in auth user_metadata
      // Profile row is created when invite is accepted

      if (mounted) {
        // Check if email confirmation is required
        if (response.session == null) {
          // Email confirmation required
          if (mounted) {
            setState(() => _signupComplete = true);
          }
        } else {
          // Session created immediately (email confirmation disabled)
          // Accept invite if token provided
          if (widget.inviteToken != null) {
            try {
              final communityRepo = context.read<CommunityRepository>();
              await communityRepo.acceptInvite(widget.inviteToken!);
              // Clear invite_token from metadata so it doesn't re-trigger on next login
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(data: {'invite_token': null}),
              );
              if (mounted) {
                if (widget.communitySlug != null) {
                  context.go('/${widget.communitySlug}/announcements');
                } else {
                  final communities = await communityRepo.getUserCommunities();
                  if (communities.isNotEmpty) {
                    context.go('/${communities.first.slug}/announcements');
                  } else {
                    context.go('/create-community');
                  }
                }
                return;
              }
            } catch (e) {
              print('Error accepting invite: $e');
            }
          }
          if (mounted) context.go('/create-community');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Signup failed: ${e.toString()}';

        // Provide more helpful error messages
        if (e.toString().contains('400')) {
          errorMessage =
              'Signup failed: Please check that Email authentication is enabled in your Supabase dashboard (Authentication → Providers → Email)';
        } else if (e.toString().contains('Invalid login credentials')) {
          errorMessage =
              'Invalid credentials. Please check your email and password.';
        } else if (e.toString().contains('User already registered')) {
          errorMessage =
              'This email is already registered. Please login instead.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const brand = Color(0xFF2E5C3F);

    if (_signupComplete) {
      return Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF0F7F4),
                    Color(0xFFE8F5E9),
                    Color(0xFFF5F5F0),
                  ],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 24,
                  vertical: 40,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: brand.withOpacity(0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 28 : 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: brand.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mark_email_read_rounded,
                              size: 56, color: brand),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Check Your Email',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We sent a confirmation email to ${_emailController.text}. Please click the link to verify your account, then log in.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              String path = '/login';
                              if (widget.communitySlug != null) {
                                path = '/${widget.communitySlug}/login';
                                if (widget.inviteToken != null) {
                                  path += '?invite=${widget.inviteToken}';
                                }
                              } else if (widget.inviteToken != null) {
                                path = '/login?invite=${widget.inviteToken}';
                              }
                              context.go(path);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Go to Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF0F7F4),
                  Color(0xFFE8F5E9),
                  Color(0xFFF5F5F0),
                ],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.withOpacity(0.04),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 24,
                vertical: 40,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: brand.withOpacity(0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 28 : 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/hoapp-logo.png',
                          height: isMobile ? 72 : 90,
                          errorBuilder: (context, error, stackTrace) {
                            return SizedBox(height: isMobile ? 72 : 90);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          widget.inviteToken != null
                              ? 'Create Account to Join'
                              : widget.communitySlug != null
                                  ? 'Join ${_formatCommunityName(widget.communitySlug!)}'
                                  : 'Create Account',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.communitySlug != null &&
                                  widget.inviteToken == null
                              ? 'Sign up as a resident and join your unit'
                              : 'Fill in your details to get started',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Juan Dela Cruz',
                            prefixIcon: Icon(Icons.person_outline_rounded,
                                color: Colors.grey.shade400, size: 20),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: brand, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            labelStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: Colors.grey.shade400, size: 20),
                            suffixIcon: _emailLocked
                                ? Icon(Icons.lock_outline_rounded,
                                    size: 18, color: Colors.grey.shade400)
                                : null,
                            filled: true,
                            fillColor: _emailLocked
                                ? Colors.grey.shade100
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: brand, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            labelStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          readOnly: _emailLocked,
                          enabled: !_emailLocked,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Unit selector (community signup only)
                        if (widget.communitySlug != null &&
                            widget.inviteToken == null) ...[
                          if (_loadingUnits)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: brand,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading available units...',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_availableUnits.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No units available yet. Please contact your community admin.',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: InputDecoration(
                                labelText: 'Select Your Unit',
                                prefixIcon: Icon(Icons.home_outlined,
                                    color: Colors.grey.shade400, size: 20),
                                helperText: 'Choose your unit/lot number',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: brand, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: Colors.red.shade300, width: 1),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                labelStyle: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14),
                              ),
                              items: _availableUnits.map((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedUnit = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your unit number';
                                }
                                return null;
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded,
                                color: Colors.grey.shade400, size: 20),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: brand, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            labelStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded,
                                color: Colors.grey.shade400, size: 20),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: brand, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            labelStyle: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSignup(),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // Sign up button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brand,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: brand.withOpacity(0.6),
                              disabledForegroundColor:
                                  Colors.white.withOpacity(0.8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (widget.inviteToken != null) {
                                  final path = widget.communitySlug != null
                                      ? '/${widget.communitySlug}/login?invite=${widget.inviteToken}'
                                      : '/login?invite=${widget.inviteToken}';
                                  context.go(path);
                                } else {
                                  context.go('/login');
                                }
                              },
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Back to Home',
                  color: const Color(0xFF374151),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
