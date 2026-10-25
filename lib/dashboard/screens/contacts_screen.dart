import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../contacts_controller.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../filter_sort.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'name', label: 'Name', type: FilterFieldType.text),
  FilterFieldDef(id: 'kind', label: 'Kind', type: FilterFieldType.select),
  FilterFieldDef(id: 'email', label: 'Email', type: FilterFieldType.text),
  FilterFieldDef(id: 'phone', label: 'Phone', type: FilterFieldType.text),
];

Object? _contactValue(ContactRecord c, String field) {
  switch (field) {
    case 'name':
      return c.name;
    case 'kind':
      return contactKindLabel(c.kind);
    case 'email':
      return c.email ?? '';
    case 'phone':
      return c.phone ?? '';
    default:
      return '';
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});

  final ContactsController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';

  ContactsController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onCtrl);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  List<String> _selectOptions(String field) {
    if (field != 'kind') return [];
    return ContactKind.values.map(contactKindLabel).toList();
  }

  List<ContactRecord> get _filtered {
    final searched =
        applySearch(_ctrl.items, _search, _filterFields, _contactValue);
    final filtered = applyFilters(searched, _filterRules, _contactValue);
    return applySort(filtered, _sortRules, _contactValue);
  }

  Future<void> _openEditor({ContactRecord? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var kind = existing?.kind ?? ContactKind.both;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;

    await showDashSheet<void>(
      context: context,
      title: existing == null ? 'Add contact' : 'Edit contact',
      description: 'Customers and vendors for bills, invoices, and transactions',
      builder: (ctx, setSheet) {
        setLocal = setSheet;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Acme Corp',
              autofocus: true,
              errorText: fieldErrors['name'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Kind'),
            DashDropdown<ContactKind>(
              value: kind,
              items: ContactKind.values,
              labelOf: contactKindLabel,
              onChanged: (v) => setSheet(() => kind = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Email'),
            DashTextField(controller: emailCtrl, hint: 'billing@example.com'),
            const SizedBox(height: 14),
            const DashFieldLabel('Phone'),
            DashTextField(controller: phoneCtrl, hint: '+1 …'),
            const SizedBox(height: 14),
            const DashFieldLabel('Notes'),
            DashTextField(
              controller: notesCtrl,
              hint: 'Optional memo',
              maxLines: 3,
            ),
          ],
        );
      },
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Remove contact?'),
                  content: Text('Remove “${existing.name}”?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Color(0xFFC53030)),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true || !mounted) return;
              final removed = await _ctrl.remove(existing.id);
              if (!mounted) return;
              Navigator.pop(context);
              toast(context, removed ? '${existing.name} removed' : 'Couldn’t remove ${existing.name}');
            },
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFC53030),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: AccentButton(
            label: existing == null ? 'Add' : 'Save',
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                setLocal?.call(
                  () => fieldErrors = {'name': 'Name is required'},
                );
                return;
              }
              setLocal?.call(() => fieldErrors = {});
              if (existing == null) {
                final row = await _ctrl.create(
                  name: nameCtrl.text,
                  kind: kind,
                  email: emailCtrl.text,
                  phone: phoneCtrl.text,
                  notes: notesCtrl.text,
                );
                if (!mounted) return;
                Navigator.pop(context);
                toast(context, row != null ? '${row.name} added' : 'Couldn’t add ${nameCtrl.text.trim()}');
              } else {
                final row = await _ctrl.update(
                  existing.id,
                  name: nameCtrl.text,
                  kind: kind,
                  email: emailCtrl.text,
                  phone: phoneCtrl.text,
                  notes: notesCtrl.text,
                );
                if (!mounted) return;
                Navigator.pop(context);
                toast(
                  context,
                  row != null ? '${row.name} updated' : 'Couldn’t update ${existing.name}',
                );
              }
            },
          ),
        ),
      ],
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite =
        SpacesScope.maybeOf(context)?.can('transactions', 'write') != false;
    final filtered = _filtered;

    return DashModalScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashFeedChrome(
            title: 'Contacts',
            subtitle: filtered.length == _ctrl.items.length
                ? '${filtered.length} contacts'
                : '${filtered.length} of ${_ctrl.items.length}',
            onPrimary: canWrite ? () => _openEditor() : null,
            primaryTooltip: 'Add contact',
            primaryEnabled: canWrite,
            filterBar: FilterSortBar(
              fields: _filterFields,
              rules: _filterRules,
              sorts: _sortRules,
              selectOptions: _selectOptions,
              defaultFilterField: 'kind',
              defaultSortField: 'name',
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search contacts…',
              onRulesChanged: (rules) => setState(() => _filterRules = rules),
              onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
              iconButtons: true,
              expandSearch: true,
            ),
          ),
          if (_ctrl.loading)
            const DashLoadingBody(kpiCount: 0, listRows: 5)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
                      child: Text(
                        'No contacts yet',
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in filtered)
                          _ContactRow(
                            contact: c,
                            onTap: canWrite
                                ? () => _openEditor(existing: c)
                                : null,
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, this.onTap});

  final ContactRecord contact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.dashLine)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.dashBrandFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  contact.name.trim().isNotEmpty
                      ? contact.name.trim()[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.dashInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        contactKindLabel(contact.kind),
                        if (contact.email?.isNotEmpty == true) contact.email!,
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: context.dashMute),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.dashSoftMute),
            ],
          ),
        ),
      ),
    );
  }
}
