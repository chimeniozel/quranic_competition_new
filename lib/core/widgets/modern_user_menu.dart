import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

/// Menu utilisateur moderne avec avatar et options
class ModernUserMenu extends StatelessWidget {
  final String userName;
  final String? userEmail;
  final String? userRole;
  final String? avatarUrl;
  final List<UserMenuOption> options;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  const ModernUserMenu({
    super.key,
    required this.userName,
    this.userEmail,
    this.userRole,
    this.avatarUrl,
    required this.options,
    this.onProfileTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header utilisateur
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusL),
              topRight: Radius.circular(AppTheme.radiusL),
            ),
          ),
          child: Row(
            children: [
              CustomAvatar(
                initials: userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                imageUrl: avatarUrl,
                size: 50,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTheme.headingSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userEmail != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        userEmail!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (userRole != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingS,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(userRole!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Text(
                          _getRoleDisplayName(userRole!),
                          style: AppTheme.bodySmall.copyWith(
                            color: _getRoleColor(userRole!),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Options du menu
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusL),
              bottomRight: Radius.circular(AppTheme.radiusL),
            ),
          ),
          child: Column(
            children:
                options.map((option) {
                  return UserMenuItem(
                    option: option,
                    onTap: () {
                      if (option.onTap != null) {
                        option.onTap!();
                      }
                    },
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'مدير عام';
      case 'admin':
        return 'مدير';
      case 'jury':
        return 'عضو لجنة';
      case 'membre':
        return 'عضو';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return AppTheme.warningColor;
      case 'admin':
        return AppTheme.successColor;
      case 'jury':
        return AppTheme.infoColor;
      case 'membre':
        return AppTheme.textSecondaryColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }
}

/// Élément du menu utilisateur
class UserMenuItem extends StatelessWidget {
  final UserMenuOption option;
  final VoidCallback? onTap;

  const UserMenuItem({super.key, required this.option, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: option.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(option.icon, color: option.color, size: 20),
        ),
        title: Text(
          option.title,
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle:
            option.subtitle != null
                ? Text(
                  option.subtitle!,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                )
                : null,
        trailing:
            option.badge != null
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: option.badgeColor ?? AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    option.badge!,
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                : const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingS,
        ),
      ),
    );
  }
}

/// Option du menu utilisateur
class UserMenuOption {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;

  const UserMenuOption({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.badge,
    this.badgeColor,
  });
}

/// Menu contextuel moderne pour les actions rapides
class ModernContextMenu extends StatelessWidget {
  final List<ContextMenuItem> items;
  final String? title;

  const ModernContextMenu({super.key, required this.items, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) => _buildMenuItem(context, item)).toList(),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: Icon(item.icon, color: item.color, size: 16),
      ),
      title: Text(item.title, style: AppTheme.bodyMedium),
      trailing:
          item.badge != null
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: item.badgeColor ?? AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  item.badge!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      onTap: item.isEnabled ? item.onTap : null,
      enabled: item.isEnabled,
    );
  }

  static Future<void> show({
    required BuildContext context,
    required List<ContextMenuItem> items,
    String? title,
    Offset? position,
  }) {
    return showMenu<ContextMenuItem>(
      context: context,
      position: RelativeRect.fromLTRB(
        position?.dx ?? MediaQuery.of(context).size.width / 2,
        position?.dy ?? MediaQuery.of(context).size.height / 2,
        0,
        0,
      ),
      items:
          items
              .map(
                (item) => PopupMenuItem<ContextMenuItem>(
                  value: item,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Icon(item.icon, color: item.color, size: 16),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(item.title, style: AppTheme.bodyMedium),
                      ),
                      if (item.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.badgeColor ?? AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: Text(
                            item.badge!,
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

/// Élément du menu contextuel
class ContextMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;
  final bool isEnabled;

  const ContextMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
    this.badge,
    this.badgeColor,
    this.isEnabled = true,
  });
}

/// Widget de profil utilisateur compact
class UserProfileCompact extends StatelessWidget {
  final String userName;
  final String? userEmail;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final bool showArrow;

  const UserProfileCompact({
    super.key,
    required this.userName,
    this.userEmail,
    this.avatarUrl,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.dividerColor, width: 1),
        ),
        child: Row(
          children: [
            CustomAvatar(
              initials: userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              imageUrl: avatarUrl,
              size: 40,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userEmail != null) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      userEmail!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (showArrow && onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
