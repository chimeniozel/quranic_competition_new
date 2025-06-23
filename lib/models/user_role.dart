class UserRole {
  final String name;
  final bool canDelete;
  final bool canEdit;
  final bool canPublish;
  final bool canEndVersion;
  final bool canVerifyAccounts;

  UserRole({
    required this.name,
    required this.canDelete,
    required this.canEdit,
    required this.canPublish,
    required this.canEndVersion,
    required this.canVerifyAccounts,
  });

  factory UserRole.fromMap(Map<String, dynamic> map) {
    return UserRole(
      name: map['name'],
      canDelete: map['can_delete'],
      canEdit: map['can_edit'],
      canPublish: map['can_publish'],
      canEndVersion: map['can_end_version'],
      canVerifyAccounts: map['can_verify_accounts'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'can_delete': canDelete,
      'can_edit': canEdit,
      'can_publish': canPublish,
      'can_end_version': canEndVersion,
      'can_verify_accounts': canVerifyAccounts,
    };
  }
}
