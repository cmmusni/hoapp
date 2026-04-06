import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';

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
                Icon(Icons.check_circle_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 24),
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
                          'Create Your Community',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Set up your HOA portal in seconds',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Community name field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Community Name',
                            hintText: 'e.g., Elevé Homes',
                            prefixIcon: Icon(Icons.home_outlined,
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
                          onChanged: _generateSlug,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a community name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // URL slug field
                        TextFormField(
                          controller: _slugController,
                          decoration: InputDecoration(
                            labelText: 'URL Slug',
                            hintText: 'e.g., eleve-homes',
                            prefixIcon: Icon(Icons.link_rounded,
                                color: Colors.grey.shade400, size: 20),
                            helperText: 'This will be your portal URL',
                            helperStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
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

                        // URL preview
                        if (_slugController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: brand.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: brand.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.public_rounded,
                                    size: 16, color: brand.withOpacity(0.6)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'hoapp.net/${_slugController.text}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: brand.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Create button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleCreate,
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
                                    'Create Community',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
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
