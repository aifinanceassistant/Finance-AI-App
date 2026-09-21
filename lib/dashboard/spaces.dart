import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../billing/entitlements.dart';
import '../spaces/permissions.dart';

class Space {
  const Space({
    required this.id,
    required this.name,
    required this.type,
    this.role,
    this.permissions,
    this.isOwner,
    this.canDeleteSpace,
  });

  final String id;
  final String name;
  final String type; // Personal | Business
  final String? role;
  final PermissionMap? permissions;
  final bool? isOwner;
  final bool? canDeleteSpace;

  String get initial =>
      name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase();

  factory Space.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    String? role;
    PermissionMap? permissions;
    bool? isOwner;
    bool? canDeleteSpace;

    if (access is Map) {
      role = access['role'] as String?;
      permissions = normalizePermissionMap(access['permissions']);
      isOwner = access['isOwner'] == true;
      canDeleteSpace =
          access['canDeleteSpace'] == true || access['isOwner'] == true;
    } else {
      role = json['role'] as String?;
      if (json['permissions'] != null) {
        permissions = normalizePermissionMap(json['permissions']);
      }
      isOwner = json['isOwner'] as bool?;
      canDeleteSpace = json['canDeleteSpace'] as bool?;
    }

    return Space(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Space',
      type: json['type'] as String? ?? 'Personal',
      role: role,
      permissions: permissions,
      isOwner: isOwner,
      canDeleteSpace: canDeleteSpace,
    );
  }

  Space copyWith({
    String? id,
    String? name,
    String? type,
    String? role,
    PermissionMap? permissions,
    bool? isOwner,
    bool? canDeleteSpace,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isOwner: isOwner ?? this.isOwner,
      canDeleteSpace: canDeleteSpace ?? this.canDeleteSpace,
    );
  }
}

class SpaceMember {
  const SpaceMember({
    required this.id,
    required this.portfolioId,
    required this.email,
    required this.role,
    required this.status,
    this.userId,
    this.name,
    this.permissions,
  });

  final String id;
  final String portfolioId;
  final String? userId;
  final String email;
  final String? name;
  final String role;
  final String status;
  final PermissionMap? permissions;

  factory SpaceMember.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] as String?) ?? 'viewer';
    return SpaceMember(
      id: json['id'] as String,
      portfolioId: (json['portfolioId'] as String?) ??
          (json['portfolio_id'] as String?) ??
          '',
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      email: (json['email'] as String?) ?? '',
      name: json['name'] as String?,
      role: role,
      status: (json['status'] as String?) ?? 'active',
      permissions: permissionMapFromJson(json['permissions'], role: role),
    );
  }
}

class SpacesController extends ChangeNotifier {
  SpacesController(this._auth);

  factory SpacesController.fake() {
    final c = SpacesController(AuthController.fake());
    c._spaces = const [
      Space(
        id: 'fake-personal',
        name: 'Personal',
        type: 'Personal',
        role: 'owner',
        isOwner: true,
        canDeleteSpace: true,
      ),
    ];
    c._spaceId = c._spaces.first.id;
    c._access = const SpaceAccessInfo(
      role: 'owner',
      isOwner: true,
      canDeleteSpace: true,
    );
    c._permissions = permissionsForRole('owner');
    c._entitlements = Entitlements.admin;
    c._selfEntitlements = Entitlements.admin;
    c._loading = false;
    c._ready = true;
    return c;
  }

  final AuthController _auth;

  List<Space> _spaces = [];
  String _spaceId = '';
  bool _loading = true;
  bool _ready = false;
  bool _accessLoading = false;

  SpaceAccessInfo? _access;
  PermissionMap? _permissions;
  Entitlements _entitlements = Entitlements.starter;
  Entitlements _selfEntitlements = Entitlements.starter;

  static const _prefsKey = 'financeai-space-id';

  List<Space> get spaces => List.unmodifiable(_spaces);
  String get spaceId => _spaceId;
  Space get space {
    for (final s in _spaces) {
      if (s.id == _spaceId) return s;
    }
    if (_spaces.isNotEmpty) return _spaces.first;
    return const Space(id: 'pending', name: 'Space', type: 'Personal');
  }

  bool get loading => _loading;
  bool get ready => _ready;
  bool get accessLoading => _accessLoading;

  SpaceAccessInfo? get access => _access;
  PermissionMap? get permissions => _permissions;
  Entitlements get entitlements => _entitlements;
  Entitlements get selfEntitlements => _selfEntitlements;

  bool get isOwner =>
      _access?.isOwner == true ||
      space.isOwner == true ||
      space.role == 'owner';

