import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';

class RoleInfoWidget extends StatefulWidget {
  final bool showDetails;
  final bool compact;

  const RoleInfoWidget({
    super.key,
    this.showDetails = false,
    this.compact = false,
  });

  @override
  State<RoleInfoWidget> createState() => _RoleInfoWidgetState();
}

class _RoleInfoWidgetState extends State<RoleInfoWidget> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await AuthService().getUserProfile();
      if (mounted) {
        setState(() {
          _userRole = user?.role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // إرجاع widget فارغ بدلاً من CircularProgressIndicator لتجنب التأخير
      // سيتم تحديثه تلقائياً عند تحميل البيانات
      return const SizedBox.shrink();
    }

    if (_userRole == null) {
      return const SizedBox.shrink();
    }

    final role = UserRole.fromString(_userRole!);

    if (widget.compact) {
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
              role.displayName,
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

    return ModernCard(
      backgroundColor: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(8),
      child: Container(
        height: widget.showDetails ? null : 50,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(
                _getRoleIcon(role),
                color: _getRoleColor(role),
                size: 16,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    role.displayName,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(role),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getRoleDescription(role),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!widget.showDetails)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'نشط',
                  style: AppTheme.bodySmall.copyWith(
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return AppTheme.warningColor;
      case UserRole.admin:
        return AppTheme.primaryColor;
      case UserRole.jury:
        return AppTheme.infoColor;
      case UserRole.member:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings;
      case UserRole.admin:
        return Icons.manage_accounts;
      case UserRole.jury:
        return Icons.gavel;
      case UserRole.member:
        return Icons.person;
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
