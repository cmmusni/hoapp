import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

class LoginScreen extends StatefulWidget {
  final String? inviteToken;

  const LoginScreen({
    super.key,
    this.inviteToken,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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
      return 'You are signed in, but we could not finish invitation setup. Please try again later.';
    }

    return 'You are signed in, but some setup steps did not complete. You can continue and try again later.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

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

      // Handle invite acceptance if token provided
      if (widget.inviteToken != null && mounted) {
        try {
          final communityRepo = context.read<CommunityRepository>();
          await communityRepo.acceptInvite(widget.inviteToken!);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invite accepted successfully!'),
                backgroundColor: Color.fromRGBO(39, 99, 67, 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            final message = _friendlyPostLoginError(e);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/splash');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    AppConfig.isCommunityBuild
                        ? 'assets/flavors/elevehomes/icon.png'
                        : 'assets/images/hoapp-logo.png',
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Login',
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
                    const SizedBox(height: 16),
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
                              'You\'ve been invited! Sign in to accept.',
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
                  ],
                  const SizedBox(height: 24),
                  HOAppButton(
                    label: 'Login',
                    onPressed: _isLoading ? null : _handleLogin,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
