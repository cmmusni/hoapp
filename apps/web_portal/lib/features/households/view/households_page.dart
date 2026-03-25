import 'package:flutter/material.dart';
import '../widgets/household_form.dart';

/// Households page: roster management with FormBuilder form.
class HouseholdsPage extends StatelessWidget {
  const HouseholdsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 800;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: member list
                  Expanded(child: _MemberList()),
                  const SizedBox(width: 24),
                  // Right: add member form
                  SizedBox(
                    width: 420,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Row(
                              children: [
                                Icon(Icons.person_add,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Add Member',
                                    style: theme.textTheme.titleMedium),
                              ],
                            ),
                          ),
                          const HouseholdForm(),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _MemberList(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Row(
                            children: [
                              Icon(Icons.person_add,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Add Member',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                        ),
                        const HouseholdForm(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  // Demo roster data
  static const _members = [
    {
      'name': 'Juan Dela Cruz',
      'role': 'Primary',
      'rel': 'Owner',
      'email': 'juan@email.com'
    },
    {
      'name': 'Maria Dela Cruz',
      'role': 'Secondary',
      'rel': 'Spouse',
      'email': 'maria@email.com'
    },
    {
      'name': 'Jose Dela Cruz',
      'role': 'Secondary',
      'rel': 'Child',
      'email': 'jose@email.com'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.family_restroom, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Current Members', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${_members.length} members',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            ..._members.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: theme.colorScheme.surfaceContainerLowest,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        m['name']![0],
                        style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(m['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${m['rel']} · ${m['email']}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: m['role'] == 'Primary'
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m['role']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: m['role'] == 'Primary'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          )),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
