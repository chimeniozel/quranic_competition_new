enum UserRole {
  superAdmin('super_admin', 'مدير عام'),
  admin('admin', 'مدير'),
  jury('jury', 'عضو لجنة التحكيم'),
  member('membre', 'عضو عادي');

  const UserRole(this.code, this.displayName);

  final String code;
  final String displayName;

  static UserRole fromString(String code) {
    return UserRole.values.firstWhere(
      (role) => role.code == code,
      orElse: () => UserRole.member,
    );
  }
}

class UserPermissions {
  final bool canCreateVersions;
  final bool canPublishContent;
  final bool canValidateAccounts;
  final bool canDelete;
  final bool canModify;
  final bool canModifyVersions;
  final bool canAssignRoles;
  final bool canViewContent;

  const UserPermissions({
    required this.canCreateVersions,
    required this.canPublishContent,
    required this.canValidateAccounts,
    required this.canDelete,
    required this.canModify,
    required this.canModifyVersions,
    required this.canAssignRoles,
    required this.canViewContent,
  });

  static UserPermissions forRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return const UserPermissions(
          canCreateVersions: true,
          canPublishContent: true,
          canValidateAccounts: true,
          canDelete: true,
          canModify: true,
          canModifyVersions: true,
          canAssignRoles: true,
          canViewContent: true,
        );
      case UserRole.admin:
        return const UserPermissions(
          canCreateVersions: true,
          canPublishContent: true,
          canValidateAccounts: true,
          canDelete: false,
          canModify: false,
          canModifyVersions: false,
          canAssignRoles: false,
          canViewContent: true,
        );
      case UserRole.jury:
        return const UserPermissions(
          canCreateVersions: false,
          canPublishContent: false,
          canValidateAccounts: false,
          canDelete: false,
          canModify: false,
          canModifyVersions: false,
          canAssignRoles: false,
          canViewContent: true,
        );
      case UserRole.member:
        return const UserPermissions(
          canCreateVersions: false,
          canPublishContent: false,
          canValidateAccounts: false,
          canDelete: false,
          canModify: false,
          canModifyVersions: false,
          canAssignRoles: false,
          canViewContent: true,
        );
    }
  }

  static UserPermissions withOverrides(
    UserPermissions base,
    Map<String, dynamic> overrides,
  ) {
    bool resolve(String key, bool fallback) {
      final value = overrides[key];
      if (value is bool) return value;
      if (value is int) return value != 0;
      return fallback;
    }

    return UserPermissions(
      canCreateVersions:
          resolve('can_create_versions', base.canCreateVersions),
      canPublishContent:
          resolve('can_publish_content', base.canPublishContent),
      canValidateAccounts:
          resolve('can_validate_accounts', base.canValidateAccounts),
      canDelete: resolve('can_delete', base.canDelete),
      canModify: resolve('can_modify', base.canModify),
      canModifyVersions:
          resolve('can_modify_versions', base.canModifyVersions),
      canAssignRoles:
          resolve('can_assign_roles', base.canAssignRoles),
      canViewContent: resolve('can_view_content', base.canViewContent),
    );
  }
}
