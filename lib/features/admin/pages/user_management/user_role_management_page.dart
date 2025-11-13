import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/services/round_jury_service.dart';
import 'package:quranic_competition/core/services/round_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/features/shared/pages/access_denied_page.dart';

void _showLoadingDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  message,
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
  );
}

void _hideLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

class UserRoleManagementPage extends StatefulWidget {
  const UserRoleManagementPage({super.key, required this.userId});

  final String userId;

  @override
  State<UserRoleManagementPage> createState() => _UserRoleManagementPageState();
}

class _UserRoleManagementPageState extends State<UserRoleManagementPage> {
  final _userService = UserManagementService();
  final _authService = AuthService();
  final _roundJuryService = RoundJuryService();
  final _roundService = RoundService();
  final _versionService = CompetitionVersionService();

  Map<String, dynamic>? _user;
  UserRole? _selectedRole;
  Map<String, bool> _permissions = {};
  Map<String, bool> _initialPermissions = {};

  bool _isLoading = true;
  bool _isSavingRole = false;
  bool _isSavingPermissions = false;
  bool _isDeleting = false;
  bool? _isValidated;
  String? _errorMessage;
  bool _permissionsColumnsExist = false;
  bool? _hasAccess;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final hasAccess = await PermissionService().isSuperAdmin();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    setState(() {
      _hasAccess = hasAccess;
    });

