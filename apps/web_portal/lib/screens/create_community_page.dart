import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  State<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends State<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _generateSlug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slugController.text = slug;
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if user is authenticated first
      final authRepo = context.read<AuthRepository>();
      final currentUser = authRepo.currentUser;

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first to create a community'),
              duration: Duration(seconds: 5),
            ),
          );
          context.go('/login');
        }
        return;
      }

      final communityRepo = context.read<CommunityRepository>();
      final result = await communityRepo.createCommunity(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
      );

      if (result['ok'] == true && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_outlined,
                    color: Color(0xFF2E7D32), size: 24),
                const SizedBox(width: 12),
                const Text('Community Created!',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your community has been created successfully.'),
                const SizedBox(height: 16),
                const Text('Portal URL:'),
                SelectableText(
                  result['portal_url'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/${result['slug']}/');
                },
                child: const Text('Go to Portal'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Creation failed: ${e.toString()}';

        // Provide more helpful error messages
        if (e.toString().contains('must be logged in')) {
          errorMessage =
              'You must be logged in to create a community. Please login again.';
          // Redirect to login after showing error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.go('/login');
          });
        } else if (e.toString().contains('401')) {
          errorMessage = 'Authentication expired. Please login again.';
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.go('/login');
          });
        } else if (e.toString().contains('409')) {
          errorMessage =
              'This community name is already taken. Please choose another.';
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
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
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
                  'Create Your Community',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Community Name',
                    hintText: 'e.g., Elevé Homes',
                    prefixIcon: Icon(Icons.home),
                  ),
                  onChanged: _generateSlug,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a community name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'URL Slug',
                    hintText: 'e.g., eleve-homes',
                    prefixIcon: Icon(Icons.link),
                    helperText: 'This will be your portal URL',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a URL slug';
                    }
                    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                      return 'Only lowercase letters, numbers, and hyphens allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                HOAppButton(
                  label: 'Create Community',
                  onPressed: _handleCreate,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
