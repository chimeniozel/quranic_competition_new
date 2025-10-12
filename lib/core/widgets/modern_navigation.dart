import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

/// Navigation moderne avec design Material 3

/// AppBar moderne avec actions personnalisées
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool automaticallyImplyLeading;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? Colors.white,
        ),
      ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              backgroundColor ?? AppTheme.primaryColor,
              (backgroundColor ?? AppTheme.primaryColor).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Menu de profil moderne dans l'AppBar
class ProfileMenuButton extends StatelessWidget {
  final String? userImage;
  final String? userName;
  final String? userRole;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSecurityTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;

  const ProfileMenuButton({
    super.key,
    this.userImage,
    this.userName,
    this.userRole,
    this.onProfileTap,
    this.onSecurityTap,
    this.onSettingsTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onProfileTap?.call();
            if (onProfileTap == null) context.push('/profile');
            break;
          case 'security':
            onSecurityTap?.call();
            if (onSecurityTap == null) context.push('/security-settings');
            break;
          case 'settings':
            onSettingsTap?.call();
            break;
          case 'logout':
            onLogoutTap?.call();
            break;
        }
      },
      itemBuilder:
          (context) => [
            // Header avec informations utilisateur
            PopupMenuItem<String>(
              enabled: false,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CustomAvatar(
                          imageUrl: userImage,
                          initials: userName,
                          size: 32,
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName ?? 'المستخدم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (userRole != null)
                                Text(
                                  _getRoleDisplayName(userRole!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),

            // Menu items
            PopupMenuItem(
              value: 'profile',
              child: const ListTile(
                leading: Icon(Icons.person, size: 20),
                title: Text('الملف الشخصي'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'security',
              child: const ListTile(
                leading: Icon(Icons.security, size: 20),
                title: Text('الأمان'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: const ListTile(
                leading: Icon(Icons.settings, size: 20),
                title: Text('الإعدادات'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  size: 20,
                  color: AppTheme.errorColor,
                ),
                title: Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomAvatar(imageUrl: userImage, initials: userName, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'مدير عام';
      case 'admin':
        return 'مدير';
      case 'jury':
        return 'عضو لجنة التحكيم';
      case 'membre':
        return 'عضو عادي';
      default:
        return 'غير محدد';
    }
  }
}

/// Bottom Navigation moderne
class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<BottomNavigationItem> items;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.shadowL,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusL),
          topRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = currentIndex == index;

                  return GestureDetector(
                    onTap: () => onTap?.call(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color:
                                  isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Item pour la navigation bottom
class BottomNavigationItem {
  final IconData icon;
  final String label;
  final String? route;

  const BottomNavigationItem({
    required this.icon,
    required this.label,
    this.route,
  });
}

/// Drawer moderne avec navigation
class ModernDrawer extends StatelessWidget {
  final String? userName;
  final String? userRole;
  final String? userEmail;
  final Widget? header;
  final List<DrawerItem> items;
  final List<DrawerItem>? footerItems;

  const ModernDrawer({
    super.key,
    this.userName,
    this.userRole,
    this.userEmail,
    this.header,
    required this.items,
    this.footerItems,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header
          if (header != null) header! else _buildDefaultHeader(),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...items.map((item) => _buildDrawerItem(item, context)),

                if (footerItems != null) ...[
                  const Divider(),
                  ...footerItems!.map(
                    (item) => _buildDrawerItem(item, context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 48,
        left: AppTheme.spacingM,
        right: AppTheme.spacingM,
        bottom: AppTheme.spacingM,
      ),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomAvatar(
                  initials: userName,
                  size: 48,
                  backgroundColor: Colors.white,
                  textColor: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName ?? 'المستخدم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (userRole != null)
                        Text(
                          _getRoleDisplayName(userRole!),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      if (userEmail != null)
                        Text(
                          userEmail!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(DrawerItem item, BuildContext context) {
    return ListTile(
      leading: Icon(
        item.icon,
        color:
            item.isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color:
              item.isActive ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
          fontWeight: item.isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing:
          item.badge != null
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      onTap: () {
        Navigator.pop(context);
        item.onTap?.call();
      },
      selected: item.isActive,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'مدير عام';
      case 'admin':
        return 'مدير';
      case 'jury':
        return 'عضو لجنة التحكيم';
      case 'membre':
        return 'عضو عادي';
      default:
        return 'غير محدد';
    }
  }
}

/// Item pour le drawer
class DrawerItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final String? badge;

  const DrawerItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.badge,
  });
}

/// Floating Action Button moderne
class ModernFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ModernFAB({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: AppTheme.elevationM,
      child: Icon(icon),
    );
  }
}

/// Backdrop moderne pour les modals
class ModernBackdrop extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  const ModernBackdrop({
    super.key,
    required this.child,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.black54,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
