import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/permission_service.dart';

class RoleGuard extends StatelessWidget {
  final Widget child;
  final bool Function() permissionCheck;
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
  Widget build(BuildContext context) {
    if (permissionCheck()) {
      return child;
    }

    if (fallbackWidget != null) {
      return fallbackWidget!;
    }

    return const SizedBox.shrink();
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