    if (hasAccess) {
      _loadData();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'هذه الصفحة متاحة للمدير العام فقط.';
      });
    }
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

      // Vérifier que l'utilisateur n'est pas le current user ou super_admin
      if (user['id'] == _currentUserId) {
        setState(() {
          _errorMessage = 'لا يمكنك إدارة حسابك الخاص من هنا.';
          _isLoading = false;
        });
        return;
      }

      final userRole = UserRole.fromString(user['role']);
      if (userRole == UserRole.superAdmin) {
        setState(() {
          _errorMessage = 'لا يمكن إدارة المستخدمين من نوع Super Admin.';
          _isLoading = false;
        });
        return;
      }

      final permissions = await _userService.getUserPermissions(widget.userId);
      final basePermissions = _permissionsFromUserPermissions(
        UserPermissions.forRole(userRole),
      );

      setState(() {
        _user = user;
        _selectedRole = userRole;
        _permissionsColumnsExist = permissions != null;
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

  Future<bool> _isJuryInAnyRound() async {
    if (_user == null) return false;

    final currentRole = UserRole.fromString(_user!['role'] ?? 'membre');
    if (currentRole != UserRole.jury) return false;

    try {
      // Récupérer toutes les versions (actives et non actives)
      final allVersions = await _versionService.fetchVersions();

      // Pour chaque version، vérifier si le jury est assigné à n'importe quel round
      for (final version in allVersions) {
        try {
          final rounds = await _roundService.getRoundsByVersion(version.id);

          // Vérifier si le jury est assigné à n'importe quel round de cette version
          for (final round in rounds) {
            final isAssigned = await _roundJuryService.isJuryAssignedToRound(
              _user!['id'],
              round.id,
            );
            if (isAssigned) {
              return true;
            }
          }
        } catch (e) {
          // Si une version n'a pas de rounds, continuer avec la suivante
          print('⚠️ Aucun round trouvé pour la version ${version.id}: $e');
          continue;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Erreur lors de la vérification des rounds: $e');
      return false;
    }
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null || _user == null) return;

    // Vérifier الصلاحيات (rapide, avant popup)
    final canAssignRoles = await PermissionService().canAssignRoles();
    if (!canAssignRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعيين الأدوار'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Forbid promoting another user to super admin (rapide, avant popup)
    if (_selectedRole == UserRole.superAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'لا يمكن تعيين مستخدم كـ Super Admin من خلال هذه الواجهة',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    // Afficher la popup de confirmation immédiatement
    final confirmed = await ConfirmationService.showCriticalActionConfirmation(
      context,
      title: 'تغيير دور المستخدم',
      message:
          'هل أنت متأكد من تغيير دور ${_user!['email']} إلى ${_selectedRole!.displayName}؟',
      actionType: 'تغيير الدور',
    );

    if (!confirmed) return;

    // Vérifier si le user actuel est un jury dans un round après confirmation
    final currentRole = UserRole.fromString(_user!['role'] ?? 'membre');
    if (currentRole == UserRole.jury) {
      if (mounted) {
        _showLoadingDialog(context, 'جاري التحقق من حالة المحكم...');
      }

      final isInAnyRound = await _isJuryInAnyRound();

      if (mounted) {
        _hideLoadingDialog(context);
      }

      if (isInAnyRound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'لا يمكن تغيير دور المحكم لأنه محكم في جولة من إحدى النسخ',
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSavingRole = true);

    try {
      await _userService.updateUserRole(_user!['id'], _selectedRole!);

      setState(() {
        _user!['role'] = _selectedRole!.code;
        _user!['role_display_name'] = _selectedRole!.displayName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث دور المستخدم بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Retourner true pour indiquer que des modifications ont été faites
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تحديث الدور: $e'),
            backgroundColor: AppTheme.errorColor,
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
    if (_user == null || !_hasPermissionChanges || !_permissionsColumnsExist)
      return;

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

    // Vérifier الصلاحيات
    final canValidate = await PermissionService().canValidateAccounts();
    if (!canValidate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية التحقق من الحسابات'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

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
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Retourner true pour indiquer que des modifications ont été faites
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تغيير حالة التحقق: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser() async {
    if (_user == null) return;

    // Afficher la popup de confirmation immédiatement
    final confirmed = await ConfirmationService.showCriticalActionConfirmation(
      context,
      title: 'حذف المستخدم',
      message:
          'هل أنت متأكد أنك تريد حذف حساب ${_user!['email']}؟ لا يمكن التراجع عن هذه العملية.',
      actionType: 'حذف المستخدم',
    );

    if (!confirmed) return;

    // Afficher loading pendant la vérification
    if (mounted) {
      _showLoadingDialog(context, 'جاري التحقق من الصلاحيات...');
    }

    // Vérifier الصلاحيات après confirmation
    final canDelete = await PermissionService().canDelete();

    if (mounted) {
      _hideLoadingDialog(context);
    }

    if (!canDelete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ليس لديك صلاحية حذف المستخدمين'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    // Vérifier si le user est un jury dans un round après confirmation
    final currentRole = UserRole.fromString(_user!['role'] ?? 'membre');
    if (currentRole == UserRole.jury) {
      if (mounted) {
        _showLoadingDialog(context, 'جاري التحقق من حالة المحكم...');
      }

      final isInAnyRound = await _isJuryInAnyRound();

      if (mounted) {
        _hideLoadingDialog(context);
      }

      if (isInAnyRound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'لا يمكن حذف المحكم لأنه محكم في جولة من إحدى النسخ',
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isDeleting = true);

    try {
      await _userService.deleteUser(_user!['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف المستخدم بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Retourner à la page précédente avec résultat pour recharger les données
        context.pop(true);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حذف المستخدم: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasAccess == false) {
      return const AccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدم'),
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
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.errorColor,
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
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('العودة'),
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
    final canEditPermissions = _isValidated == true;

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
              _buildPermissionsSection(canEditPermissions),
            const SizedBox(height: AppTheme.spacingS),
            _buildDeleteSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic> user) {
    final role = UserRole.fromString(user['role'] ?? 'membre');

    return Card(
      elevation: AppTheme.elevationM,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          gradient: LinearGradient(
            colors: [AppTheme.cardColor, AppTheme.surfaceColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getRoleColor(role),
                        _getRoleColor(role).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: _getRoleColor(role).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getRoleIcon(role),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? user['email'] ?? 'بدون اسم',
                        style: AppTheme.headingSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildInfoChip(String label, dynamic value, {Color? color}) {
    final displayValue = value?.toString() ?? 'غير متوفر';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? AppTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (color != null) const SizedBox(width: AppTheme.spacingXS),
          Column(
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
        ],
      ),
    );
  }

  Widget _buildValidationSection() {
    final isValidated = _isValidated == true;

    return Card(
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          gradient: LinearGradient(
            colors: [
              isValidated
                  ? AppTheme.successColor.withOpacity(0.05)
                  : AppTheme.warningColor.withOpacity(0.05),
              AppTheme.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isValidated
                              ? [
                                AppTheme.successColor,
                                AppTheme.successColor.withOpacity(0.7),
                              ]
                              : [
                                AppTheme.warningColor,
                                AppTheme.warningColor.withOpacity(0.7),
                              ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    boxShadow: [
                      BoxShadow(
                        color: (isValidated
                                ? AppTheme.successColor
                                : AppTheme.warningColor)
                            .withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isValidated ? Icons.verified : Icons.pending,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حالة التحقق',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        isValidated ? 'المستخدم موثق' : 'المستخدم غير موثق',
                        style: AppTheme.bodyMedium.copyWith(
                          color:
                              isValidated
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                  width: 1.5,
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
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Text(
                      isValidated
                          ? 'هذا المستخدم موثق حالياً. يمكنه الوصول إلى اللوحة وفق صلاحياته.'
                          : 'هذا المستخدم غير موثق. لن يتمكن من الوصول الكامل حتى يتم توثيقه.',
                      style: AppTheme.bodyMedium.copyWith(
                        color:
                            isValidated
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            CanValidateAccountsGuard(
              child: SizedBox(
                width: double.infinity,
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
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingS,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection() {
    return Card(
      elevation: AppTheme.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              AppTheme.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تغيير الدور',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        'اختر الدور الجديد للمستخدم',
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
            CanAssignRolesGuard(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'اختر الدور الجديد',
                    labelStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                  ),
                  items:
                      UserRole.values
                          .map(
                            (role) => DropdownMenuItem<UserRole>(
                              value: role,
                              child: Row(
                                children: [
                                  Icon(
                                    _getRoleIcon(role),
                                    color: _getRoleColor(role),
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    role.displayName,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: _getRoleColor(role),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            CanAssignRolesGuard(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingRole ? null : _saveRole,
                  icon:
                      _isSavingRole
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(Icons.save),
                  label: Text(_isSavingRole ? 'جاري الحفظ...' : 'حفظ الدور'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingS,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection(bool canEditPermissions) {
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
            if (!_permissionsColumnsExist)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.infoColor.withOpacity(0.26),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.infoColor),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'أعمدة الصلاحيات غير موجودة في قاعدة البيانات. سيتم استخدام الصلاحيات الافتراضية حسب الدور.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!canEditPermissions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.26),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warningColor),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'لا يمكن تعديل الصلاحيات قبل توثيق حساب المستخدم.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ..._buildPermissionSwitches(
              context,
              canEditPermissions && _permissionsColumnsExist,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        canEditPermissions && _permissionsColumnsExist
                            ? _resetPermissions
                            : null,
                    child: const Text('استعادة الافتراضي'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        !canEditPermissions ||
                                !_permissionsColumnsExist ||
                                _isSavingPermissions ||
                                !_hasPermissionChanges
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

  List<Widget> _buildPermissionSwitches(
    BuildContext context,
    bool canEditPermissions,
  ) {
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
          onChanged:
              canEditPermissions
                  ? (newValue) {
                    setState(() {
                      _permissions[definition.key] = newValue;
                    });
                  }
                  : null,
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

  Widget _buildDeleteSection() {
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
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'حذف المستخدم',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.errorColor),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'حذف المستخدم هو إجراء دائم ولا يمكن التراجع عنه.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            CanDeleteGuard(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _deleteUser,
                  icon:
                      _isDeleting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_outline),
                  label: Text(_isDeleting ? 'جاري الحذف...' : 'حذف المستخدم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
