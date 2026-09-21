/// Space permission areas and role presets (UI mirror of web `lib/spaces/permissions.ts`).
library;

const spaceAreas = [
  'transactions',
  'accounts',
  'categories',
  'goals',
  'investments',
  'recurring',
  'reports',
  'settings',
  'members',
];

typedef SpaceArea = String;
typedef SpaceAction = String; // 'read' | 'write'
typedef SpaceRole = String; // owner | admin | editor | viewer | custom

class AreaPermission {
  const AreaPermission({required this.read, required this.write});

  final bool read;
  final bool write;

  AreaPermission copyWith({bool? read, bool? write}) => AreaPermission(
        read: read ?? this.read,
        write: write ?? this.write,
      );

  Map<String, dynamic> toJson() => {'read': read, 'write': write};

  factory AreaPermission.fromJson(Object? raw) {
    if (raw is! Map) return const AreaPermission(read: false, write: false);
    final read = raw['read'] == true;
    final write = raw['write'] == true;
    return AreaPermission(read: write ? true : read, write: write);
  }
}

typedef PermissionMap = Map<String, AreaPermission>;

const _allRw = AreaPermission(read: true, write: true);
const _readOnly = AreaPermission(read: true, write: false);
const _none = AreaPermission(read: false, write: false);

PermissionMap _buildMap(AreaPermission Function(String area) fill) {
  return {for (final area in spaceAreas) area: fill(area)};
}

final Map<String, PermissionMap> rolePresets = {
  'owner': _buildMap((_) => _allRw),
  'admin': _buildMap((_) => _allRw),
  'editor': _buildMap((area) {
    if (area == 'settings' || area == 'members') return _none;
    if (area == 'reports') return _readOnly;
    return _allRw;
  }),
  'viewer': _buildMap((area) {
    if (area == 'settings' || area == 'members') return _none;
    return _readOnly;
  }),
};

PermissionMap permissionsForRole(String role) {
  if (role == 'custom') {
    return Map.fromEntries(
      rolePresets['viewer']!.entries.map(
        (e) => MapEntry(e.key, e.value.copyWith()),
      ),
    );
  }
  final preset = rolePresets[role] ?? rolePresets['viewer']!;
  return Map.fromEntries(
    preset.entries.map((e) => MapEntry(e.key, e.value.copyWith())),
  );
}

PermissionMap emptyPermissionMap() => _buildMap((_) => _none);

PermissionMap normalizePermissionMap(Object? raw) {
  final base = emptyPermissionMap();
  if (raw is! Map) return base;
  for (final area in spaceAreas) {
    if (raw.containsKey(area)) {
      base[area] = AreaPermission.fromJson(raw[area]);
    }
  }
  return base;
}

PermissionMap permissionMapFromJson(Object? raw, {String? role}) {
  if (role == 'owner' || role == 'admin') return permissionsForRole(role!);
  if (raw != null) return normalizePermissionMap(raw);
  if (role != null && role != 'custom') return permissionsForRole(role);
  return permissionsForRole('viewer');
}

bool canPermission(
  PermissionMap? permissions,
  String area,
  String action,
) {
  if (permissions == null) return false;
  final entry = permissions[area];
  if (entry == null) return false;
  if (action == 'write') return entry.write;
  return entry.read || entry.write;
}

const List<String> kSpaceAreas = spaceAreas;

const Map<String, String> kAreaLabels = {
  'transactions': 'Transactions',
  'accounts': 'Accounts',
  'categories': 'Categories',
  'goals': 'Goals',
  'investments': 'Investments',
  'recurring': 'Recurring',
  'reports': 'Reports',
  'settings': 'Settings',
  'members': 'Members',
};

const List<({String value, String label})> kInviteRoleOptions = [
  (value: 'admin', label: 'Admin'),
  (value: 'editor', label: 'Editor'),
  (value: 'viewer', label: 'Viewer'),
  (value: 'custom', label: 'Custom'),
];

bool isSpaceRole(String v) =>
    v == 'owner' ||
    v == 'admin' ||
    v == 'editor' ||
    v == 'viewer' ||
    v == 'custom';

Map<String, dynamic> permissionMapToJson(PermissionMap map) => {
      for (final e in map.entries) e.key: e.value.toJson(),
    };
