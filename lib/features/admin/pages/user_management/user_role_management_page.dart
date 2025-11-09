import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRoleManagementPage extends StatefulWidget {
  const UserRoleManagementPage({super.key, required this.userId});

  final String userId;

  @override
  State<UserRoleManagementPage> createState() => _UserRoleManagementPageState();
}

class _UserRoleManagementPageState extends State<UserRoleManagementPage> {
  final _userService = UserManagementService();
  final _authService = AuthService();

  Map<String, dynamic>? _user;
  UserRole? _selectedRole;
  Map<String, bool> _permissions = {};
  Map<String, bool> _initialPermissions = {};

  bool _isLoading = true;
  bool _isSavingRole = false;
  bool _isSavingPermissions = false;
  bool? _isValidated;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _userService.getUserById(widget.userId);
      if (user == null) {
        setState(() {
          _errorMessage = 'المستخدم غير موجود أو تم حذفه.';
          _isLoading = false;
        });
        return;
      }

      final permissions = await _userService.getUserPermissions(widget.userId);
      final role = UserRole.fromString(user['role']);
      final basePermissions = _permissionsFromUserPermissions(
        UserPermissions.forRole(role),
      );

      setState(() {
        _user = user;
        _selectedRole = role == UserRole.superAdmin ? UserRole.admin : role;
        _permissions =
            permissions != null
                ? {
                  for (final entry in basePermissions.entries)
                    entry.key: permissions[entry.key] ?? entry.value,
                }
                : basePermissions;
        _initialPermissions = Map<String, bool>.from(_permissions);
        _isValidated = user['is_validated'] == true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر تحميل بيانات المستخدم: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, bool> _permissionsFromUserPermissions(
    UserPermissions permissions,
  ) {
    return {
      'can_create_versions': permissions.canCreateVersions,
      'can_publish_content': permissions.canPublishContent,
      'can_validate_accounts': permissions.canValidateAccounts,
      'can_delete': permissions.canDelete,
      'can_modify': permissions.canModify,
      'can_modify_versions': permissions.canModifyVersions,
      'can_assign_roles': permissions.canAssignRoles,
      'can_view_content': permissions.canViewContent,
    };
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null || _user == null) return;

    // Forbid promoting another user to super admin (except current user already super admin)
    final currentRole = UserRole.fromString(_user!['role'] ?? 'membre');
    if (_selectedRole == UserRole.superAdmin &&
        currentRole != UserRole.superAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن تعيين مستخدم كـ Super Admin من خلال هذه الواجهة',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSavingRole = true);

    try {
      await _userService.updateUserRole(_user!['id'], _selectedRole!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث دور المستخدم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (_user!['id'] == Supabase.instance.client.auth.currentUser?.id) {
        await _authService.initializeCurrentUserPermissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تحديث الدور: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingRole = false);
      }
    }
  }

  bool get _hasPermissionChanges {
    for (final entry in _permissions.entries) {
      if (_initialPermissions[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

  Future<void> _resetPermissions() async {
    if (_selectedRole == null) return;
    final defaults = _permissionsFromUserPermissions(
      UserPermissions.forRole(_selectedRole!),
    );
    setState(() {
      _permissions = defaults;
    });
  }

  Future<void> _savePermissions() async {
    if (_user == null || !_hasPermissionChanges) return;

    setState(() => _isSavingPermissions = true);

    try {
      await _userService.updateUserPermissions(_user!['id'], _permissions);
      _initialPermissions = Map<String, bool>.from(_permissions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصلاحيات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (_user!['id'] == Supabase.instance.client.auth.currentUser?.id) {
        await _authService.initializeCurrentUserPermissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ الصلاحيات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPermissions = false);
      }
    }
  }

  Future<void> _toggleValidationStatus() async {
    if (_user == null || _isValidated == null) return;

    final newStatus = !_isValidated!;

    final confirmed = await ConfirmationService.showCriticalActionConfirmation(
      context,
      title: newStatus ? 'توثيق المستخدم' : 'إلغاء توثيق المستخدم',
      message:
          'هل أنت متأكد من ${newStatus ? 'توثيق' : 'إلغاء توثيق'} المستخدم ${_user!['email']}؟',
      actionType: 'تغيير حالة التحقق',
    );

    if (!confirmed) return;

    try {
      await _userService.updateUserVerificationStatus(_user!['id'], newStatus);

      setState(() {
        _isValidated = newStatus;
        _user!['is_validated'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'تم توثيق المستخدم بنجاح' : 'تم إلغاء توثيق المستخدم',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تغيير حالة التحقق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة دور المستخدم'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = _user!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(user),
            const SizedBox(height: AppTheme.spacingS),
            _buildValidationSection(),
            const SizedBox(height: AppTheme.spacingS),
            _buildRoleSection(),
            const SizedBox(height: AppTheme.spacingS),
            if (_selectedRole == UserRole.admin ||
                _selectedRole == UserRole.superAdmin)
              _buildPermissionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic> user) {
    return Card(
      elevation: AppTheme.elevationM,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? user['email'] ?? 'بدون اسم',
                        style: AppTheme.headingMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        user['email'] ?? 'لا يوجد بريد إلكتروني',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: [
                _buildInfoChip('الدور الحالي', user['role_display_name']),
                _buildInfoChip(
                  'موثق',
                  user['is_validated'] == true ? 'نعم' : 'لا',
                  color:
                      user['is_validated'] == true
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                ),
                if (user['phone'] != null &&
                    user['phone'].toString().isNotEmpty)
                  _buildInfoChip('الهاتف', user['phone']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, dynamic value, {Color? color}) {
    final displayValue = value?.toString() ?? 'غير متوفر';
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            displayValue,
            style: AppTheme.bodySmall.copyWith(
              color: color ?? AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      backgroundColor: color?.withOpacity(0.08) ?? AppTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
    );
  }

  Widget _buildRoleSection() {
    return Card(
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'تغيير الدور',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'اختر الدور الجديد',
                border: OutlineInputBorder(),
              ),
              items:
                  UserRole.values
                      .map(
                        (role) => DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.displayName),
                        ),
                      )
                      .where((entry) => entry.value != UserRole.superAdmin)
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingS),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSavingRole ? null : _saveRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isSavingRole
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('حفظ الدور'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Card(
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(Icons.tune, color: AppTheme.infoColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'الصلاحيات التفصيلية',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            ..._buildPermissionSwitches(context),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetPermissions,
                    child: const Text('استعادة الافتراضي'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isSavingPermissions || !_hasPermissionChanges
                            ? null
                            : _savePermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _isSavingPermissions
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('حفظ الصلاحيات'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPermissionSwitches(BuildContext context) {
    final theme = Theme.of(context);
    const permissionDefinitions = [
      (
        key: 'can_create_versions',
        title: 'إنشاء نسخ جديدة',
        description: 'السماح بإنشاء نسخ جديدة من المسابقة وإدارتها.',
      ),
      (
        key: 'can_modify_versions',
        title: 'تعديل النسخ',
        description: 'السماح بتعديل إعدادات النسخ الحالية وقواعدها.',
      ),
      (
        key: 'can_publish_content',
        title: 'نشر المحتوى',
        description: 'إدارة ونشر الفوائد القرآنية، قواعد التجويد، والأرشيف.',
      ),
      (
        key: 'can_validate_accounts',
        title: 'توثيق الحسابات',
        description: 'الموافقة على حسابات المستخدمين الجدد وتوثيقهم.',
      ),
      (
        key: 'can_assign_roles',
        title: 'تعيين الأدوار',
        description: 'تغيير دور المستخدمين الآخرين (مدير، محكم...).',
      ),
      (
        key: 'can_delete',
        title: 'حذف العناصر',
        description: 'السماح بحذف البيانات أو المحتوى من لوحة الإدارة.',
      ),
      (
        key: 'can_modify',
        title: 'تعديل العناصر',
        description: 'تعديل بيانات المشاركين، المحتوى، أو الإعدادات.',
      ),
      (
        key: 'can_view_content',
        title: 'عرض المحتوى الإداري',
        description: 'الوصول إلى صفحات الإدارة دون القدرة على التعديل.',
      ),
    ];

    return permissionDefinitions.map((definition) {
      final value = _permissions[definition.key] ?? false;
      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.dividerColor.withOpacity(0.6)),
        ),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: (newValue) {
            setState(() {
              _permissions[definition.key] = newValue;
            });
          },
          title: Text(
            definition.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          subtitle: Text(
            definition.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          activeColor: AppTheme.primaryColor,
        ),
      );
    }).toList();
  }

  Widget _buildValidationSection() {
    final isValidated = _isValidated == true;

    return Card(
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    color:
                        isValidated
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    isValidated ? Icons.verified : Icons.pending,
                    color:
                        isValidated
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'حالة التحقق',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color:
                    isValidated
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color:
                      isValidated
                          ? AppTheme.successColor.withOpacity(0.3)
                          : AppTheme.warningColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isValidated ? Icons.verified : Icons.hourglass_top,
                    color:
                        isValidated
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      isValidated
                          ? 'هذا المستخدم موثق حالياً. يمكنه الوصول إلى اللوحة وفق صلاحياته.'
                          : 'هذا المستخدم غير موثق. لن يتمكن من الوصول الكامل حتى يتم توثيقه.',
                      style: AppTheme.bodySmall.copyWith(
                        color:
                            isValidated
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _toggleValidationStatus,
                icon: Icon(isValidated ? Icons.block : Icons.verified_user),
                label: Text(isValidated ? 'إلغاء التوثيق' : 'توثيق المستخدم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isValidated
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
