import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/permission_service.dart';

// Import pour استخدام PermissionService في _checkPermissionSync

class RoleGuard extends StatefulWidget {
  final Widget child;
  final Future<bool> Function() permissionCheck;
  final Widget? fallbackWidget;
  final String? permissionName;

  const RoleGuard({
    super.key,
    required this.child,
    required this.permissionCheck,
    this.fallbackWidget,
    this.permissionName,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool? _hasPermission;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // محاولة استخدام cache أولاً (للتسريع)
    _checkPermissionSync();
    // ثم التحقق من الصلاحيات بشكل كامل
    _checkPermission();
  }

  void _checkPermissionSync() {
    // محاولة استخدام cache للصلاحيات إذا كانت متوفرة
    // هذا يقلل من التأخير في العرض الأولي
    // لكن التحقق الكامل سيتم في _checkPermission()
  }

  Future<void> _checkPermission() async {
    try {
      // التحقق من الصلاحيات (سيستخدم cache إذا كان متوفراً)
      final hasPermission = await widget.permissionCheck();
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isLoading = false;
        });
      }
    } catch (e) {
      // في حالة الخطأ، افترض عدم وجود صلاحية
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // إرجاع widget فارغ شفاف بدلاً من SizedBox.shrink() لتجنب الصفحة السوداء
      // العناصر الصغيرة مثل الأزرار والقوائم لا تحتاج loading indicator
      return const SizedBox(width: 0, height: 0);
    }

    if (_hasPermission == true) {
      return widget.child;
    }

    if (widget.fallbackWidget != null) {
      return widget.fallbackWidget!;
    }

    return const SizedBox(width: 0, height: 0);
  }
}

// Widgets spécialisés pour chaque type de permission
class CanCreateVersionsGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanCreateVersionsGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canCreateVersions(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanPublishContentGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanPublishContentGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canPublishContent(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanDeleteGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanDeleteGuard({super.key, required this.child, this.fallbackWidget});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canDelete(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanModifyGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanModifyGuard({super.key, required this.child, this.fallbackWidget});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canModify(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanModifyVersionsGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanModifyVersionsGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canModifyVersions(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanAssignRolesGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanAssignRolesGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canAssignRoles(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class CanValidateAccountsGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const CanValidateAccountsGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().canValidateAccounts(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}

class HasAdminPermissionsGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const HasAdminPermissionsGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      permissionCheck: () => PermissionService().hasAdminPermissions(),
      fallbackWidget: fallbackWidget,
      child: child,
    );
  }
}