  bool get canDeleteSpace =>
      _access?.canDeleteSpace == true ||
      space.canDeleteSpace == true ||
      isOwner;

  bool get canInvite =>
      (_selfEntitlements.isAppAdmin || _selfEntitlements.canInvite) &&
      can('members', 'write');

  bool get canCreateSpace {
    if (_selfEntitlements.isAppAdmin) return true;
    return _spaces.length < _selfEntitlements.maxSpaces;
  }

  /// Permission check for the active space. App admins get full access.
  bool can(String area, String action) {
    if (_auth.user?.isAppAdmin == true ||
        _access?.isAppAdmin == true ||
        _entitlements.isAppAdmin ||
        _selfEntitlements.isAppAdmin) {
      return true;
    }
    final map = _permissions ?? space.permissions;
    if (map != null) return canPermission(map, area, action);
    // Owner of a space without loaded access: allow.
    if (isOwner) return true;
    // Default: allow read so UI isn't blank before access loads.
    return action == 'read';
  }

  bool hasFeature(String feature) {
    if (_auth.user?.isAppAdmin == true ||
        _entitlements.isAppAdmin ||
        _selfEntitlements.isAppAdmin) {
      return true;
    }
    // Prefer space-owner entitlements for product features.
    return _entitlements.hasFeature(feature);
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    if (_auth.isFake) {
      _spaces = const [
        Space(
          id: 'fake-personal',
          name: 'Personal',
          type: 'Personal',
          role: 'owner',
          isOwner: true,
          canDeleteSpace: true,
        ),
      ];
      _spaceId = _spaces.first.id;
      _access = const SpaceAccessInfo(
        role: 'owner',
        isOwner: true,
        canDeleteSpace: true,
      );
      _permissions = permissionsForRole('owner');
      _entitlements = Entitlements.admin;
      _selfEntitlements = Entitlements.admin;
      _loading = false;
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = await _auth.apiDecode('GET', '/api/portfolios');
      final list = <Space>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(Space.fromJson(item));
          } else if (item is Map) {
            list.add(Space.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      _spaces = list;

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _spaceId = list.any((s) => s.id == stored)
          ? stored!
          : (list.isNotEmpty ? list.first.id : '');
    } catch (e) {
      debugPrint('SpacesController.load: $e');
      _spaces = const [];
      _spaceId = '';
    }

    _loading = false;
    _ready = true;
    notifyListeners();

    if (_spaceId.isNotEmpty) {
      await loadAccess(_spaceId);
    }
  }

  Future<void> loadAccess(String id) async {
    if (id.isEmpty) return;

    if (_auth.isFake) {
      _access = const SpaceAccessInfo(
        role: 'owner',
        isOwner: true,
        canDeleteSpace: true,
      );
      _permissions = permissionsForRole('owner');
      _entitlements = Entitlements.admin;
      _selfEntitlements = Entitlements.admin;
      notifyListeners();
      return;
    }

    _accessLoading = true;
    notifyListeners();

    try {
      final decoded =
          await _auth.apiDecode('GET', '/api/spaces/$id/access');
      if (decoded is Map<String, dynamic>) {
        final accessRaw = decoded['access'];
        _access = SpaceAccessInfo.fromJson(accessRaw);
        _permissions = permissionMapFromJson(
          accessRaw is Map ? accessRaw['permissions'] : null,
          role: _access?.role,
        );
        _entitlements = Entitlements.fromJson(decoded['entitlements']);
        _selfEntitlements = Entitlements.fromJson(
          decoded['selfEntitlements'] ?? decoded['entitlements'],
        );

        // Merge access onto the active space entry.
        _spaces = [
          for (final s in _spaces)
            if (s.id == id)
              s.copyWith(
                role: _access?.role,
                permissions: _permissions,
                isOwner: _access?.isOwner,
                canDeleteSpace: _access?.canDeleteSpace,
              )
            else
              s,
        ];
      }
    } catch (e) {
      debugPrint('SpacesController.loadAccess: $e');
    }

    _accessLoading = false;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (!_spaces.any((s) => s.id == id)) return;
    _spaceId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
    await loadAccess(id);
  }

  Future<Space?> create({
    required String name,
    String type = 'Personal',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (!canCreateSpace) return null;

    if (_auth.isFake) {
      final space = Space(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed,
        type: type,
        role: 'owner',
        isOwner: true,
        canDeleteSpace: true,
      );
      _spaces = [..._spaces, space];
      await select(space.id);
      return space;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/portfolios',
      body: {'name': trimmed, 'type': type},
    );
    if (decoded is! Map<String, dynamic>) return null;
    final space = Space.fromJson(decoded);
    _spaces = [..._spaces, space];
    await select(space.id);
    return space;
  }

  Future<bool> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    if (_auth.isFake) {
      _spaces = [
        for (final s in _spaces)
          if (s.id == id)
            s.copyWith(name: trimmed)
          else
            s,
      ];
      notifyListeners();
      return true;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/portfolios/$id',
      body: {'name': trimmed},
    );
    if (decoded is! Map<String, dynamic>) return false;
    final updated = Space.fromJson(decoded);
    _spaces = [for (final s in _spaces) if (s.id == id) updated else s];
    notifyListeners();
    return true;
  }

  Future<bool> remove(String id) async {
    if (_spaces.length <= 1) return false;
    if (!canDeleteSpace && id == _spaceId) return false;

    if (_auth.isFake) {
      _spaces = _spaces.where((s) => s.id != id).toList();
      if (_spaceId == id) await select(_spaces.first.id);
      notifyListeners();
      return true;
    }

    final decoded = await _auth.apiDecode('DELETE', '/api/portfolios/$id');
    if (decoded == null) return false;
    _spaces = _spaces.where((s) => s.id != id).toList();
    if (_spaceId == id && _spaces.isNotEmpty) {
      await select(_spaces.first.id);
    } else {
      notifyListeners();
    }
    return true;
  }

  // ── Members API ──────────────────────────────────────────────────────────

  Future<({List<SpaceMember> members, bool canManage})?> listMembers([
    String? portfolioId,
  ]) async {
    final id = portfolioId ?? _spaceId;
    if (id.isEmpty) return null;

    if (_auth.isFake) {
      return (
        members: [
          SpaceMember(
            id: 'fake-me',
            portfolioId: id,
            email: _auth.user?.email ?? 'you@example.com',
            name: _auth.user?.name,
            role: 'owner',
            status: 'active',
            permissions: permissionsForRole('owner'),
          ),
        ],
        canManage: true,
      );
    }

    final decoded = await _auth.apiDecode('GET', '/api/spaces/$id/members');
    if (decoded is! Map<String, dynamic>) return null;
    final raw = decoded['members'];
    final members = <SpaceMember>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          members.add(SpaceMember.fromJson(item));
        } else if (item is Map) {
          members.add(SpaceMember.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return (
      members: members,
      canManage: decoded['canManage'] == true,
    );
  }

  Future<({String? inviteToken, String? error})> inviteMember({
    required String email,
    required String role,
    PermissionMap? permissions,
    String? portfolioId,
  }) async {
    final id = portfolioId ?? _spaceId;
    if (id.isEmpty) return (inviteToken: null, error: 'No space');
    if (!canInvite && !_selfEntitlements.isAppAdmin) {
      return (inviteToken: null, error: 'Invites require Plus or Family');
    }

    if (_auth.isFake) {
      return (inviteToken: 'fake-invite-token', error: null);
    }

    final body = <String, dynamic>{
      'email': email.trim(),
      'role': role,
    };
    if (role == 'custom' && permissions != null) {
      body['permissions'] = permissionMapToJson(permissions);
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/spaces/$id/members',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) {
      return (inviteToken: null, error: 'Invite failed');
    }
    if (decoded['error'] is String) {
      return (inviteToken: null, error: decoded['error'] as String);
    }
    return (
      inviteToken: decoded['inviteToken'] as String?,
      error: null,
    );
  }

  Future<String?> updateMember({
    required String memberId,
    required String role,
    PermissionMap? permissions,
    String? portfolioId,
  }) async {
    final id = portfolioId ?? _spaceId;
    if (id.isEmpty) return 'No space';

    if (_auth.isFake) return null;

    final body = <String, dynamic>{'role': role};
    if (role == 'custom' && permissions != null) {
      body['permissions'] = permissionMapToJson(permissions);
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/spaces/$id/members/$memberId',
      body: body,
    );
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    if (decoded == null) return 'Update failed';
    return null;
  }

  Future<String?> removeMember(String memberId, {String? portfolioId}) async {
    final id = portfolioId ?? _spaceId;
    if (id.isEmpty) return 'No space';
    if (_auth.isFake) return null;

    final decoded = await _auth.apiDecode(
      'DELETE',
      '/api/spaces/$id/members/$memberId',
    );
    if (decoded == null) return 'Remove failed';
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    return null;
  }

  Future<String?> acceptInvite(String token) async {
    if (token.trim().isEmpty) return 'Missing token';
    if (_auth.isFake) return null;

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/invites/accept',
      body: {'token': token.trim()},
    );
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    if (decoded == null) return 'Could not accept invite';
    await load();
    return null;
  }
}
