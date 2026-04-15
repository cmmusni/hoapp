import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/eyedropper.dart' as eyedropper;

/// Shared settings screen — adaptive for web and mobile.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<Community?>? _communityFuture;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  void _loadCommunity() {
    final appState = context.read<AppState>();
    final repo = context.read<CommunityRepository>();
    if (appState.activeCommunityId != null) {
      setState(() {
        _communityFuture = repo.getCommunityById(appState.activeCommunityId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;

    return Scaffold(
      body: FutureBuilder<Community?>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final community = snapshot.data;
          if (community == null) {
            return const Center(child: Text('Community not found'));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadCommunity(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Community info
                Text('Community Information',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _InfoRow(label: 'Name', value: community.name),
                      const Divider(),
                      _InfoRow(label: 'Slug', value: community.slug),
                      if (community.address != null) ...[
                        const Divider(),
                        _InfoRow(label: 'Address', value: community.address!),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Branding
                Row(children: [
                  Text('Branding',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: () => _showBrandingDialog(context, community),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                ]),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        const Text('Primary Color:'),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(int.parse(community.primaryColor
                                .replaceFirst('#', '0xff'))),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(community.primaryColor),
                      ]),
                      const Divider(height: 24),
                      Row(children: [
                        const Text('Community Logo:'),
                        const Spacer(),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () => _uploadLogo(context, community),
                            icon: const Icon(Icons.upload, size: 18),
                            label: Text(community.logoUrl != null
                                ? 'Change'
                                : 'Upload'),
                          ),
                      ]),
                      if (community.logoUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            community.logoUrl!,
                            height: 60,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No logo uploaded',
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Unit Types (admin only)
                if (isAdmin) ...[
                  _UnitTypesSection(communityId: community.id),
                  const SizedBox(height: 24),
                ],

                // Plan & Subscription (admin only)
                if (isAdmin) ...[
                  _PlanSection(
                    community: community,
                    onPlanUpdated: _loadCommunity,
                  ),
                  const SizedBox(height: 24),
                ],

                // Payment Notification Recipients (admin only)
                if (isAdmin) ...[
                  _PaymentNotificationSection(
                    community: community,
                    onUpdated: _loadCommunity,
                  ),
                  const SizedBox(height: 24),
                ],

                // Sign out
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSignOut(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Preset color swatches for quick selection
  static const List<Color> _presetColors = [
    Color(0xff215E3F), // Forest green (default)
    Color(0xff1565C0), // Blue
    Color(0xff6A1B9A), // Purple
    Color(0xffC62828), // Red
    Color(0xffE65100), // Deep orange
    Color(0xff2E7D32), // Green
    Color(0xff00838F), // Teal
    Color(0xff4527A0), // Deep purple
    Color(0xff283593), // Indigo
    Color(0xff558B2F), // Light green
    Color(0xff795548), // Brown
    Color(0xff37474F), // Blue grey
    Color(0xffF57F17), // Amber
    Color(0xffAD1457), // Pink
    Color(0xff00695C), // Dark teal
    Color(0xff1B5E20), // Dark green
  ];

  void _showBrandingDialog(BuildContext context, Community community) {
    Color pickerColor =
        Color(int.parse(community.primaryColor.replaceFirst('#', '0xff')));
    final hexController = TextEditingController(
      text: community.primaryColor.replaceFirst('#', '').toUpperCase(),
    );
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void updateFromHex(String hex) {
            hex = hex.replaceFirst('#', '').toUpperCase();
            if (hex.length == 6 && RegExp(r'^[0-9A-F]{6}$').hasMatch(hex)) {
              setDialogState(() {
                pickerColor = Color(int.parse('0xff$hex'));
              });
            }
          }

          void updateFromPicker(Color c) {
            setDialogState(() {
              pickerColor = c;
              hexController.text =
                  c.toARGB32().toRadixString(16).substring(2).toUpperCase();
            });
          }

          final theme = Theme.of(ctx);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: pickerColor.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pickerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.palette_rounded,
                        color: pickerColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Edit Branding',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pickerColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: pickerColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Live Preview',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '#${hexController.text}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Hex input + eyedropper
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: pickerColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              prefixText: '#',
                              labelText: 'Hex Color',
                              hintText: '2E7D32',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: pickerColor, width: 1.5),
                              ),
                              counterText: '',
                            ),
                            maxLength: 6,
                            onChanged: updateFromHex,
                          ),
                        ),
                        if (eyedropper.isEyeDropperAvailable) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Pick color from screen',
                            child: Material(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final color =
                                      await eyedropper.pickColorFromScreen();
                                  if (color != null) {
                                    updateFromPicker(color);
                                  }
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.colorize_rounded,
                                      color: Colors.grey.shade700, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Preset colors
                    Text('Quick Select',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((color) {
                        final isSelected =
                            pickerColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => updateFromPicker(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text('Custom Color',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: updateFromPicker,
                        enableAlpha: false,
                        pickerAreaHeightPercent: 0.5,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final repo = context.read<CommunityRepository>();
                          final appState = context.read<AppState>();
                          final hex =
                              '#${pickerColor.toARGB32().toRadixString(16).substring(2)}';
                          final existing =
                              appState.activeCommunity?.settings ?? {};
                          final brand =
                              (existing['brand'] as Map<String, dynamic>?) ??
                                  {};
                          final updatedSettings = {
                            ...existing,
                            'brand': {...brand, 'primary': hex},
                          };
                          await repo.updateCommunitySettings(
                            communityId: appState.activeCommunityId!,
                            settings: updatedSettings,
                          );
                          if (mounted) {
                            final refreshed = await repo.getCommunityById(
                              appState.activeCommunityId!,
                            );
                            if (refreshed != null) {
                              appState.setActiveCommunityData(refreshed);
                            }
                            Navigator.of(ctx).pop();
                            _loadCommunity();
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Saving...' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pickerColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadLogo(BuildContext context, Community community) async {
    try {
      final storageService = StorageService(Supabase.instance.client);
      final file = await storageService.pickImage();
      if (file == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Uploading logo...')));

      final url = await storageService.uploadImage(
        bucket: 'community-logos',
        file: file,
        folder: community.id,
      );

      if (!mounted) return;
      final repo = context.read<CommunityRepository>();
      final appState = context.read<AppState>();
      final existing = appState.activeCommunity?.settings ?? {};
      final updatedSettings = {
        ...existing,
        'logo_url': url,
      };
      await repo.updateCommunitySettings(
        communityId: community.id,
        settings: updatedSettings,
      );

      final refreshed = await repo.getCommunityById(community.id);
      if (refreshed != null && mounted) {
        appState.setActiveCommunityData(refreshed);
        _loadCommunity();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Sign Out',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.red.shade700)),
            ],
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out? You will need to log in again to access your community.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon:
                const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}

// ─── Support Widgets ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ]),
    );
  }
}

// ─── Unit Types Section ──────────────────────────────────────────────────────

class _UnitTypesSection extends StatefulWidget {
  final String communityId;
  const _UnitTypesSection({required this.communityId});

  @override
  State<_UnitTypesSection> createState() => _UnitTypesSectionState();
}

class _UnitTypesSectionState extends State<_UnitTypesSection> {
  Future<List<UnitType>>? _unitTypesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<HouseholdRepository>();
    setState(() {
      _unitTypesFuture = repo.getUnitTypes(widget.communityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Unit Types', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddDialog(),
          ),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<List<UnitType>>(
          future: _unitTypesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final types = snapshot.data ?? [];
            if (types.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No unit types defined',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              );
            }
            return Column(
              children: types
                  .map((t) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: t.description != null
                              ? Text(t.description!)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditDialog(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () async {
                                  final repo =
                                      context.read<HouseholdRepository>();
                                  await repo.deleteUnitType(t.id);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_home_work_rounded,
                      color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Add Unit Type',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.label_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final repo = context.read<HouseholdRepository>();
                  await repo.createUnitType(
                    communityId: widget.communityId,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: Icon(Icons.add_circle_outline, color: primary),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(UnitType unitType) {
    final nameCtrl = TextEditingController(text: unitType.name);
    final descCtrl = TextEditingController(text: unitType.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Edit Unit Type',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.label_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final repo = context.read<HouseholdRepository>();
                  await repo.updateUnitType(
                    id: unitType.id,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Plan & Subscription Section ───────────────────────────

class _PlanSection extends StatefulWidget {
  final Community community;
  final VoidCallback onPlanUpdated;

  const _PlanSection({
    required this.community,
    required this.onPlanUpdated,
  });

  @override
  State<_PlanSection> createState() => _PlanSectionState();
}

class _PlanSectionState extends State<_PlanSection> {
  String? _proLabel;
  String? _proPeriod;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final row = await Supabase.instance.client
          .from('plan_pricing')
          .select('label, period')
          .eq('plan', 'professional')
          .single();
      if (mounted) {
        setState(() {
          _proLabel = row['label'] as String?;
          _proPeriod = row['period'] as String?;
        });
      }
    } catch (_) {}
  }

  String get _priceDisplay =>
      '${_proLabel ?? '₱2,999'}${_proPeriod ?? '/month'}';

  Community get community => widget.community;

  String get _planLabel {
    switch (community.plan) {
      case 'professional':
        return 'Professional';
      case 'enterprise':
        return 'Enterprise';
      default:
        return 'Starter';
    }
  }

  Color _planColor(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (community.plan) {
      case 'professional':
        return primary;
      case 'enterprise':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData get _planIcon {
    switch (community.plan) {
      case 'professional':
        return Icons.workspace_premium;
      case 'enterprise':
        return Icons.diamond_outlined;
      default:
        return Icons.rocket_launch_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStarter = community.plan == 'starter';
    final planColor = _planColor(context);
    final expiresAt = community.planExpiresAt;
    final isExpiringSoon = community.isPlanExpiringSoon;
    final isExpired = community.isPlanExpired;
    final daysLeft = (community.daysUntilExpiry ?? 0) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan & Subscription',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Current plan display
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: planColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_planIcon, size: 28, color: planColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _planLabel,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: planColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: planColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: planColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isStarter
                                ? 'Free plan — up to 50 units'
                                : community.plan == 'professional'
                                    ? '$_priceDisplay — up to 300 units'
                                    : 'Custom pricing — unlimited units',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          // Show expiry date for paid plans
                          if (!isStarter && expiresAt != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isExpired
                                      ? Icons.error_outline
                                      : isExpiringSoon
                                          ? Icons.warning_amber_rounded
                                          : Icons.schedule,
                                  size: 14,
                                  color: isExpired
                                      ? Colors.red
                                      : isExpiringSoon
                                          ? Colors.orange
                                          : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExpired
                                      ? 'Expired — renew to keep features'
                                      : isExpiringSoon
                                          ? 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'} — renew now'
                                          : 'Renews ${_formatDate(expiresAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: (isExpired || isExpiringSoon)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isExpired
                                        ? Colors.red
                                        : isExpiringSoon
                                            ? Colors.orange.shade800
                                            : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Renewal banner for expiring/expired paid plans
                if (!isStarter && (isExpiringSoon || isExpired)) ...[
                  const Divider(height: 28),
                  _RenewalBanner(
                    communityId: community.id,
                    onRenewed: widget.onPlanUpdated,
                    priceDisplay: _priceDisplay,
                    isExpired: isExpired,
                  ),
                ],

                // Upgrade option for starter plans
                if (isStarter) ...[
                  const Divider(height: 28),
                  _UpgradeBanner(
                    communityId: community.id,
                    onUpgraded: widget.onPlanUpdated,
                    priceDisplay: _priceDisplay,
                  ),
                ],

                // Cancel subscription for paid plans (not if already expired)
                if (!isStarter && !isExpired) ...[
                  const Divider(height: 28),
                  _CancelSubscriptionBanner(
                    communityId: community.id,
                    planLabel: _planLabel,
                    onCancelled: widget.onPlanUpdated,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _RenewalBanner extends StatefulWidget {
  final String communityId;
  final VoidCallback onRenewed;
  final String priceDisplay;
  final bool isExpired;

  const _RenewalBanner({
    required this.communityId,
    required this.onRenewed,
    required this.priceDisplay,
    required this.isExpired,
  });

  @override
  State<_RenewalBanner> createState() => _RenewalBannerState();
}

class _RenewalBannerState extends State<_RenewalBanner> {
  bool _renewing = false;

  Future<void> _handleRenew() async {
    setState(() => _renewing = true);
    try {
      final supabase = Supabase.instance.client;
      final token = supabase.auth.currentSession?.accessToken;
      final response = await supabase.functions.invoke(
        'create_upgrade_checkout',
        body: {'community_id': widget.communityId},
        headers: {if (token != null) 'x-user-token': token},
      );

      final data = response.data is String
          ? jsonDecode(response.data) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final checkoutUrl = data['checkout_url'] as String?;
      if (checkoutUrl == null) {
        throw Exception(data['error'] ?? 'Failed to create checkout session');
      }

      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open payment page');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment page opened. Your plan will be renewed once payment is confirmed.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Renewal failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isExpired ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.05),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            widget.isExpired ? Icons.error_outline : Icons.autorenew,
            color: color.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isExpired
                      ? 'Plan Expired — Renew Now'
                      : 'Plan Expiring Soon',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isExpired
                      ? 'Renew for ${widget.priceDisplay} to restore premium features.'
                      : 'Renew for ${widget.priceDisplay} to keep your premium features.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _renewing ? null : _handleRenew,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _renewing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Renew',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CancelSubscriptionBanner extends StatefulWidget {
  final String communityId;
  final String planLabel;
  final VoidCallback onCancelled;

  const _CancelSubscriptionBanner({
    required this.communityId,
    required this.planLabel,
    required this.onCancelled,
  });

  @override
  State<_CancelSubscriptionBanner> createState() =>
      _CancelSubscriptionBannerState();
}

class _CancelSubscriptionBannerState extends State<_CancelSubscriptionBanner> {
  bool _cancelling = false;

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cancel_outlined,
                      color: Colors.red.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Cancel Subscription',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel your ${widget.planLabel} plan?',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'You will lose access to:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              _CancelFeatureRow(text: 'Billing & Payments'),
              _CancelFeatureRow(text: 'Amenity Reservations'),
              _CancelFeatureRow(text: 'Pool Access Management'),
              _CancelFeatureRow(text: 'Security Passes & QR'),
              _CancelFeatureRow(text: 'Mobile App Access'),
              _CancelFeatureRow(text: 'Priority Support'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your community will be downgraded to the Starter plan immediately.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Keep Plan'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.cancel_outlined,
                  size: 18, color: Colors.white),
              label: const Text('Cancel Subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final repo = context.read<CommunityRepository>();
      await repo.updateCommunityPlan(
        communityId: widget.communityId,
        plan: 'starter',
      );

      if (mounted) {
        final appState = context.read<AppState>();
        final refreshed = await repo.getCommunityById(widget.communityId);
        if (refreshed != null && mounted) {
          appState.setActiveCommunityData(refreshed);
        }
        widget.onCancelled();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Subscription cancelled. Your community is now on the Starter plan.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cancellation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.03),
            Colors.red.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel Subscription',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Downgrade to the free Starter plan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _cancelling ? null : _confirmCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: Colors.red.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _cancelling
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red.shade600),
                  )
                : Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}

class _CancelFeatureRow extends StatelessWidget {
  final String text;
  const _CancelFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.remove_circle_outline,
              color: Colors.red.shade400, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatefulWidget {
  final String communityId;
  final VoidCallback onUpgraded;
  final String priceDisplay;

  const _UpgradeBanner({
    required this.communityId,
    required this.onUpgraded,
    required this.priceDisplay,
  });

  @override
  State<_UpgradeBanner> createState() => _UpgradeBannerState();
}

class _UpgradeBannerState extends State<_UpgradeBanner> {
  bool _upgrading = false;

  Future<void> _confirmUpgrade() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.workspace_premium, color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Upgrade to Professional'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock all premium features for your community:',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              _UpgradeFeatureRow(text: 'Up to 300 units', color: primary),
              _UpgradeFeatureRow(text: 'Billing & Payments', color: primary),
              _UpgradeFeatureRow(text: 'Amenity Reservations', color: primary),
              _UpgradeFeatureRow(
                  text: 'Pool Access Management', color: primary),
              _UpgradeFeatureRow(text: 'Security Passes & QR', color: primary),
              _UpgradeFeatureRow(text: 'Mobile App Access', color: primary),
              _UpgradeFeatureRow(text: 'Priority Support', color: primary),
              const SizedBox(height: 16),
              Text(
                widget.priceDisplay,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _upgrading = true);
    try {
      final supabase = Supabase.instance.client;
      final token = supabase.auth.currentSession?.accessToken;
      final response = await supabase.functions.invoke(
        'create_upgrade_checkout',
        body: {'community_id': widget.communityId},
        headers: {if (token != null) 'x-user-token': token},
      );

      final data = response.data is String
          ? jsonDecode(response.data) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final checkoutUrl = data['checkout_url'] as String?;
      if (checkoutUrl == null) {
        throw Exception(data['error'] ?? 'Failed to create checkout session');
      }

      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open payment page');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment page opened. Your plan will be upgraded once payment is confirmed.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upgrade failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.05),
            primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade to Professional',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlock billing, amenities, pool access, security passes & more.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _upgrading ? null : _confirmUpgrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _upgrading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Upgrade',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _UpgradeFeatureRow extends StatelessWidget {
  final String text;
  final Color? color;
  const _UpgradeFeatureRow({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: c, size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

// ─── Payment Notification Recipients ──────────────────────────────────────

class _PaymentNotificationSection extends StatefulWidget {
  final Community community;
  final VoidCallback onUpdated;

  const _PaymentNotificationSection({
    required this.community,
    required this.onUpdated,
  });

  @override
  State<_PaymentNotificationSection> createState() =>
      _PaymentNotificationSectionState();
}

class _PaymentNotificationSectionState
    extends State<_PaymentNotificationSection> {
  List<_AdminInfo> _admins = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    final repo = context.read<CommunityRepository>();
    final client = SupabaseClientManager.instance;
    final communityId = widget.community.id;

    try {
      // Get all community user roles
      final roles = await repo.getCommunityUserRoles(communityId);
      final adminRoles =
          roles.where((r) => r.role == Role.communityAdmin).toList();

      // Get emails & names via RPC
      final emailMap = <String, _AdminInfo>{};
      try {
        final result = await client.rpc('get_community_user_emails', params: {
          'p_community_id': communityId,
        });
        for (final row in (result as List)) {
          final uid = row['user_id'] as String;
          emailMap[uid] = _AdminInfo(
            userId: uid,
            name: (row['display_name'] as String?) ?? '',
            email: (row['email'] as String?) ?? '',
          );
        }
      } catch (_) {}

      final adminList = adminRoles.map((r) {
        final info = emailMap[r.userId];
        return _AdminInfo(
          userId: r.userId,
          name: info?.name ?? 'Unknown',
          email: info?.email ?? '',
        );
      }).toList();

      // Pre-select from saved settings
      final savedIds = widget.community.paymentNotificationAdminIds;

      if (mounted) {
        setState(() {
          _admins = adminList;
          _selectedIds = savedIds.isEmpty
              ? {} // empty means "all admins" (default behavior)
              : savedIds.toSet();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = context.read<CommunityRepository>();
      final currentSettings =
          Map<String, dynamic>.from(widget.community.settings ?? {});

      // Empty list = notify all admins (default)
      currentSettings['payment_notification_admin_ids'] =
          _selectedIds.toList();

      await repo.updateCommunitySettings(
        communityId: widget.community.id,
        settings: currentSettings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment notification settings saved')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Notifications', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Choose which community admins receive email notifications when a payment is submitted.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _admins.isEmpty
                    ? const Text('No community admins found.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._admins.map((admin) {
                            final isSelected =
                                _selectedIds.contains(admin.userId);
                            final allSelected = _selectedIds.isEmpty;
                            return CheckboxListTile(
                              value: allSelected || isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (_selectedIds.isEmpty) {
                                    // Switching from "all" to individual:
                                    // populate with all, then toggle this one
                                    _selectedIds = _admins
                                        .map((a) => a.userId)
                                        .toSet();
                                  }
                                  if (checked == true) {
                                    _selectedIds.add(admin.userId);
                                  } else {
                                    _selectedIds.remove(admin.userId);
                                  }
                                  // If all are selected, clear to mean "all"
                                  if (_selectedIds.length ==
                                      _admins.length) {
                                    _selectedIds.clear();
                                  }
                                });
                              },
                              title: Text(
                                admin.name.isNotEmpty
                                    ? admin.name
                                    : 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: admin.email.isNotEmpty
                                  ? Text(admin.email,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]))
                                  : null,
                              secondary: CircleAvatar(
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  admin.name.isNotEmpty
                                      ? admin.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              controlAffinity:
                                  ListTileControlAffinity.trailing,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                          const SizedBox(height: 8),
                          Text(
                            _selectedIds.isEmpty
                                ? 'All community admins will be notified.'
                                : '${_selectedIds.length} of ${_admins.length} admin(s) will be notified.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _AdminInfo {
  final String userId;
  final String name;
  final String email;

  const _AdminInfo({
    required this.userId,
    required this.name,
    required this.email,
  });
}
