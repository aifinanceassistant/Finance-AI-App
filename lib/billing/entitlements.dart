/// Entitlements UI mirror of web `lib/billing/entitlements.ts`.
library;

class EntitlementFeatures {
  const EntitlementFeatures({
    this.goals = false,
    this.investments = false,
    this.aiCoaching = false,
    this.liveRefresh = false,
    this.subscriptionFinder = false,
    this.reportsAdvanced = false,
    this.canInvite = false,
  });

  final bool goals;
  final bool investments;
  final bool aiCoaching;
  final bool liveRefresh;
  final bool subscriptionFinder;
  final bool reportsAdvanced;
  final bool canInvite;

  static const full = EntitlementFeatures(
    goals: true,
    investments: true,
    aiCoaching: true,
    liveRefresh: true,
    subscriptionFinder: true,
    reportsAdvanced: true,
    canInvite: true,
  );

  static const starter = EntitlementFeatures();

  factory EntitlementFeatures.fromJson(Object? raw) {
    if (raw is! Map) return starter;
    return EntitlementFeatures(
      goals: raw['goals'] == true,
      investments: raw['investments'] == true,
      aiCoaching: raw['aiCoaching'] == true,
      liveRefresh: raw['liveRefresh'] == true,
      subscriptionFinder: raw['subscriptionFinder'] == true,
      reportsAdvanced: raw['reportsAdvanced'] == true,
      canInvite: raw['canInvite'] == true,
    );
  }

  bool operator [](String key) {
    switch (key) {
      case 'goals':
        return goals;
      case 'investments':
        return investments;
      case 'aiCoaching':
        return aiCoaching;
      case 'liveRefresh':
        return liveRefresh;
      case 'subscriptionFinder':
        return subscriptionFinder;
      case 'reportsAdvanced':
        return reportsAdvanced;
      case 'canInvite':
        return canInvite;
      default:
        return false;
    }
  }
}

class Entitlements {
  const Entitlements({
    this.plan,
    this.maxSpaces = 1,
    this.maxAccounts = 5,
    this.historyDays = 90,
    this.maxMembersPerSpace = 1,
    this.canInvite = false,
    this.features = EntitlementFeatures.starter,
    this.isAppAdmin = false,
    this.isSubscribed = false,
  });

  final String? plan; // solo | team | family
  final int maxSpaces;
  final int? maxAccounts;
  final int? historyDays;
  final int maxMembersPerSpace;
  final bool canInvite;
  final EntitlementFeatures features;
  final bool isAppAdmin;
  final bool isSubscribed;

  static const starter = Entitlements();

  static const admin = Entitlements(
    plan: 'family',
    maxSpaces: 100,
    maxAccounts: null,
    historyDays: null,
    maxMembersPerSpace: 100,
    canInvite: true,
    features: EntitlementFeatures.full,
    isAppAdmin: true,
    isSubscribed: true,
  );

  factory Entitlements.fromJson(Object? raw) {
    if (raw is! Map) return starter;
    return Entitlements(
      plan: raw['plan'] as String?,
      maxSpaces: (raw['maxSpaces'] as num?)?.toInt() ?? 1,
      maxAccounts: raw['maxAccounts'] == null
          ? null
          : (raw['maxAccounts'] as num?)?.toInt(),
      historyDays: raw['historyDays'] == null
          ? null
          : (raw['historyDays'] as num?)?.toInt(),
      maxMembersPerSpace: (raw['maxMembersPerSpace'] as num?)?.toInt() ?? 1,
      canInvite: raw['canInvite'] == true,
      features: EntitlementFeatures.fromJson(raw['features']),
      isAppAdmin: raw['isAppAdmin'] == true,
      isSubscribed: raw['isSubscribed'] == true,
    );
  }

  bool hasFeature(String feature) {
    if (isAppAdmin) return true;
    return features[feature];
  }
}

/// App-level roles that get full access (mirror of web `isAdminRole`).
bool isAppAdminRole(String? role) {
  if (role == null) return false;
  final r = role.trim().toLowerCase();
  return r == 'admin' || r == 'superadmin' || r == 'owner';
}

class SpaceAccessInfo {
  const SpaceAccessInfo({
    this.role = 'viewer',
    this.permissions,
    this.isOwner = false,
    this.canDeleteSpace = false,
    this.isAppAdmin = false,
  });

  final String role;
  final Map<String, dynamic>? permissions;
  final bool isOwner;
  final bool canDeleteSpace;
  final bool isAppAdmin;

  factory SpaceAccessInfo.fromJson(Object? raw) {
    if (raw is! Map) return const SpaceAccessInfo();
    return SpaceAccessInfo(
      role: (raw['role'] as String?) ?? 'viewer',
      permissions: raw['permissions'] is Map
          ? Map<String, dynamic>.from(raw['permissions'] as Map)
          : null,
      isOwner: raw['isOwner'] == true,
      canDeleteSpace: raw['canDeleteSpace'] == true || raw['isOwner'] == true,
      isAppAdmin: raw['isAppAdmin'] == true,
    );
  }
}
