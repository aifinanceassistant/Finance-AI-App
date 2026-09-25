import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'dash_colors.dart';
import 'dash_sheets.dart';
import 'ui.dart';

enum NotifSeverity { critical, warning, info }

enum NotifStatus { unread, read, archived }

enum NotifCategory { billing, security, accounts, budgets, system }

class DashNotification {
  const DashNotification({
    required this.id,
    required this.title,
    required this.detail,
    required this.date,
    required this.severity,
    required this.status,
    required this.category,
  });

  final String id;
  final String title;
  final String detail;
  final String date;
  final NotifSeverity severity;
  final NotifStatus status;
  final NotifCategory category;

  DashNotification copyWith({NotifStatus? status}) {
    return DashNotification(
      id: id,
      title: title,
      detail: detail,
      date: date,
      severity: severity,
      status: status ?? this.status,
      category: category,
    );
  }
}

const _prefsKey = 'financeai.notifications.v1';

const _demoSeed = <DashNotification>[
  DashNotification(
    id: 'n1',
    title: 'Service restrictions are active.',
    detail: 'AI credits are paused until your payment method updates.',
    date: 'Sep 12, 2026',
    severity: NotifSeverity.critical,
    status: NotifStatus.unread,
    category: NotifCategory.billing,
  ),
  DashNotification(
    id: 'n2',
    title: 'Grace period ending soon.',
    detail:
        'Your Plus plan renews in 3 days. Update billing to avoid interruption.',
    date: 'Sep 09, 2026',
    severity: NotifSeverity.warning,
    status: NotifStatus.unread,
    category: NotifCategory.billing,
  ),
  DashNotification(
    id: 'n3',
    title: 'Grace period started.',
    detail:
        'We couldn’t charge Visa ····4242. You’re in a 7-day grace period.',
    date: 'Sep 06, 2026',
    severity: NotifSeverity.warning,
    status: NotifStatus.read,
    category: NotifCategory.billing,
  ),
  DashNotification(
    id: 'n4',
    title: 'Dining budget is 112% spent.',
    detail: 'You’ve spent \$336 of \$300 this month in Dining.',
    date: 'Sep 11, 2026',
    severity: NotifSeverity.warning,
    status: NotifStatus.unread,
    category: NotifCategory.budgets,
  ),
  DashNotification(
    id: 'n5',
    title: 'New sign-in from Chrome on Mac.',
    detail: 'San Francisco, CA · If this wasn’t you, review sessions.',
    date: 'Sep 10, 2026',
    severity: NotifSeverity.info,
    status: NotifStatus.read,
    category: NotifCategory.security,
  ),
  DashNotification(
    id: 'n6',
    title: 'Monzo sync needs attention.',
    detail: 'Re-authenticate to keep balances and transactions up to date.',
    date: 'Sep 08, 2026',
    severity: NotifSeverity.critical,
    status: NotifStatus.unread,
    category: NotifCategory.accounts,
  ),
  DashNotification(
    id: 'n7',
    title: 'Weekly digest is ready.',
    detail: 'Cash up \$420 · 3 recurring charges due next week.',
    date: 'Sep 07, 2026',
    severity: NotifSeverity.info,
    status: NotifStatus.archived,
    category: NotifCategory.system,
  ),
];

/// In-memory + SharedPreferences-backed demo notifications.
class NotificationsStore extends ChangeNotifier {
  NotificationsStore._();

  static final NotificationsStore instance = NotificationsStore._();

  List<DashNotification> _items = List.of(_demoSeed);
  var _ready = false;

  List<DashNotification> get items => List.unmodifiable(_items);
  bool get ready => _ready;

  int get unreadCount =>
      _items.where((n) => n.status == NotifStatus.unread).length;

