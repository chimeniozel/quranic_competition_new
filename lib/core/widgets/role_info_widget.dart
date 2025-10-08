import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/user_role.dart';

class RoleInfoWidget extends StatelessWidget {
  final bool showDetails;
  final bool compact;

  const RoleInfoWidget({
    super.key,
    this.showDetails = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService = PermissionService();
    final role = permissionService.currentUserRole;
    final permissions = permissionService.currentPermissions;

    if (role == null || permissions == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getRoleColor(role).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getRoleColor(role).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              permissionService.getRoleDisplayName(),
              style: TextStyle(
                color: _getRoleColor(role),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                permissionService.getRoleDisplayName(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(role),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getRoleDescription(role),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          if (showDetails) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'الصلاحيات المتاحة:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ..._buildPermissionList(permissions),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPermissionList(UserPermissions permissions) {
    final permissionItems = [
      ('إنشاء نسخ المسابقات', permissions.canCreateVersions),
      ('نشر المحتوى', permissions.canPublishContent),
      ('التحقق من الحسابات', permissions.canValidateAccounts),
      ('حذف العناصر', permissions.canDelete),
      ('تعديل العناصر', permissions.canModify),
      ('تعديل نسخ المسابقات', permissions.canModifyVersions),
      ('تعيين الأدوار', permissions.canAssignRoles),
      ('عرض المحتوى', permissions.canViewContent),
    ];

    return permissionItems.map((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              item.$2 ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: item.$2 ? Colors.green[600] : Colors.red[400],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.$1,
                style: TextStyle(
                  fontSize: 14,
                  color: item.$2 ? Colors.green[700] : Colors.red[600],
                  fontWeight: item.$2 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple[600]!;
      case UserRole.admin:
        return Colors.blue[600]!;
      case UserRole.jury:
        return Colors.orange[600]!;
      case UserRole.member:
        return Colors.grey[600]!;
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'صلاحيات كاملة على النظام';
      case UserRole.admin:
        return 'صلاحيات إدارية محدودة';
      case UserRole.jury:
        return 'صلاحيات تقييم المشاركات';
      case UserRole.member:
        return 'عضو عادي بدون صلاحيات إدارية';
    }
  }
}

// Widget compact pour la barre d'outils
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleInfoWidget(compact: true);
  }
}

// Widget pour le profil utilisateur
class UserProfileRoleInfo extends StatelessWidget {
  const UserProfileRoleInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleInfoWidget(showDetails: true);
  }
}
