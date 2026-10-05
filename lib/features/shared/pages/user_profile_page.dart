import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/delete_account_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/services/unified_user_service.dart';
import '../../../models/app_user.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _authService = AuthService();
  final _errorService = ErrorService();
  final _userService = UnifiedUserService();
  final _supabase = Supabase.instance.client;

  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      final user = await _authService.getUserProfile();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _fullNameController.text = user.fullName;
          _phoneController.text = user.phone;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorDialog('فشل في تحميل بيانات المستخدم');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      await _userService.updateUserProfile(
        userId,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      // Recharger le profil
      await _loadUserProfile();
      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      _showSuccessDialog('تم تحديث الملف الشخصي بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(context, title: 'خطأ', message: error);
  }

  void _showSuccessDialog(String message) {
    ModernDialog.showSuccess(context, title: 'نجح', message: message);
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (value.trim().length < 2) {
      return _errorService.getErrorMessage('VALIDATION_TOO_SHORT');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidPhone(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_PHONE');
    }
    return null;
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{8,15}$').hasMatch(phone);
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

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.admin_panel_settings_rounded;
      case 'admin':
        return Icons.settings_rounded;
      case 'jury':
        return Icons.gavel_rounded;
      case 'membre':
      case 'membre_ordinaire':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      // Restaurer les valeurs originales
      _fullNameController.text = _currentUser!.fullName;
      _phoneController.text = _currentUser!.phone;
    });
  }

  Future<void> _logout() => confirmAndSignOut(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          if (_currentUser != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'تعديل',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body:
          _isLoading && _currentUser == null
              ? const Center(child: CircularProgressIndicator())
              : _currentUser == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppNotice(
                        text: 'تعذر تحميل بيانات المستخدم',
                        color: AppTheme.errorColor,
                        icon: Icons.error_outline_rounded,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      OutlinedButton.icon(
                        onPressed: _loadUserProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
              : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildProfileHeader(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPersonalInfoSection(),
                          const SizedBox(height: AppTheme.spacingM),
                          _buildAccountInfoSection(),
                          const SizedBox(height: AppTheme.spacingM),
                          _buildSecuritySection(),
                          const SizedBox(height: AppTheme.spacingL),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser!;
    final initial =
        user.fullName.trim().isNotEmpty
            ? user.fullName.trim().characters.first
            : '?';

    return AppGradientHeader(
      title: user.fullName.isNotEmpty ? user.fullName : 'بدون اسم',
      subtitle: _supabase.auth.currentUser?.email,
      leading: CircleAvatar(
        radius: 38,
        backgroundColor: Colors.white,
        child: Text(
          initial.toUpperCase(),
          style: AppTheme.headingLarge.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      badges: [
        AppHeaderBadge(
          icon: _getRoleIcon(user.role),
          text: _getRoleDisplayName(user.role),
        ),
        AppHeaderBadge(
          icon: user.isVerified ? Icons.verified_rounded : Icons.pending_rounded,
          text: user.isVerified ? 'حساب موثق' : 'بانتظار التوثيق',
          highlightColor: user.isVerified ? null : AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return AppSection(
      icon: Icons.person_outline_rounded,
      title: 'المعلومات الشخصية',
      subtitle: _isEditing ? 'عدّل بياناتك ثم احفظ' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _fullNameController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'الاسم الكامل',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            validator: _validateFullName,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _phoneController,
            enabled: _isEditing,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            validator: _validatePhone,
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _cancelEditing,
                    style: AppButtonStyles.outlined(
                      AppTheme.textSecondaryColor,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: AppButtonStyles.filled(AppTheme.primaryColor),
                    child:
                        _isSaving ? const AppButtonLoader() : const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection() {
    final user = _currentUser!;

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppSection(
      icon: Icons.info_outline_rounded,
      color: AppTheme.infoColor,
      title: 'معلومات الحساب',
      child: Column(
        children: [
          row(
            Icons.email_rounded,
            'البريد الإلكتروني',
            _supabase.auth.currentUser?.email ?? 'غير محدد',
          ),
          const Divider(),
          row(
            Icons.calendar_today_rounded,
            'تاريخ الإنشاء',
            _formatDate(user.createdAt),
          ),
          const Divider(),
          row(
            user.isVerified ? Icons.verified_rounded : Icons.pending_rounded,
            'حالة الحساب',
            user.isVerified ? 'موثق' : 'في انتظار التوثيق',
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    Widget action({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
    }) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXS,
        ),
        leading: AppIconBadge(icon: icon, color: color, size: 18),
        title: Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            color:
                color == AppTheme.primaryColor
                    ? AppTheme.textPrimaryColor
                    : color,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
        trailing: Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondaryColor),
        onTap: onTap,
      );
    }

    return AppSection(
      icon: Icons.shield_rounded,
      color: AppTheme.secondaryColor,
      title: 'الأمان والحساب',
      child: Column(
        children: [
          action(
            icon: Icons.lock_reset_rounded,
            title: 'تغيير كلمة المرور',
            subtitle: 'تحديث كلمة المرور لحماية حسابك',
            color: AppTheme.primaryColor,
            onTap: () => context.push('/change-password'),
          ),
          const Divider(),
          action(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            subtitle: 'إنهاء الجلسة على هذا الجهاز',
            color: AppTheme.warningColor,
            onTap: _logout,
          ),
          const Divider(),
          action(
            icon: Icons.delete_forever_rounded,
            title: 'حذف الحساب',
            subtitle: 'حذف الحساب نهائياً (لا يمكن التراجع)',
            color: AppTheme.errorColor,
            onTap: () => confirmAndDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