  Future<void> ensureLoaded() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _items = _demoSeed.map((seed) {
            final statusName = decoded[seed.id] as String?;
            final status = _parseStatus(statusName);
            return status == null ? seed : seed.copyWith(status: status);
          }).toList();
        }
      } catch (_) {
        _items = List.of(_demoSeed);
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{
      for (final n in _items) n.id: n.status.name,
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  Future<void> setStatus(String id, NotifStatus status) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0) return;
    if (_items[i].status == status) return;
    _items = List.of(_items)..[i] = _items[i].copyWith(status: status);
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    var changed = false;
    _items = _items.map((n) {
      if (n.status == NotifStatus.unread) {
        changed = true;
        return n.copyWith(status: NotifStatus.read);
      }
      return n;
    }).toList();
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  NotifStatus? _parseStatus(String? name) {
    if (name == null) return null;
    for (final s in NotifStatus.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

Color _severityColor(NotifSeverity s) => switch (s) {
      NotifSeverity.critical => const Color(0xFFF87171),
      NotifSeverity.warning => const Color(0xFFFBBF24),
      NotifSeverity.info => const Color(0xFF60A5FA),
    };

String _severityLabel(NotifSeverity s) => switch (s) {
      NotifSeverity.critical => 'Critical',
      NotifSeverity.warning => 'Warning',
      NotifSeverity.info => 'Info',
    };

String _categoryLabel(NotifCategory c) => switch (c) {
      NotifCategory.billing => 'Billing',
      NotifCategory.security => 'Security',
      NotifCategory.accounts => 'Accounts',
      NotifCategory.budgets => 'Budgets',
      NotifCategory.system => 'System',
    };

String _statusLabel(NotifStatus s) => switch (s) {
      NotifStatus.unread => 'Unread',
      NotifStatus.read => 'Read',
      NotifStatus.archived => 'Archived',
    };

/// Bell button with unread badge; opens the notifications center sheet.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    this.onOpenItem,
  });

  /// Called after marking an item read when the user taps it.
  final ValueChanged<DashNotification>? onOpenItem;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final _store = NotificationsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    // ignore: discarded_futures
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    await _store.ensureLoaded();
    if (!mounted) return;
    await showNotificationsCenter(
      context,
      onOpenItem: widget.onOpenItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _store.unreadCount;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(
          unread > 9 ? '9+' : '$unread',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        child: Icon(
          Icons.notifications_outlined,
          color: context.dashInk,
          size: 22,
        ),
      ),
    );
  }
}

