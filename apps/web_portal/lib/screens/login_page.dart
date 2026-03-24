import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

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

    setState(() => _isLoading = true);

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
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Handle invite acceptance
      if (mounted) {
        final communityRepo = context.read<CommunityRepository>();
        final authRepo2 = context.read<AuthRepository>();
        final userMeta = authRepo2.currentUser?.userMetadata;
        final metaInviteToken = userMeta?['invite_token'] as String?;
        final metaCommunitySlug = userMeta?['community_slug'] as String?;

        // Determine which invite token to use
        final effectiveToken = widget.inviteToken ?? metaInviteToken;

        if (effectiveToken != null) {
          try {
            await communityRepo.acceptInvite(effectiveToken);
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
        } else {
          // No token at all — silently try to claim any pending invites
          try {
            await communityRepo.acceptPendingInvites();
          } catch (e) {
            debugPrint('Auto-accept pending invites failed (non-blocking): $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(height: 120);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  widget.communitySlug != null
                      ? 'Login to $_communityDisplayName'
                      : 'Login',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                if (widget.inviteToken != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You\'ve been invited${widget.communitySlug != null ? ' to $_communityDisplayName' : ''}! Sign in or create an account to accept.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                HOAppButton(
                  label: 'Login',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                if (widget.inviteToken != null)
                  HOAppButton(
                    label: 'Create Account',
                    onPressed: _isLoading
                        ? null
                        : () {
                            final path = widget.communitySlug != null
                                ? '/${widget.communitySlug}/signup?invite=${widget.inviteToken}'
                                : '/signup?invite=${widget.inviteToken}';
                            context.go(path);
                          },
                    isOutlined: true,
                  )
                else
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/signup'),
                    child: const Text('Don\'t have an account? Sign up'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
