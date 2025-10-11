import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/app_user.dart';

/// Widget réutilisable pour afficher les paramètres de sécurité
class SecuritySettingsWidget extends StatelessWidget {
  final AppUser? currentUser;
  final VoidCallback? onRefresh;

  const SecuritySettingsWidget({super.key, this.currentUser, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'الأمان',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push('/security-settings'),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('الإعدادات'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Changer le mot de passe
            _buildSecurityItem(
              context,
              icon: Icons.lock_reset,
              title: 'تغيير كلمة المرور',
              subtitle: 'تحديث كلمة المرور لحماية حسابك',
              onTap: () => context.push('/change-password'),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            // Statut de validation
            if (currentUser != null)
              _buildSecurityItem(
                context,
                icon:
                    currentUser!.isVerified
                        ? Icons.verified_user
                        : Icons.pending,
                title: 'حالة الحساب',
                subtitle:
                    currentUser!.isVerified
                        ? 'حسابك موثق ومحمي'
                        : 'في انتظار التوثيق من الإدارة',
                onTap: null,
                color: currentUser!.isVerified ? Colors.green : Colors.orange,
                isEnabled: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
    bool isEnabled = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isEnabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isEnabled ? Colors.grey.shade600 : Colors.grey),
      ),
      trailing:
          isEnabled
              ? const Icon(Icons.arrow_forward_ios, size: 16)
              : Icon(
                isEnabled ? Icons.arrow_forward_ios : Icons.check,
                size: 16,
                color: isEnabled ? null : color,
              ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isEnabled ? null : color.withOpacity(0.05),
    );
  }
}

/// Widget pour afficher les informations de profil de manière compacte
class ProfileInfoWidget extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onEdit;

  const ProfileInfoWidget({super.key, required this.user, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'المعلومات الشخصية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'تعديل',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Avatar et nom
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRoleDisplayName(user.role),
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Informations de contact
            _buildInfoRow(Icons.email, 'البريد الإلكتروني', user.email),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'الهاتف', user.phone),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'تاريخ الإنشاء',
              _formatDate(user.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        return 'عضو لجنة التحكيم';
      case 'membre':
        return 'عضو عادي';
      default:
        return 'غير محدد';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'jury':
        return Colors.blue;
      case 'membre':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Widget pour afficher un menu de profil rapide
class ProfileQuickMenu extends StatelessWidget {
  final AppUser? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSecurityTap;
  final VoidCallback? onSettingsTap;

  const ProfileQuickMenu({
    super.key,
    this.user,
    this.onProfileTap,
    this.onSecurityTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header avec avatar
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'المستخدم',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user != null
                          ? _getRoleDisplayName(user!.role)
                          : 'غير محدد',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Menu items
          _buildMenuItem(
            context,
            icon: Icons.person,
            title: 'الملف الشخصي',
            onTap: onProfileTap ?? () => context.push('/profile'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.security,
            title: 'الأمان',
            onTap: onSecurityTap ?? () => context.push('/security-settings'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'الإعدادات',
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
