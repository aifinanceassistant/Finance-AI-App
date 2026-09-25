import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../ui.dart';

class McpApiKey {
  const McpApiKey({
    required this.id,
    required this.name,
    required this.keyPreview,
    required this.created,
    this.lastUsed,
    this.usage = 0,
    this.status = 'Active',
    this.mcpPermissions = const [],
    this.mcpFullAccess = true,
  });

  final String id;
  final String name;
  final String keyPreview;
  final String created;
  final String? lastUsed;
  final int usage;
  final String status;
  final List<String> mcpPermissions;
  final bool mcpFullAccess;

  bool get isActive => status.toLowerCase() == 'active';

  factory McpApiKey.fromJson(Map<String, dynamic> json) {
    final perms = <String>[];
    final raw = json['mcpPermissions'];
    if (raw is List) {
      for (final p in raw) {
        if (p is String) perms.add(p);
      }
    }
    return McpApiKey(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Key',
      keyPreview: (json['keyPreview'] as String?) ?? '••••',
      created: (json['created'] as String?) ?? '',
      lastUsed: json['lastUsed'] as String?,
      usage: (json['usage'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'Active',
      mcpPermissions: perms,
      mcpFullAccess: json['mcpFullAccess'] != false,
    );
  }

  McpApiKey copyWith({
    String? status,
    bool? mcpFullAccess,
    List<String>? mcpPermissions,
  }) {
    return McpApiKey(
      id: id,
      name: name,
      keyPreview: keyPreview,
      created: created,
      lastUsed: lastUsed,
      usage: usage,
      status: status ?? this.status,
      mcpPermissions: mcpPermissions ?? this.mcpPermissions,
      mcpFullAccess: mcpFullAccess ?? this.mcpFullAccess,
    );
  }
}

/// In-memory fake keys for demo / widget-test sessions.
List<McpApiKey> _fakeKeys = [
  McpApiKey(
    id: 'fake-key-1',
    name: 'Claude Desktop',
    keyPreview: 'fai_••••a1b2',
    created: DateTime.now()
        .subtract(const Duration(days: 12))
        .toIso8601String(),
    lastUsed: DateTime.now()
        .subtract(const Duration(hours: 5))
        .toIso8601String(),
    usage: 42,
    status: 'Active',
    mcpFullAccess: true,
  ),
];

class McpKeysScreen extends StatefulWidget {
  const McpKeysScreen({super.key});

  @override
  State<McpKeysScreen> createState() => _McpKeysScreenState();
}

class _McpKeysScreenState extends State<McpKeysScreen> {
  List<McpApiKey> _keys = [];
  bool _loading = true;
  String? _error;

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
    final auth = AuthScope.read(context);
    if (auth.isFake) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _keys = List<McpApiKey>.of(_fakeKeys);
        _loading = false;
      });
      return;
    }

    final data = await auth.apiDecode('GET', '/api/settings/api-keys');
    if (!mounted) return;
    if (data is! Map<String, dynamic>) {
      setState(() {
        _loading = false;
        _error = 'Could not load API keys';
        _keys = [];
      });
      return;
    }
    final raw = data['keys'];
    final list = <McpApiKey>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(McpApiKey.fromJson(item));
        } else if (item is Map) {
          list.add(McpApiKey.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    setState(() {
      _keys = list;
      _loading = false;
    });
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.isEmpty ? '—' : iso;
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _createKey() async {
    final nameCtrl = TextEditingController();
    String? nameError;
    var fullAccess = true;

    await showDashSheet<void>(
      context: context,
      title: 'Create API key',
      description: 'Name the key — you’ll see the secret once',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Claude Desktop, Cursor…',
              autofocus: true,
              errorText: nameError,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Full MCP access'),
              subtitle: const Text('Unlock every FinanceAI MCP tool'),
              value: fullAccess,
              onChanged: (v) => setSheet(() => fullAccess = v),
            ),
            const SizedBox(height: 12),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Create',
              onSave: () {
                final err = requiredText(nameCtrl.text, 'Name');
                setSheet(() => nameError = err);
                if (err != null) {
                  toast(context, err);
                  return;
                }
                Navigator.pop(ctx);
                // ignore: discarded_futures
                _doCreate(nameCtrl.text.trim(), fullAccess);
              },
            ),
          ],
        );
      },
    );
    nameCtrl.dispose();
  }

  Future<void> _doCreate(String name, bool fullAccess) async {
    final auth = AuthScope.read(context);
    if (auth.isFake) {
      final id = 'fake-key-${DateTime.now().millisecondsSinceEpoch}';
      final plain =
          'fai_live_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      final preview =
          'fai_••••${plain.substring(plain.length - 4)}';
      final row = McpApiKey(
        id: id,
        name: name,
        keyPreview: preview,
        created: DateTime.now().toIso8601String(),
        usage: 0,
        status: 'Active',
        mcpFullAccess: fullAccess,
      );
      _fakeKeys = [row, ..._fakeKeys];
      if (!mounted) return;
      setState(() => _keys = List<McpApiKey>.of(_fakeKeys));
      await _showPlainKey(plain);
      return;
    }

    final data = await auth.apiDecode(
      'POST',
      '/api/settings/api-keys',
      body: {
        'name': name,
        'mcpFullAccess': fullAccess,
        'mcpPermissions': <String>[],
      },
    );
    if (!mounted) return;
    if (data is! Map<String, dynamic>) {
      toast(context, 'Couldn’t create key');
      return;
    }
    final plain = data['plainKey'] as String?;
    await _load();
    if (!mounted) return;
    if (plain != null && plain.isNotEmpty) {
      await _showPlainKey(plain);
    } else {
      toast(context, 'Key created');
    }
  }

  Future<void> _showPlainKey(String plainKey) async {
    if (!mounted) return;
    await showDashSheet<void>(
      context: context,
      title: 'Copy your API key',
      description: 'This secret is shown only once',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.dashSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.dashLine),
              ),
              child: SelectableText(
                plainKey,
                style: TextStyle(
                  color: context.dashInk,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AccentButton(
              label: 'Copy key',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: plainKey));
                if (!mounted) return;
                toast(context, 'Key copied');
              },
            ),
            const SizedBox(height: 8),
            GhostButton(
              label: 'Done',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleActive(McpApiKey key) async {
    final nextActive = !key.isActive;
    final auth = AuthScope.read(context);
    if (auth.isFake) {
      final updated = key.copyWith(status: nextActive ? 'Active' : 'Inactive');
      _fakeKeys = _fakeKeys
          .map((k) => k.id == key.id ? updated : k)
          .toList();
      setState(() => _keys = List<McpApiKey>.of(_fakeKeys));
      toast(context, nextActive ? 'Key activated' : 'Key revoked');
      return;
    }

    final data = await auth.apiDecode(
      'PATCH',
      '/api/settings/api-keys/${Uri.encodeComponent(key.id)}',
      body: {'active': nextActive},
    );
    if (!mounted) return;
    if (data == null) {
      toast(context, 'Couldn’t update key');
      return;
    }
    toast(context, nextActive ? 'Key activated' : 'Key revoked');
    await _load();
  }

  Future<void> _deleteKey(McpApiKey key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete API key?'),
        content: Text('Permanently remove “${key.name}”. This can’t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final auth = AuthScope.read(context);
    if (auth.isFake) {
      _fakeKeys = _fakeKeys.where((k) => k.id != key.id).toList();
      setState(() => _keys = List<McpApiKey>.of(_fakeKeys));
      toast(context, 'Key deleted');
      return;
    }

    final data = await auth.apiDecode(
      'DELETE',
      '/api/settings/api-keys/${Uri.encodeComponent(key.id)}',
    );
    if (!mounted) return;
    if (data == null) {
      toast(context, 'Couldn’t delete key');
      return;
    }
    toast(context, 'Key deleted');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dashSurface,
      appBar: AppBar(
        backgroundColor: context.dashPanel,
        foregroundColor: context.dashInk,
        elevation: 0,
        title: Text(
          'MCP & API keys',
          style: TextStyle(
            color: context.dashInk,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create key',
            onPressed: _createKey,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Connect Claude, ChatGPT, and other MCP clients to your FinanceAI data.',
              style: TextStyle(
                color: context.dashMute,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Column(
                children: [
                  ShimmerBox(width: 320, height: 72, borderRadius: 12),
                  SizedBox(height: 10),
                  ShimmerBox(width: 320, height: 72, borderRadius: 12),
                ],
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(color: context.dashMute),
                    ),
                    const SizedBox(height: 12),
                    GhostButton(label: 'Retry', onPressed: _load),
                  ],
                ),
              )
            else if (_keys.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Text(
                      'No API keys yet',
                      style: TextStyle(
                        color: context.dashInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create one to authorize MCP clients.',
                      style: TextStyle(color: context.dashMute, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    AccentButton(label: 'Create API key', onPressed: _createKey),
                  ],
                ),
              )
            else
              for (final key in _keys) ...[
                DashPanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              key.name,
                              style: TextStyle(
                                color: context.dashInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: key.isActive
                                  ? AppColors.brand.withValues(alpha: 0.12)
                                  : context.dashWash,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              key.status,
                              style: TextStyle(
                                color: key.isActive
                                    ? AppColors.brand
                                    : context.dashMute,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        key.keyPreview,
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created ${_shortDate(key.created)}'
                        '${key.lastUsed != null ? ' · Last used ${_shortDate(key.lastUsed!)}' : ''}'
                        ' · ${key.usage} call${key.usage == 1 ? '' : 's'}'
                        ' · ${key.mcpFullAccess ? 'Full access' : '${key.mcpPermissions.length} scopes'}',
                        style: TextStyle(
                          color: context.dashSoftMute,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          LinkAction(
                            label: key.isActive ? 'Revoke' : 'Activate',
                            onTap: () => _toggleActive(key),
                          ),
                          const SizedBox(width: 16),
                          LinkAction(
                            label: 'Delete',
                            onTap: () => _deleteKey(key),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
