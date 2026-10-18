import 'package:flutter/material.dart';

import 'contacts_controller.dart';
import 'dash_colors.dart';
import 'dash_sheets.dart';
import 'ui.dart';

/// Dropdown + inline “Add contact” for forms.
class ContactPickerField extends StatelessWidget {
  const ContactPickerField({
    super.key,
    required this.contacts,
    required this.valueId,
    required this.onChanged,
    this.kindFilter,
    this.label,
    this.enabled = true,
  });

  final ContactsController contacts;
  final String? valueId;
  final ValueChanged<String?> onChanged;
  final ContactKind? kindFilter;
  final String? label;
  final bool enabled;

  Future<void> _addContact(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var kind = kindFilter ?? ContactKind.both;
    final created = await showDashSheet<ContactRecord>(
      context: context,
      title: 'Add contact',
      description: 'Customer or vendor for this space',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(controller: nameCtrl, hint: 'Acme Corp', autofocus: true),
            const SizedBox(height: 14),
            const DashFieldLabel('Kind'),
            DashDropdown<ContactKind>(
              value: kind,
              items: ContactKind.values,
              labelOf: contactKindLabel,
              onChanged: (v) => setSheet(() => kind = v),
            ),
          ],
        );
      },
      actions: [
        Expanded(
          child: AccentButton(
            label: 'Add',
            onPressed: () async {
              final row = await contacts.create(
                name: nameCtrl.text,
                kind: kind,
              );
              if (!context.mounted) return;
              Navigator.pop(context, row);
            },
          ),
        ),
      ],
    );
    nameCtrl.dispose();
    if (created != null) onChanged(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final options = contacts.forKind(kindFilter);
    final fieldLabel = label ??
        (kindFilter == ContactKind.customer
            ? 'Customer'
            : kindFilter == ContactKind.vendor
                ? 'Vendor'
                : 'Contact');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashFieldLabel(fieldLabel),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: valueId != null &&
                        options.any((c) => c.id == valueId)
                    ? valueId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.dashPanel,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.dashLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.dashLine),
                  ),
                ),
                hint: Text(
                  'Optional',
                  style: TextStyle(color: context.dashMute, fontSize: 14),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...options.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add contact',
              onPressed: enabled ? () => _addContact(context) : null,
              icon: Icon(Icons.person_add_alt_1_outlined, color: context.dashInk),
            ),
          ],
        ),
      ],
    );
  }
}