Future<void> showNotificationsCenter(
  BuildContext context, {
  ValueChanged<DashNotification>? onOpenItem,
}) {
  return showDashSheet<void>(
    context: context,
    title: 'Notifications',
    description: 'Billing, security, and account alerts',
    builder: (ctx, setSheet) {
      return _NotificationsPanel(
        onChanged: () => setSheet(() {}),
        onOpenItem: (item) {
          Navigator.pop(ctx);
          onOpenItem?.call(item);
        },
      );
    },
  );
}

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel({
    required this.onChanged,
    this.onOpenItem,
  });

  final VoidCallback onChanged;
  final ValueChanged<DashNotification>? onOpenItem;

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  final _store = NotificationsStore.instance;
  NotifCategory? _category;
  NotifStatus? _status;
  NotifSeverity? _severity;

  List<DashNotification> get _filtered {
    return _store.items.where((n) {
      if (_category != null && n.category != _category) return false;
      if (_status != null && n.status != _status) return false;
      if (_severity != null && n.severity != _severity) return false;
      return true;
    }).toList();
  }

  Future<void> _markRead(DashNotification n) async {
    if (n.status == NotifStatus.unread) {
      await _store.setStatus(n.id, NotifStatus.read);
      widget.onChanged();
    }
  }

  Future<void> _archive(DashNotification n) async {
    await _store.setStatus(n.id, NotifStatus.archived);
    widget.onChanged();
  }

  Future<void> _pickCategory() async {
    final options = <MapEntry<NotifCategory?, String>>[
      const MapEntry(null, 'All categories'),
      for (final c in NotifCategory.values)
        MapEntry(c, _categoryLabel(c)),
    ];
    final i = await _pickIndex(
      context: context,
      title: 'Category',
      labels: options.map((e) => e.value).toList(),
      selected: options.indexWhere((e) => e.key == _category),
    );
    if (i != null) setState(() => _category = options[i].key);
  }

  Future<void> _pickStatus() async {
    final options = <MapEntry<NotifStatus?, String>>[
      const MapEntry(null, 'All statuses'),
      for (final s in NotifStatus.values) MapEntry(s, _statusLabel(s)),
    ];
    final i = await _pickIndex(
      context: context,
      title: 'Status',
      labels: options.map((e) => e.value).toList(),
      selected: options.indexWhere((e) => e.key == _status),
    );
    if (i != null) setState(() => _status = options[i].key);
  }

  Future<void> _pickSeverity() async {
    final options = <MapEntry<NotifSeverity?, String>>[
      const MapEntry(null, 'All severities'),
      for (final s in NotifSeverity.values) MapEntry(s, _severityLabel(s)),
    ];
    final i = await _pickIndex(
      context: context,
      title: 'Severity',
      labels: options.map((e) => e.value).toList(),
      selected: options.indexWhere((e) => e.key == _severity),
    );
    if (i != null) setState(() => _severity = options[i].key);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: _category == null
                    ? 'All categories'
                    : _categoryLabel(_category!),
                onTap: _pickCategory,
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _status == null ? 'All statuses' : _statusLabel(_status!),
                onTap: _pickStatus,
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _severity == null
                    ? 'All severities'
                    : _severityLabel(_severity!),
                onTap: _pickSeverity,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _store.unreadCount == 0
                ? null
                : () async {
                    await _store.markAllRead();
                    widget.onChanged();
                  },
            child: const Text(
              'Mark all read',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'No notifications match these filters',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.dashSoftMute, fontSize: 13),
            ),
          )
        else
          for (final n in filtered)
            _NotifRow(
              item: n,
              onTap: () async {
                await _markRead(n);
                widget.onOpenItem?.call(
                  n.copyWith(
                    status: n.status == NotifStatus.unread
                        ? NotifStatus.read
                        : n.status,
                  ),
                );
              },
              onMarkRead: n.status == NotifStatus.unread
                  ? () => _markRead(n)
                  : null,
              onArchive: n.status != NotifStatus.archived
                  ? () => _archive(n)
                  : null,
            ),
        const SizedBox(height: 8),
        GhostButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.isDark ? context.dashLine : const Color(0xFFF6F9FC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.dashInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 16, color: context.dashMute),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> _pickIndex({
  required BuildContext context,
  required String title,
  required List<String> labels,
  required int selected,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: context.dashPanel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: ctx.dashInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < labels.length; i++)
              ListTile(
                title: Text(labels[i]),
                trailing: i == selected
                    ? Icon(Icons.check_rounded, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.pop(ctx, i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.item,
    required this.onTap,
    this.onMarkRead,
    this.onArchive,
  });

  final DashNotification item;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final unread = item.status == NotifStatus.unread;
    final archived = item.status == NotifStatus.archived;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: unread
            ? (context.isDark
                ? AppColors.brand.withValues(alpha: 0.12)
                : const Color(0xFFEAF4FB))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.dashLine),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _severityColor(item.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: archived
                              ? context.dashSoftMute
                              : context.dashInk,
                          fontSize: 13,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.date} · ${_categoryLabel(item.category)}',
                        style: TextStyle(
                          color: context.dashSoftMute,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMarkRead != null)
                  IconButton(
                    tooltip: 'Mark read',
                    visualDensity: VisualDensity.compact,
                    onPressed: onMarkRead,
                    icon: Icon(
                      Icons.mark_email_read_outlined,
                      size: 18,
                      color: context.dashMute,
                    ),
                  ),
                if (onArchive != null)
                  IconButton(
                    tooltip: 'Archive',
                    visualDensity: VisualDensity.compact,
                    onPressed: onArchive,
                    icon: Icon(
                      Icons.archive_outlined,
                      size: 18,
                      color: context.dashMute,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
