import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/features/shared/pages/access_denied_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class UserPermissionsBottomSheet extends StatefulWidget {
  const UserPermissionsBottomSheet({
    super.key,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.userService,
  });

  final String userId;
  final String email;
  final String fullName;
  final UserRole role;
  final UserManagementService userService;

  @override
  State<UserPermissionsBottomSheet> createState() =>
      _UserPermissionsBottomSheetState();
}

class _UserPermissionsBottomSheetState
    extends State<UserPermissionsBottomSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  late Map<String, bool> _permissions;
  late Map<String, bool> _initialPermissions;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);

    try {
      final fetched = await widget.userService.getUserPermissions(
        widget.userId,
      );
      final base = UserPermissions.forRole(widget.role);
      final defaults = _permissionsFromUserPermissions(base);

      if (fetched != null) {
        _permissions = {
          for (final entry in defaults.entries)
            entry.key: fetched[entry.key] ?? entry.value,
        };
      } else {
        _permissions = defaults;
      }

      _initialPermissions = Map<String, bool>.from(_permissions);
    } catch (e) {
      _permissions = _permissionsFromUserPermissions(
        UserPermissions.forRole(widget.role),
      );
      _initialPermissions = Map<String, bool>.from(_permissions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل الصلاحيات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasChanges {
    for (final entry in _permissions.entries) {
      if (_initialPermissions[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
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

  Future<void> _resetToDefaults() async {
    final defaults = _permissionsFromUserPermissions(
      UserPermissions.forRole(widget.role),
    );
    setState(() {
      _permissions = defaults;
    });
  }

  Future<void> _savePermissions() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await widget.userService.updateUserPermissions(
        widget.userId,
        _permissions,
      );

      _initialPermissions = Map<String, bool>.from(_permissions);

      if (mounted) {
        Navigator.of(context).pop(true);
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusXL),
            topRight: Radius.circular(AppTheme.radiusXL),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        child: const Icon(Icons.tune, color: Colors.white),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إدارة صلاحيات المستخدم',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              widget.fullName.isNotEmpty
                                  ? '${widget.fullName}\n${widget.email}'
                                  : widget.email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingS),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        ..._buildPermissionSwitches(theme),
                        const SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _isSaving ? null : () => _resetToDefaults(),
                                child: const Text(
                                  'استعادة الصلاحيات الافتراضية',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving || !_hasChanges
                                        ? null
                                        : _savePermissions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingS,
                                  ),
                                ),
                                child:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Text('حفظ التغييرات'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPermissionSwitches(ThemeData theme) {
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
        description: 'إدارة ونشر الفوائد القرآنية، أحكام التجويد، والأرشيف.',
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
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementService _userService = UserManagementService();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedValidationFilter = 'all'; // all, validated, unvalidated
  bool? _isAdmin;
  bool _isSummaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final isAdmin = await PermissionService().isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });

    if (isAdmin) {
      _loadUsers();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    if (_isAdmin != true) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _userService.getAllUsers();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المستخدمين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users;

    // Filtrer par recherche (nom ou email)
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((user) {
            final email = user['email']?.toString().toLowerCase() ?? '';
            final fullName = user['full_name']?.toString().toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();

            return email.contains(query) || fullName.contains(query);
          }).toList();
    }

    // Filtrer par rôle
    if (_selectedRoleFilter != 'all') {
      filtered =
          filtered
              .where((user) => user['role'] == _selectedRoleFilter)
              .toList();
    }

    // Filtrer par حالة التحقق
    if (_selectedValidationFilter != 'all') {
      filtered =
          filtered.where((user) {
            final isValidated = user['is_validated'] == true;
            if (_selectedValidationFilter == 'validated') {
              return isValidated;
            } else if (_selectedValidationFilter == 'unvalidated') {
              return !isValidated;
            }
            return true;
          }).toList();
    }

    return filtered;
  }

  Future<void> _openUserManagement(Map<String, dynamic> user) async {
    if (!mounted) return;

    // Vérifier الصلاحيات
    final canAssignRoles = await PermissionService().canAssignRoles();
    if (!canAssignRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية إدارة المستخدمين'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Naviguer vers la page de gestion et attendre le résultat
    final result = await context.push('/admin/users/${user['id']}/manage');

    // Si l'utilisateur a été supprimé ou modifié, recharger la liste
    if (result == true && mounted) {
      _loadUsers();
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = UserRole.fromString(user['role']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: () => _openUserManagement(user),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            gradient: LinearGradient(
              colors: [AppTheme.cardColor, AppTheme.cardColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar avec gradient
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getRoleColor(role),
                          _getRoleColor(role).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      boxShadow: [
                        BoxShadow(
                          color: _getRoleColor(role).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getRoleIcon(role),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['full_name'] ?? user['email'],
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          user['email'],
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingXS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                            border: Border.all(
                              color: AppTheme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'تم الإنشاء: ${_formatDate(user['created_at'])}',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Statut de vérification Badge moderne
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            user['is_validated'] == true
                                ? [
                                  AppTheme.successColor.withOpacity(0.1),
                                  AppTheme.successColor.withOpacity(0.05),
                                ]
                                : [
                                  AppTheme.warningColor.withOpacity(0.1),
                                  AppTheme.warningColor.withOpacity(0.05),
                                ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color:
                            user['is_validated'] == true
                                ? AppTheme.successColor.withOpacity(0.3)
                                : AppTheme.warningColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user['is_validated'] == true
                              ? Icons.verified
                              : Icons.pending,
                          color:
                              user['is_validated'] == true
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                          size: 14,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          user['is_validated'] == true ? 'محقق' : 'غير محقق',
                          style: AppTheme.labelSmall.copyWith(
                            color:
                                user['is_validated'] == true
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
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
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings;
      case UserRole.admin:
        return Icons.settings;
      case UserRole.jury:
        return Icons.gavel;
      case UserRole.member:
        return Icons.person;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
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

  Widget _buildLoadingState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(AppTheme.spacingXL),
        elevation: AppTheme.elevationL,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            gradient: AppTheme.primaryGradient,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'جاري تحميل المستخدمين...',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'يرجى الانتظار قليلاً',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final totalUsers = _users.length;
    final validatedUsers =
        _users.where((user) => user['is_validated'] == true).length;
    final unvalidatedUsers =
        _users.where((user) => user['is_validated'] != true).length;
    final superAdmins =
        _users.where((user) => user['role'] == UserRole.superAdmin.code).length;
    final admins =
        _users.where((user) => user['role'] == UserRole.admin.code).length;
    final juries =
        _users.where((user) => user['role'] == UserRole.jury.code).length;

    return InkWell(
      onTap: () {
        setState(() {
          _isSummaryExpanded = !_isSummaryExpanded;
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.12),
              AppTheme.primaryColor.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
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
                  child: const Icon(Icons.insights, color: Colors.white),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'إحصائيات سريعة',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                Icon(
                  _isSummaryExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondaryColor,
                ),
              ],
            ),
            if (_isSummaryExpanded) ...[
              const SizedBox(height: AppTheme.spacingM),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 660;
                  final stats = [
                    (
                      label: 'إجمالي المستخدمين',
                      value: totalUsers,
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    (
                      label: 'مستخدمون موثقون',
                      value: validatedUsers,
                      icon: Icons.verified_outlined,
                      color: AppTheme.successColor,
                    ),
                    (
                      label: 'مستخدمون غير موثقين',
                      value: unvalidatedUsers,
                      icon: Icons.pending_outlined,
                      color: AppTheme.warningColor,
                    ),
                    (
                      label: 'المديرون العامون',
                      value: superAdmins,
                      icon: Icons.shield_outlined,
                      color: AppTheme.errorColor,
                    ),
                    (
                      label: 'المديرون',
                      value: admins,
                      icon: Icons.settings_outlined,
                      color: AppTheme.infoColor,
                    ),
                    (
                      label: 'أعضاء لجنة التحكيم',
                      value: juries,
                      icon: Icons.gavel_outlined,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ];

                  Widget buildStatCard(
                    String label,
                    int value,
                    IconData icon,
                    Color color,
                  ) {
                    return Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        boxShadow: AppTheme.shadowS,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingXS),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusS,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value.toString(),
                                  style: AppTheme.headingSmall.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isWide) {
                    return Row(
                      children:
                          stats
                              .map(
                                (stat) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          stat == stats.last
                                              ? 0
                                              : AppTheme.spacingS,
                                    ),
                                    child: buildStatCard(
                                      stat.label,
                                      stat.value,
                                      stat.icon,
                                      stat.color,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    );
                  }

                  return Column(
                    children:
                        stats
                            .map(
                              (stat) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.spacingS,
                                ),
                                child: buildStatCard(
                                  stat.label,
                                  stat.value,
                                  stat.icon,
                                  stat.color,
                                ),
                              ),
                            )
                            .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.textSecondaryColor.withOpacity(0.1),
                  AppTheme.textSecondaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: AppTheme.textSecondaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              size: 80,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            _searchQuery.isEmpty ? 'لا يوجد مستخدمون' : 'لا توجد نتائج للبحث',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingL,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.dividerColor, width: 1),
            ),
            child: Text(
              _searchQuery.isEmpty
                  ? 'لم يتم إضافة أي مستخدمين بعد'
                  : 'جرب تغيير معايير البحث أو إزالة المرشحات',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedRoleFilter = 'all';
                  _selectedValidationFilter = 'all';
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('مسح المرشحات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingS,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Attendre que les permissions soient chargées
    if (_isAdmin == null || _isAdmin == false) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAdmin == false) {
      return const AccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body:
          _isLoading
              ? _buildLoadingState()
              : ModernPullToRefresh(
                onRefresh: _loadUsers,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummarySection(),
                      const SizedBox(height: AppTheme.spacingS),
                      // Barre de recherche et filtres
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                          gradient: LinearGradient(
                            colors: [AppTheme.cardColor, AppTheme.surfaceColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre avec icône
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.infoColor,
                                        AppTheme.infoColor.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    boxShadow: AppTheme.shadowS,
                                  ),
                                  child: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'البحث والتصفية',
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.textPrimaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppTheme.spacingXS,
                                      ),
                                      Text(
                                        'البحث عن المستخدمين وتصفيتهم حسب الدور',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingXL),

                            // Champs de recherche et filtre
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Si l'écran est petit, utiliser un layout vertical
                                if (constraints.maxWidth < 600) {
                                  return Column(
                                    children: [
                                      // Champ de recherche
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.backgroundColor,
                                              AppTheme.backgroundColor
                                                  .withOpacity(0.8),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusL,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText:
                                                'البحث بالاسم أو البريد الإلكتروني...',
                                            hintStyle: AppTheme.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppTheme
                                                          .textDisabledColor,
                                                ),
                                            prefixIcon: Container(
                                              margin: const EdgeInsets.all(
                                                AppTheme.spacingXS,
                                              ),
                                              padding: const EdgeInsets.all(
                                                AppTheme.spacingXS,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient:
                                                    AppTheme.primaryGradient,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusM,
                                                    ),
                                                boxShadow: AppTheme.shadowS,
                                              ),
                                              child: const Icon(
                                                Icons.search,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingS,
                                                  vertical: AppTheme.spacingS,
                                                ),
                                            filled: false,
                                          ),
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textPrimaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _searchQuery = value;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.spacingS),

                                      // Dropdown filtre الأدوار
                                      DropdownButtonFormField<String>(
                                        value: _selectedRoleFilter,
                                        dropdownColor: Colors.white,
                                        decoration: InputDecoration(
                                          labelText: 'فلترة حسب الدور',
                                          labelStyle: AppTheme.bodyMedium
                                              .copyWith(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                          prefixIcon: Icon(
                                            Icons.filter_list,
                                            color: AppTheme.primaryColor,
                                            size: 20,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: AppTheme.spacingS,
                                                vertical: AppTheme.spacingS,
                                              ),
                                        ),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.all_inclusive,
                                                  size: 18,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                Text(
                                                  'جميع الأدوار',
                                                  style: AppTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                          ...UserRole.values.map((role) {
                                            return DropdownMenuItem<String>(
                                              value: role.code,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _getRoleIcon(role),
                                                    size: 18,
                                                    color: _getRoleColor(role),
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingS,
                                                  ),
                                                  Text(
                                                    role.displayName,
                                                    style: AppTheme.bodyMedium
                                                        .copyWith(
                                                          color: _getRoleColor(
                                                            role,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedRoleFilter =
                                                value ?? 'all';
                                          });
                                        },
                                      ),
                                      const SizedBox(height: AppTheme.spacingS),

                                      // Dropdown filtre التحقق
                                      DropdownButtonFormField<String>(
                                        value: _selectedValidationFilter,
                                        dropdownColor: Colors.white,
                                        decoration: InputDecoration(
                                          labelText: 'فلترة حسب التحقق',
                                          labelStyle: AppTheme.bodyMedium
                                              .copyWith(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                          prefixIcon: Icon(
                                            Icons.verified_user,
                                            color: AppTheme.infoColor,
                                            size: 20,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppTheme.primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: AppTheme.spacingS,
                                                vertical: AppTheme.spacingS,
                                              ),
                                        ),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.all_inclusive,
                                                  size: 18,
                                                  color: AppTheme.infoColor,
                                                ),
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                Text(
                                                  'جميع الحالات',
                                                  style: AppTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'validated',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.verified,
                                                  size: 18,
                                                  color: AppTheme.successColor,
                                                ),
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                Text(
                                                  'موثقون',
                                                  style: AppTheme.bodyMedium
                                                      .copyWith(
                                                        color:
                                                            AppTheme
                                                                .successColor,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'unvalidated',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.pending,
                                                  size: 18,
                                                  color: AppTheme.warningColor,
                                                ),
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                Text(
                                                  'غير موثقين',
                                                  style: AppTheme.bodyMedium
                                                      .copyWith(
                                                        color:
                                                            AppTheme
                                                                .warningColor,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedValidationFilter =
                                                value ?? 'all';
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                } else {
                                  // Pour les écrans larges, utiliser un layout horizontal
                                  return Row(
                                    children: [
                                      // Champ de recherche avec design moderne
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.backgroundColor,
                                                AppTheme.backgroundColor
                                                    .withOpacity(0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusL,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.primaryColor
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText:
                                                  'البحث بالاسم أو البريد الإلكتروني...',
                                              hintStyle: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppTheme
                                                            .textDisabledColor,
                                                  ),
                                              prefixIcon: Container(
                                                margin: const EdgeInsets.all(
                                                  AppTheme.spacingXS,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  AppTheme.spacingXS,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      AppTheme.primaryGradient,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppTheme.radiusM,
                                                      ),
                                                  boxShadow: AppTheme.shadowS,
                                                ),
                                                child: const Icon(
                                                  Icons.search,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        AppTheme.spacingS,
                                                    vertical: AppTheme.spacingS,
                                                  ),
                                              filled: false,
                                            ),
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.textPrimaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _searchQuery = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),

                                      // Dropdown filtre avec design moderne
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedRoleFilter,
                                          dropdownColor: Colors.white,
                                          decoration: InputDecoration(
                                            labelText: 'فلترة حسب الدور',
                                            labelStyle: AppTheme.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppTheme
                                                          .textSecondaryColor,
                                                ),
                                            prefixIcon: Icon(
                                              Icons.filter_list,
                                              color: AppTheme.primaryColor,
                                              size: 20,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.dividerColor,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.dividerColor,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingS,
                                                  vertical: AppTheme.spacingS,
                                                ),
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'all',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.all_inclusive,
                                                    size: 18,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingS,
                                                  ),
                                                  Text(
                                                    'جميع الأدوار',
                                                    style: AppTheme.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ...UserRole.values.map((role) {
                                              return DropdownMenuItem<String>(
                                                value: role.code,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      _getRoleIcon(role),
                                                      size: 18,
                                                      color: _getRoleColor(
                                                        role,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: AppTheme.spacingS,
                                                    ),
                                                    Text(
                                                      role.displayName,
                                                      style: AppTheme.bodyMedium
                                                          .copyWith(
                                                            color:
                                                                _getRoleColor(
                                                                  role,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedRoleFilter =
                                                  value ?? 'all';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),

                                      // Dropdown filtre التحقق للشاشات الكبيرة
                                      Expanded(
                                        flex: 1,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedValidationFilter,
                                          dropdownColor: Colors.white,
                                          decoration: InputDecoration(
                                            labelText: 'فلترة حسب التحقق',
                                            labelStyle: AppTheme.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppTheme
                                                          .textSecondaryColor,
                                                ),
                                            prefixIcon: Icon(
                                              Icons.verified_user,
                                              color: AppTheme.infoColor,
                                              size: 20,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.dividerColor,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.dividerColor,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusM,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacingS,
                                                  vertical: AppTheme.spacingS,
                                                ),
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'all',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.all_inclusive,
                                                    size: 18,
                                                    color: AppTheme.infoColor,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingS,
                                                  ),
                                                  Text(
                                                    'جميع الحالات',
                                                    style: AppTheme.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'validated',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.verified,
                                                    size: 18,
                                                    color:
                                                        AppTheme.successColor,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingS,
                                                  ),
                                                  Text(
                                                    'موثقون',
                                                    style: AppTheme.bodyMedium
                                                        .copyWith(
                                                          color:
                                                              AppTheme
                                                                  .successColor,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'unvalidated',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.pending,
                                                    size: 18,
                                                    color:
                                                        AppTheme.warningColor,
                                                  ),
                                                  const SizedBox(
                                                    width: AppTheme.spacingS,
                                                  ),
                                                  Text(
                                                    'غير موثقين',
                                                    style: AppTheme.bodyMedium
                                                        .copyWith(
                                                          color:
                                                              AppTheme
                                                                  .warningColor,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedValidationFilter =
                                                  value ?? 'all';
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: AppTheme.spacingS),

                            // Liste des utilisateurs
                            Container(
                              // padding: const EdgeInsets.all(
                              //   AppTheme.spacingS,
                              // ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusL,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.cardColor,
                                    AppTheme.surfaceColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Titre avec compteur
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppTheme.spacingS,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.successColor,
                                              AppTheme.successColor.withOpacity(
                                                0.7,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          boxShadow: AppTheme.shadowS,
                                        ),
                                        child: const Icon(
                                          Icons.people,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'قائمة المستخدمين',
                                              style: AppTheme.bodyLarge
                                                  .copyWith(
                                                    color:
                                                        AppTheme
                                                            .textPrimaryColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(
                                              height: AppTheme.spacingXS,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        AppTheme.spacingS,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.successColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusS,
                                                    ),
                                                border: Border.all(
                                                  color: AppTheme.successColor
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '${_filteredUsers.length} مستخدم',
                                                style: AppTheme.labelSmall
                                                    .copyWith(
                                                      color:
                                                          AppTheme.successColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),

                                  // Contenu de la liste
                                  _filteredUsers.isEmpty
                                      ? _buildEmptyState()
                                      : Column(
                                        children: [
                                          ..._filteredUsers.map(
                                            (user) => _buildUserCard(user),
                                          ),
                                          const SizedBox(
                                            height: AppTheme.spacingS,
                                          ),
                                        ],
                                      ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingXL),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
