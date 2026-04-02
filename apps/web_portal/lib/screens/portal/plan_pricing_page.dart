import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform admin page to manage plan pricing.
class PlanPricingPage extends StatefulWidget {
  const PlanPricingPage({super.key});

  @override
  State<PlanPricingPage> createState() => _PlanPricingPageState();
}

class _PlanPricingPageState extends State<PlanPricingPage> {
  bool _loading = true;
  bool _saving = false;
  List<_PlanRow> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final rows =
          await sb.from('plan_pricing').select().order('plan', ascending: true);
      if (mounted) {
        setState(() {
          _plans = (rows as List)
              .map((r) => _PlanRow.fromJson(r as Map<String, dynamic>))
              .toList();
          // Sort: starter, professional, enterprise
          _plans.sort((a, b) => _planOrder(a.plan) - _planOrder(b.plan));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load pricing: $e')));
      }
    }
  }

  int _planOrder(String plan) {
    switch (plan) {
      case 'starter':
        return 0;
      case 'professional':
        return 1;
      case 'enterprise':
        return 2;
      default:
        return 3;
    }
  }

  Future<void> _save(_PlanRow plan) async {
    setState(() => _saving = true);
    try {
      final sb = Supabase.instance.client;
      await sb.from('plan_pricing').update({
        'price_centavos': plan.priceCentavos,
        'original_price_centavos': plan.originalPriceCentavos,
        'label': plan.label,
        'period': plan.period,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('plan', plan.plan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_planDisplayName(plan.plan)} pricing updated successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _planDisplayName(String plan) {
    switch (plan) {
      case 'starter':
        return 'Starter';
      case 'professional':
        return 'Professional';
      case 'enterprise':
        return 'Enterprise';
      default:
        return plan;
    }
  }

  IconData _planIcon(String plan) {
    switch (plan) {
      case 'starter':
        return Icons.rocket_launch_outlined;
      case 'professional':
        return Icons.workspace_premium;
      case 'enterprise':
        return Icons.business;
      default:
        return Icons.payments;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.payments_outlined, color: primary, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Plan Pricing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure the pricing displayed on the marketing page and used for payment checkout.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),

          // Plan cards
          ..._plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PlanPricingCard(
                  plan: plan,
                  displayName: _planDisplayName(plan.plan),
                  icon: _planIcon(plan.plan),
                  saving: _saving,
                  onSave: (updated) => _save(updated),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Data Model ────────────────────────────────────────────

class _PlanRow {
  final String plan;
  int priceCentavos;
  int? originalPriceCentavos;
  String label;
  String period;

  _PlanRow({
    required this.plan,
    required this.priceCentavos,
    this.originalPriceCentavos,
    required this.label,
    required this.period,
  });

  factory _PlanRow.fromJson(Map<String, dynamic> json) {
    return _PlanRow(
      plan: json['plan'] as String,
      priceCentavos: json['price_centavos'] as int? ?? 0,
      originalPriceCentavos: json['original_price_centavos'] as int?,
      label: json['label'] as String? ?? '',
      period: json['period'] as String? ?? '',
    );
  }

  _PlanRow copy() => _PlanRow(
        plan: plan,
        priceCentavos: priceCentavos,
        originalPriceCentavos: originalPriceCentavos,
        label: label,
        period: period,
      );
}

// ─── Plan Card Widget ──────────────────────────────────────

class _PlanPricingCard extends StatefulWidget {
  final _PlanRow plan;
  final String displayName;
  final IconData icon;
  final bool saving;
  final ValueChanged<_PlanRow> onSave;

  const _PlanPricingCard({
    required this.plan,
    required this.displayName,
    required this.icon,
    required this.saving,
    required this.onSave,
  });

  @override
  State<_PlanPricingCard> createState() => _PlanPricingCardState();
}

class _PlanPricingCardState extends State<_PlanPricingCard> {
  late TextEditingController _labelCtrl;
  late TextEditingController _periodCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _originalPriceCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _labelCtrl = TextEditingController(text: p.label);
    _periodCtrl = TextEditingController(text: p.period);
    _priceCtrl =
        TextEditingController(text: (p.priceCentavos / 100).toStringAsFixed(2));
    _originalPriceCtrl = TextEditingController(
        text: p.originalPriceCentavos != null
            ? (p.originalPriceCentavos! / 100).toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _periodCtrl.dispose();
    _priceCtrl.dispose();
    _originalPriceCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _handleSave() {
    final price = (double.tryParse(_priceCtrl.text) ?? 0) * 100;
    final origText = _originalPriceCtrl.text.trim();
    final origPrice = origText.isNotEmpty
        ? ((double.tryParse(origText) ?? 0) * 100).round()
        : null;

    final updated = widget.plan.copy();
    updated.priceCentavos = price.round();
    updated.originalPriceCentavos = origPrice;
    updated.label = _labelCtrl.text.trim();
    updated.period = _periodCtrl.text.trim();

    widget.onSave(updated);
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isEnterprise = widget.plan.plan == 'enterprise';
    final isStarter = widget.plan.plan == 'starter';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  widget.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (isStarter) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('FREE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280))),
                  ),
                ],
                if (isEnterprise) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('CUSTOM',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E))),
                  ),
                ],
                const Spacer(),
                if (_dirty)
                  ElevatedButton.icon(
                    onPressed: widget.saving ? null : _handleSave,
                    icon: widget.saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // Fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _field(
                  label: 'Display Label',
                  hint: 'e.g. ₱2,999 or Free',
                  controller: _labelCtrl,
                  width: 180,
                ),
                _field(
                  label: 'Period',
                  hint: 'e.g. /month',
                  controller: _periodCtrl,
                  width: 120,
                ),
                _field(
                  label: 'Price (₱)',
                  hint: '0.00',
                  controller: _priceCtrl,
                  width: 140,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  keyboardType: TextInputType.number,
                ),
                _field(
                  label: 'Original Price (₱)',
                  hint: 'Leave blank if none',
                  controller: _originalPriceCtrl,
                  width: 160,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    double width = 200,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: (_) => _markDirty(),
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
