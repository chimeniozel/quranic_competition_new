import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/delete_account_dialog.dart';
import '../../../core/widgets/ui_components.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  Future<void> _logout() => confirmAndSignOut(context);

  void _showComingSoon() {
    ModernDialog.showInfo(
      context,
      title: 'قريباً',
      message: 'هذه الميزة ستكون متاحة قريباً',
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool comingSoon = false,
  }) {
    final effectiveColor = comingSoon ? AppTheme.textDisabledColor : color;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXS,
      ),
      leading: AppIconBadge(icon: icon, color: effectiveColor, size: 18),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          color:
              comingSoon
                  ? AppTheme.textDisabledColor
                  : color == AppTheme.primaryColor
                  ? AppTheme.textPrimaryColor
                  : color,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      trailing:
          comingSoon
              ? const AppTag(text: 'قريباً', color: AppTheme.textDisabledColor)
              : const Icon(
                Icons.chevron_left_rounded,
                color: AppTheme.textSecondaryColor,
              ),
      onTap: comingSoon ? _showComingSoon : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الأمان')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const AppGradientHeader(
            icon: Icons.security_rounded,
            title: 'مركز الأمان',
            subtitle: 'إدارة إعدادات الأمان الخاصة بحسابك',
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  icon: Icons.lock_outline_rounded,
                  title: 'إعدادات الأمان',
                  child: Column(
                    children: [
                      _buildAction(
                        icon: Icons.lock_reset_rounded,
                        title: 'تغيير كلمة المرور',
                        subtitle: 'تحديث كلمة المرور لحماية حسابك',
                        color: AppTheme.primaryColor,
                        onTap: () => context.push('/change-password'),
                      ),
                      const Divider(),
                      _buildAction(
                        icon: Icons.phone_android_rounded,
                        title: 'المصادقة الثنائية',
                        subtitle: 'حماية إضافية لحسابك',
                        color: AppTheme.warningColor,
                        onTap: _showComingSoon,
                        comingSoon: true,
                      ),
                      const Divider(),
                      _buildAction(
                        icon: Icons.notifications_rounded,
                        title: 'إشعارات الأمان',
                        subtitle: 'تلقي تنبيهات حول نشاط الحساب',
                        color: AppTheme.successColor,
                        onTap: _showComingSoon,
                        comingSoon: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                AppSection(
                  icon: Icons.devices_rounded,
                  color: AppTheme.infoColor,
                  title: 'الجلسات النشطة',
                  child: Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.phone_android_rounded,
                        color: AppTheme.successColor,
                        size: 18,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          'هذا الجهاز',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const AppTag(
                        text: 'نشط الآن',
                        color: AppTheme.successColor,
                        icon: Icons.circle_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                AppSection(
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                  title: 'منطقة الخطر',
                  borderColor: AppTheme.errorColor,
                  child: Column(
                    children: [
                      _buildAction(
                        icon: Icons.logout_rounded,
                        title: 'تسجيل الخروج',
                        subtitle: 'إنهاء الجلسة الحالية',
                        color: AppTheme.warningColor,
                        onTap: _logout,
                      ),
                      const Divider(),
                      _buildAction(
                        icon: Icons.delete_forever_rounded,
                        title: 'حذف الحساب',
                        subtitle: 'حذف الحساب نهائياً (لا يمكن التراجع)',
                        color: AppTheme.errorColor,
                        onTap: () => confirmAndDeleteAccount(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
