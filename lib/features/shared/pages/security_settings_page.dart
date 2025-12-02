import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/ui_components.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _authService = AuthService();
  final _errorService = ErrorService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      final user = await _authService.getUserProfile();
      if (user != null) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmDialog(
      'تسجيل الخروج',
      'هل أنت متأكد من أنك تريد تسجيل الخروج؟',
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        _showErrorDialog(_errorService.analyzeException(e));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      'حذف الحساب',
      'هل أنت متأكد من أنك تريد حذف حسابك نهائياً؟\n\nهذا الإجراء لا يمكن التراجع عنه.',
    );

    if (confirmed == true) {
      final doubleConfirmed = await _showConfirmDialog(
        'تأكيد نهائي',
        'اكتب "حذف" لتأكيد حذف الحساب نهائياً:',
      );

      if (doubleConfirmed == true) {
        try {
          // Dans une vraie application, vous auriez une API pour supprimer le compte
          _showErrorDialog(
            'هذه الميزة غير متاحة حالياً. يرجى التواصل مع الدعم الفني.',
          );
        } catch (e) {
          _showErrorDialog(_errorService.analyzeException(e));
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) async {
    return ModernDialog.showConfirm(context, title: title, message: content);
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(context, title: 'خطأ', message: error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الأمان'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Paramètres de sécurité
                    _buildSecuritySettings(),
                    const SizedBox(height: 24),

                    // Sessions actives
                    _buildActiveSessions(),
                    const SizedBox(height: 24),

                    // Actions dangereuses
                    _buildDangerZone(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.security, size: 60, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'مركز الأمان',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'إدارة إعدادات الأمان الخاصة بحسابك',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
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
                Icon(Icons.lock_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'إعدادات الأمان',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Changer le mot de passe
            _buildSecurityItem(
              icon: Icons.lock_reset,
              title: 'تغيير كلمة المرور',
              subtitle: 'تحديث كلمة المرور لحماية حسابك',
              onTap: () => context.push('/change-password'),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            // Authentification à deux facteurs (future)
            _buildSecurityItem(
              icon: Icons.phone_android,
              title: 'المصادقة الثنائية',
              subtitle: 'حماية إضافية لحسابك (قريباً)',
              onTap: () => _showComingSoonDialog(),
              color: Colors.orange,
              isEnabled: false,
            ),
            const SizedBox(height: 12),

            // Notifications de sécurité
            _buildSecurityItem(
              icon: Icons.notifications,
              title: 'إشعارات الأمان',
              subtitle: 'تلقي تنبيهات حول نشاط الحساب',
              onTap: () => _showComingSoonDialog(),
              color: Colors.green,
              isEnabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
              : const Icon(Icons.lock, size: 16, color: Colors.grey),
      onTap: isEnabled ? onTap : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isEnabled ? null : Colors.grey.shade50,
    );
  }

  Widget _buildActiveSessions() {
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
                Icon(Icons.devices, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'الجلسات النشطة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Session actuelle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'هذا الجهاز',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'متصل الآن',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'نشط',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
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
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'المنطقة الخطيرة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Déconnexion
            _buildDangerItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              subtitle: 'إنهاء الجلسة الحالية',
              onTap: _logout,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            // Supprimer le compte
            _buildDangerItem(
              icon: Icons.delete_forever,
              title: 'حذف الحساب',
              subtitle: 'حذف الحساب نهائياً (لا يمكن التراجع)',
              onTap: _deleteAccount,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: color.withOpacity(0.7))),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: color.withOpacity(0.05),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('قريباً'),
            ],
          ),
          content: const Text('هذه الميزة ستكون متاحة قريباً'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }
}
