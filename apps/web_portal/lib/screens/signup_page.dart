import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.inviteEmail != null) {
      _emailController.text = widget.inviteEmail!;
      _emailLocked = true;
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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = context.read<AuthRepository>();
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
    if (_signupComplete) {
      return Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_read,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Check Your Email',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a confirmation email to ${_emailController.text}. Please click the link to verify your account, then log in.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                HOAppButton(
                  label: 'Go to Login',
                  onPressed: () {
                    final path = widget.communitySlug != null &&
                            widget.inviteToken != null
                        ? '/${widget.communitySlug}/login?invite=${widget.inviteToken}'
                        : widget.inviteToken != null
                            ? '/login?invite=${widget.inviteToken}'
                            : '/login';
                    context.go(path);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/hoapp-logo.png',
                      height: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.inviteToken != null
                          ? 'Create Account to Join'
                          : 'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        suffixIcon: _emailLocked
                            ? const Icon(Icons.lock_outline, size: 18)
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
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
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    HOAppButton(
                      label: 'Sign Up',
                      onPressed: _handleSignup,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        if (widget.inviteToken != null) {
                          final path = widget.communitySlug != null
                              ? '/${widget.communitySlug}/login?invite=${widget.inviteToken}'
                              : '/login?invite=${widget.inviteToken}';
                          context.go(path);
                        } else {
                          context.go('/login');
                        }
                      },
                      child: const Text('Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Home',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
