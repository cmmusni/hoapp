import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

/// FormBuilder-based household member form with validation and conditional fields.
class HouseholdForm extends StatefulWidget {
  final String unitLabel;
  const HouseholdForm({super.key, this.unitLabel = 'Tower A, Unit 101'});

  @override
  State<HouseholdForm> createState() => _HouseholdFormState();
}

class _HouseholdFormState extends State<HouseholdForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormBuilder(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read-only unit display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.apartment, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned Unit',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      Text(widget.unitLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Member Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            FormBuilderTextField(
              name: 'name',
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(2),
              ]),
            ),
            const SizedBox(height: 16),

            FormBuilderDropdown<String>(
              name: 'relationship',
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.people),
              ),
              validator: FormBuilderValidators.required(),
              items: const [
                DropdownMenuItem(value: 'spouse', child: Text('Spouse')),
                DropdownMenuItem(value: 'child', child: Text('Child')),
                DropdownMenuItem(value: 'parent', child: Text('Parent')),
                DropdownMenuItem(value: 'sibling', child: Text('Sibling')),
                DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                DropdownMenuItem(value: 'helper', child: Text('Helper')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
            ),
            const SizedBox(height: 16),

            FormBuilderTextField(
              name: 'email',
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.email(),
              ]),
            ),
            const SizedBox(height: 16),

            FormBuilderTextField(
              name: 'phone',
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            FormBuilderDropdown<String>(
              name: 'role',
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge),
              ),
              initialValue: 'secondary',
              validator: FormBuilderValidators.required(),
              items: const [
                DropdownMenuItem(value: 'primary', child: Text('Primary')),
                DropdownMenuItem(value: 'secondary', child: Text('Secondary')),
              ],
            ),
            const SizedBox(height: 16),

            // Conditional field: show move-in date only for tenants
            Builder(
              builder: (context) {
                final rel =
                    _formKey.currentState?.fields['relationship']?.value;
                if (rel == 'tenant') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FormBuilderDateTimePicker(
                      name: 'move_in_date',
                      inputType: InputType.date,
                      decoration: const InputDecoration(
                        labelText: 'Move-in Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      debugPrint('Household member payload: $values');

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Invite sent to ${values['email']}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ));
    }
  }
}
