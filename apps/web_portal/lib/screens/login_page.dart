import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  final String? communitySlug;
  final String? inviteToken;

  const LoginPage({
    super.key,
    this.communitySlug,
    this.inviteToken,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _communityName;
  String? _communityLogoUrl;
  String? _errorMessage;

  String _formatSlugAsName(String slug) {
    return slug
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String get _communityDisplayName {
    if (_communityName != null && _communityName!.trim().isNotEmpty) {
      return _communityName!;
    }
    if (widget.communitySlug != null) {
      return _formatSlugAsName(widget.communitySlug!);
    }
    return '';
  }

  String _friendlyLoginError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (raw.contains('email not confirmed') ||
        raw.contains('email not verified') ||
        raw.contains('not confirmed')) {
      return 'Please verify your email first. Check your inbox for the confirmation link.';
    }

    if (raw.contains('too many requests') || raw.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }

    if (raw.contains('unauthorized') ||
        raw.contains('invalid jwt') ||
        raw.contains('missing authorization header')) {
      return 'Your session could not be verified. Please try logging in again.';
    }

    if (raw.contains('network') ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection')) {
      return 'Unable to connect right now. Please check your internet and try again.';
    }

    return 'Login failed. Please try again.';
  }

  String _friendlyPostLoginError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('unauthorized') ||
        raw.contains('invalid jwt') ||
        raw.contains('missing authorization header')) {
      return 'You are signed in, but we could not finish invitation setup. Please refresh and try again.';
    }

    return 'You are signed in, but some setup steps did not complete. You can continue and try again later.';
  }

  @override
  void initState() {
    super.initState();
    if (widget.communitySlug != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCommunityName();
      });
    }
  }

  Future<void> _loadCommunityName() async {
    try {
      final communityRepo = context.read<CommunityRepository>();
      final community =
          await communityRepo.getCommunityBySlug(widget.communitySlug!);
      if (mounted && community != null) {
        setState(() {
          _communityName = community.name;
          _communityLogoUrl = community.logoUrl;
        });
      }
    } catch (e) {
      print('Error loading community: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // Prevent multiple simultaneous calls

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      try {
        await authRepo.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } catch (e) {
        if (mounted) {
          final message = _friendlyLoginError(e);
          setState(() => _errorMessage = message);
        }
        return;
      }

      // Tell the browser the autofill context is done so it offers to save credentials
      TextInput.finishAutofillContext();

      // Handle invite acceptance and unit assignment from metadata
      if (mounted) {
        final communityRepo = context.read<CommunityRepository>();
        final authRepo2 = context.read<AuthRepository>();
        final userMeta = authRepo2.currentUser?.userMetadata;
        final metaInviteToken = userMeta?['invite_token'] as String?;
        final metaCommunitySlug = userMeta?['community_slug'] as String?;
        final metaUnitNumber = userMeta?['unit_number'] as String?;

        debugPrint(
            'Login: Processing metadata - communitySlug=$metaCommunitySlug, unitNumber=$metaUnitNumber, inviteToken=$metaInviteToken');

        // Determine which invite token to use
        final effectiveToken = widget.inviteToken ?? metaInviteToken;

        // Only accept invite if there's an explicit invite token
        // Don't auto-accept pending invites for regular logins
        if (effectiveToken != null) {
          try {
            await communityRepo.acceptInvite(effectiveToken);
            // Clear invite_token from metadata so it doesn't re-trigger on next login
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'invite_token': null}),
            );
          } catch (e) {
            debugPrint('Post-login invite setup failed: $e');
            // Only show error for explicit invite tokens, not metadata ones
            if (widget.inviteToken != null && mounted) {
              final message = _friendlyPostLoginError(e);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }

        // Handle pending unit assignment from signup metadata
        // This handles cases where user signed up via /community/signup but experienced
        // PKCE timeout during email verification, then manually logged in
        if (metaCommunitySlug != null &&
            metaUnitNumber != null &&
            metaUnitNumber.isNotEmpty) {
          try {
            debugPrint(
                'Login: Processing pending unit assignment for $metaCommunitySlug, unit $metaUnitNumber');

            final community =
                await communityRepo.getCommunityBySlug(metaCommunitySlug);

            if (community != null) {
              final client = Supabase.instance.client;
              final userId = authRepo2.currentUser!.id;

              // Check if user already has household_members record
              // If they already have a unit assigned, skip this
              final existingHousehold = await client
                  .from('household_members')
                  .select('id')
                  .eq('user_id', userId)
                  .eq('community_id', community.id)
                  .maybeSingle();

              if (existingHousehold == null) {
                // Find the unit by unit_no
                final unitRow = await client
                    .from('units')
                    .select('id')
                    .eq('community_id', community.id)
                    .eq('unit_no', metaUnitNumber)
                    .maybeSingle();

                if (unitRow != null) {
                  final unitId = unitRow['id'];
                  debugPrint(
                      'Login: Found unit $unitId for unit_no $metaUnitNumber');

                  // Check if unit already has a primary member
                  final existingPrimary = await client
                      .from('household_members')
                      .select('id')
                      .eq('unit_id', unitId)
                      .eq('member_role', 'primary')
                      .maybeSingle();

                  // Determine member role: first person is primary, others are member
                  final memberRole =
                      existingPrimary == null ? 'primary' : 'member';

                  // Add user as household member
                  await client.from('household_members').insert({
                    'unit_id': unitId,
                    'user_id': userId,
                    'community_id': community.id,
                    'member_role': memberRole,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  debugPrint(
                      'Login: Created household_members record with role: $memberRole');

                  // Check if user already has a role
                  final existingRole = await client
                      .from('user_roles')
                      .select('id')
                      .eq('user_id', userId)
                      .eq('community_id', community.id)
                      .maybeSingle();

                  if (existingRole == null) {
                    // Create user role as resident
                    await client.from('user_roles').insert({
                      'user_id': userId,
                      'community_id': community.id,
                      'role': 'resident',
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    debugPrint('Login: Created user_roles record');
                  }

                  // Clear metadata after successful assignment
                  await client.auth.updateUser(
                    UserAttributes(data: {
                      'community_slug': null,
                      'unit_number': null,
                    }),
                  );

                  debugPrint(
                      'Login: Successfully assigned user to unit $metaUnitNumber as $memberRole and cleared metadata');
                } else {
                  debugPrint(
                      'Login: Unit $metaUnitNumber not found in community');

                  // Clear invalid metadata
                  await client.auth.updateUser(
                    UserAttributes(data: {
                      'community_slug': null,
                      'unit_number': null,
                    }),
                  );
                }
              } else {
                debugPrint(
                    'Login: User already has household assignment, clearing metadata');

                // Clear metadata since user already has assignment
                await client.auth.updateUser(
                  UserAttributes(data: {
                    'community_slug': null,
                    'unit_number': null,
                  }),
                );
              }
            } else {
              debugPrint('Login: Community $metaCommunitySlug not found');
            }
          } catch (e, stackTrace) {
            debugPrint('Login: Unit assignment failed: $e');
            debugPrint('Stack trace: $stackTrace');
            // Don't block login if unit assignment fails
          }
        }

        // Determine community slug for navigation
        final effectiveSlug = widget.communitySlug ?? metaCommunitySlug;

        // Navigate based on context
        if (mounted) {
          if (effectiveSlug != null && effectiveSlug.isNotEmpty) {
            context.go('/$effectiveSlug/announcements');
          } else {
            // Look up user's communities
            try {
              final communities = await communityRepo.getUserCommunities();

              if (communities.isNotEmpty) {
                final firstSlug = communities.first.slug;
                if (firstSlug.isNotEmpty) {
                  context.go('/$firstSlug/announcements');
                } else {
                  context.go('/create-community');
                }
              } else {
                context.go('/create-community');
              }
            } catch (e) {
              print('Error loading communities: $e');
              context.go('/create-community');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Unexpected login flow error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        var sending = false;
        var sent = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (sent) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_read_outlined,
                          size: 48, color: Colors.green.shade600),
                    ),
                    const SizedBox(height: 16),
                    const Text('Reset Link Sent!',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your email for a password reset link. It may take a few minutes to arrive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset,
                      color: Theme.of(context).colorScheme.primary, size: 28),
                  SizedBox(width: 8),
                  Text('Reset Password',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (formKey.currentState!.validate() && !sending) {
                          // Trigger send
                        }
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            sending = true;
                            error = null;
                          });
                          try {
                            final authRepo = context.read<AuthRepository>();
                            await authRepo.resetPassword(emailCtrl.text.trim());
                            setDialogState(() => sent = true);
                          } catch (e) {
                            setDialogState(() {
                              error =
                                  'Failed to send reset email. Please try again.';
                              sending = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const brand = Color(0xFF2E5C3F);

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
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          _communityLogoUrl != null
                              ? Image.network(
                                  _communityLogoUrl!,
                                  height: isMobile ? 72 : 90,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/hoapp-logo.png',
                                      height: isMobile ? 72 : 90,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return SizedBox(
                                            height: isMobile ? 72 : 90);
                                      },
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/hoapp-logo.png',
                                  height: isMobile ? 80 : 100,
                                  errorBuilder: (context, error, stackTrace) {
                                    return SizedBox(
                                        height: isMobile ? 80 : 100);
                                  },
                                ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            widget.communitySlug != null
                                ? 'Welcome back'
                                : 'Welcome back',
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.communitySlug != null
                                ? 'Sign in to $_communityDisplayName'
                                : 'Sign in to your account',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Invite banner
                          if (widget.inviteToken != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    brand.withOpacity(0.08),
                                    brand.withOpacity(0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: brand.withOpacity(0.15)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: brand.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.mail_outline_rounded,
                                        color: brand,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'You\'ve been invited${widget.communitySlug != null ? ' to $_communityDisplayName' : ''}! Sign in or create an account.',
                                      style: TextStyle(
                                        color: brand.withOpacity(0.85),
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.red.shade200, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: Colors.red.shade600, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined,
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
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

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
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: brand,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
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
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Create account / Sign up link
                          if (widget.inviteToken != null)
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        final path = widget.communitySlug !=
                                                null
                                            ? '/${widget.communitySlug}/signup?invite=${widget.inviteToken}'
                                            : '/signup?invite=${widget.inviteToken}';
                                        context.go(path);
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: brand,
                                  side: const BorderSide(
                                      color: brand, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => context.go('/signup'),
                                  child: const Text(
                                    'Sign up',
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
                        ],
                      ),
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
