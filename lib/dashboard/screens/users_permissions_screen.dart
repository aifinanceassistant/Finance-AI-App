import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../spaces/permissions.dart';
import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../spaces.dart';
import '../spaces_scope.dart';
import '../ui.dart';
import 'settings_screen.dart';

/// Manage space members, invites, and per-area permissions.
class UsersPermissionsScreen extends StatefulWidget {
  const UsersPermissionsScreen({super.key});

  @override
  State<UsersPermissionsScreen> createState() => _UsersPermissionsScreenState();
}

class _UsersPermissionsScreenState extends State<UsersPermissionsScreen> {
  List<SpaceMember> _members = [];
  bool _canManage = false;
  bool _loading = true;
  String? _error;

  SpacesController get _spaces => SpacesScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await SpacesScope.read(context).listMembers();
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load members';
        _members = [];
        _canManage = false;
      });
      return;
    }
    setState(() {
      _loading = false;
      _members = result.members;
      _canManage = result.canManage;
    });
  }

  Future<void> _openInvite() async {
    final spaces = SpacesScope.read(context);
    if (!spaces.canInvite && !spaces.selfEntitlements.isAppAdmin) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Upgrade to invite'),
          content: const Text(
            'Inviting members requires Plus or Family. Open Plan settings to subscribe.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('View plans'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsScreen(initialSection: 'plan'),
          ),
        );
      }
      return;
    }

    final emailCtrl = TextEditingController();
    var role = 'viewer';
    var permissions = permissionsForRole('viewer');
    String? inviteToken;
    String? emailError;

    await showDashSheet<void>(
      context: context,
      title: 'Invite member',
      description: 'Send an invite for ${spaces.space.name}',
      builder: (ctx, setSheet) {
        if (inviteToken != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share this invite token with the member:',
                style: TextStyle(color: context.dashMute, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SelectableText(
                inviteToken!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              AccentButton(
                label: 'Copy token',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: inviteToken!));
                  if (context.mounted) toast(context, 'Token copied');
                },
              ),
              const SizedBox(height: 8),
              GhostButton(
                label: 'Done',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Email'),
            DashTextField(
              controller: emailCtrl,
              hint: 'teammate@example.com',
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              errorText: emailError,
            ),
            const SizedBox(height: 12),
            const DashFieldLabel('Role'),
            DashDropdown<String>(
              value: role,
              items: kInviteRoleOptions.map((o) => o.value).toList(),
              labelOf: (v) => kInviteRoleOptions
                  .firstWhere((o) => o.value == v, orElse: () => kInviteRoleOptions.last)
                  .label,
              onChanged: (v) {
                setSheet(() {
                  role = v;
                  if (v != 'custom') {
                    permissions = permissionsForRole(v);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionMatrix(
              permissions: permissions,
              disabled: role == 'admin',
              onChange: (next) {
                setSheet(() {
                  permissions = next;
                  role = 'custom';
                });
              },
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Send invite',
              onSave: () async {
                final email = emailCtrl.text.trim();
                final err = emailValidator(email);
                setSheet(() => emailError = err);
                if (err != null) {
                  toast(context, err);
                  return;
                }
                final result = await spaces.inviteMember(
                  email: email,
                  role: role,
                  permissions: role == 'custom' ? permissions : null,
                );
                if (!ctx.mounted) return;
                if (result.error != null) {
                  toast(context, result.error!);
                  return;
                }
                toast(context, 'Invite created');
                setSheet(() => inviteToken = result.inviteToken ?? '');
                // ignore: discarded_futures
                _load();
              },
            ),
          ],
        );
      },
    );
    emailCtrl.dispose();
  }

  Future<void> _openEdit(SpaceMember member) async {
    if (member.role == 'owner') return;
    final spaces = SpacesScope.read(context);
    var role = member.role == 'owner' ? 'admin' : member.role;
    if (!kInviteRoleOptions.any((o) => o.value == role)) role = 'viewer';
    var permissions =
        member.permissions ?? permissionMapFromJson(null, role: role);

    await showDashSheet<void>(
      context: context,
      title: 'Edit permissions',
      description: member.name ?? member.email,
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Role'),
            DashDropdown<String>(
              value: role,
              items: kInviteRoleOptions.map((o) => o.value).toList(),
              labelOf: (v) => kInviteRoleOptions
                  .firstWhere((o) => o.value == v, orElse: () => kInviteRoleOptions.last)
                  .label,
              onChanged: (v) {
                setSheet(() {
                  role = v;
                  if (v != 'custom') {
                    permissions = permissionsForRole(v);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _PermissionMatrix(
              permissions: permissions,
              disabled: role == 'admin',
              onChange: (next) {
                setSheet(() {
                  permissions = next;
                  role = 'custom';
                });
              },
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Save',
              onSave: () async {
                final err = await spaces.updateMember(
                  memberId: member.id,
                  role: role,
                  permissions: role == 'custom' ? permissions : null,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  toast(context, err);
                  return;
                }
                Navigator.pop(ctx);
                toast(context, 'Permissions updated');
                // ignore: discarded_futures
                _load();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _remove(SpaceMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.email} from this space?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await SpacesScope.read(context).removeMember(member.id);
    if (!mounted) return;
    if (err != null) {
      toast(context, err);
      return;
    }
    toast(context, 'Member removed');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final spaces = _spaces;
    final yourRole = spaces.access?.role ?? spaces.space.role ?? 'viewer';

    return DashModalScaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            DashPageHeader(
              title: 'Users & permissions',
              subtitle:
                  'Manage who can access ${spaces.space.name}. Your role: $yourRole',
              actions: [
                if (_canManage)
                  AccentButton(
                    label: 'Invite member',
                    onPressed: _openInvite,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DashPanel(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: ListShimmer(rows: 4),
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.dashMute),
                            ),
                          )
                        : _members.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  _canManage
                                      ? 'No members yet. Invite someone on Plus or Family.'
                                      : 'You don’t have permission to view members.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.dashMute,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < _members.length; i++)
                                    _MemberTile(
                                      member: _members[i],
                                      canManage: _canManage &&
                                          _members[i].role != 'owner',
                                      showDivider: i < _members.length - 1,
                                      onEdit: () => _openEdit(_members[i]),
                                      onRemove: () => _remove(_members[i]),
                                    ),
                                ],
                              ),
              ),
            ),
            if (!spaces.selfEntitlements.canInvite &&
                !spaces.selfEntitlements.isAppAdmin) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DashPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Invites need Plus or Family',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upgrade to collaborate with roles and permissions.',
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AccentButton(
                        label: 'View plans',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SettingsScreen(initialSection: 'plan'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.showDivider,
    required this.onEdit,
    required this.onRemove,
  });

  final SpaceMember member;
  final bool canManage;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: context.dashLine))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name?.isNotEmpty == true
                      ? member.name!
                      : member.email,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.dashInk,
                  ),
                ),
                if (member.name?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    style: TextStyle(
                      color: context.dashMute,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${member.role} · ${member.status}',
                  style: TextStyle(
                    color: context.dashSoftMute,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canManage) ...[
            LinkAction(label: 'Edit', onTap: onEdit),
            const SizedBox(width: 8),
            LinkAction(label: 'Remove', onTap: onRemove),
          ],
        ],
      ),
    );
  }
}

class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({
    required this.permissions,
    required this.onChange,
    this.disabled = false,
  });

  final PermissionMap permissions;
  final ValueChanged<PermissionMap> onChange;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashFieldLabel('Permissions'),
        if (!disabled) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in rolePresets.keys)
                GhostButton(
                  label: 'Use $key',
                  onPressed: () => onChange(
                    Map.fromEntries(
                      rolePresets[key]!.entries.map(
                        (e) => MapEntry(e.key, e.value.copyWith()),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.dashLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Area',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.dashMute,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        'Read',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.dashMute,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        'Write',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.dashMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.dashLine),
              for (final area in kSpaceAreas)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          kAreaLabels[area] ?? area,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Checkbox(
                          value: permissions[area]?.read ?? false,
                          onChanged: disabled
                              ? null
                              : (v) {
                                  final next = Map<String, AreaPermission>.from(
                                    permissions.map(
                                      (k, val) =>
                                          MapEntry(k, val.copyWith()),
                                    ),
                                  );
                                  final write = next[area]?.write ?? false;
                                  next[area] = AreaPermission(
                                    read: v == true,
                                    write: v == true ? write : false,
                                  );
                                  onChange(next);
                                },
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Checkbox(
                          value: permissions[area]?.write ?? false,
                          onChanged: disabled
                              ? null
                              : (v) {
                                  final next = Map<String, AreaPermission>.from(
                                    permissions.map(
                                      (k, val) =>
                                          MapEntry(k, val.copyWith()),
                                    ),
                                  );
                                  final read = next[area]?.read ?? false;
                                  next[area] = AreaPermission(
                                    read: v == true ? true : read,
                                    write: v == true,
                                  );
                                  onChange(next);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Accept an invite token (e.g. from paste / deep link).
Future<void> acceptInviteFlow(BuildContext context, String token) async {
  final err = await SpacesScope.read(context).acceptInvite(token);
  if (!context.mounted) return;
  if (err != null) {
    toast(context, err);
  } else {
    toast(context, 'Invite accepted — space added');
  }
}
