import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/services/round_jury_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
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
  // Des modifications ont été enregistrées : la liste devra être rechargée
  bool _hasChanges = false;

  /// Nom affiché dans les messages (nom complet, sinon email)
  String get _userLabel {
    final name = (_user?['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return (_user?['email'] as String?) ?? '';
  }

  /// Message d'erreur lisible, sans le préfixe technique « Exception: »
  String _errorText(Object e) =>
      e.toString().replaceAll('Exception: ', '').trim();

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // Admin et Super Admin ont accès à la gestion des utilisateurs
    final hasAccess = await PermissionService().hasAdminPermissions();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted) return;

    setState(() {
      _hasAccess = hasAccess;
    });

    if (hasAccess) {
      _loadData();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'هذه الصفحة متاحة للمديرين فقط.';
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _userService.getUserById(widget.userId);
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'المستخدم غير موجود أو تم حذفه.';
          _isLoading = false;
        });
        return;
      }

      // Vérifier que l'utilisateur n'est pas le current user ou super_admin
      if (user['id'] == _currentUserId) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'لا يمكنك إدارة حسابك الخاص من هنا.';
          _isLoading = false;
        });
        return;
      }

      final userRole = UserRole.fromString(user['role']);
      if (userRole == UserRole.superAdmin) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'لا يمكن إدارة حساب مدير عام من هنا.';
          _isLoading = false;
        });
        return;
      }

      final permissions = await _userService.getUserPermissions(widget.userId);
      final basePermissions = _permissionsFromUserPermissions(
        UserPermissions.forRole(userRole),
      );

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'تعذر تحميل بيانات المستخدم. تحقق من الاتصال وحاول مجدداً.';
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

    // Une seule requête, au lieu d'une par version puis par جولة
    return _roundJuryService.isJuryAssignedToAnyRound(_user!['id']);
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
              'لا يمكن تعيين مستخدم كمدير عام من خلال هذه الواجهة',
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
          'هل أنت متأكد من تغيير دور $_userLabel إلى ${_selectedRole!.displayName}؟',
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
      if (!mounted) return;

      // On reste sur la page : l'administrateur peut enchaîner (vérifier
      // le compte, ajuster les صلاحيات...). La liste sera rechargée au retour.
      setState(() {
        _user!['role'] = _selectedRole!.code;
        _user!['role_display_name'] = _selectedRole!.displayName;
        _hasChanges = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تحديث دور المستخدم بنجاح'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تحديث الدور: ${_errorText(e)}'),
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
      _hasChanges = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصلاحيات بنجاح'),
            backgroundColor: AppTheme.successColor,
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
            content: Text('خطأ أثناء حفظ الصلاحيات: ${_errorText(e)}'),
            backgroundColor: AppTheme.errorColor,
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
          'هل أنت متأكد من ${newStatus ? 'توثيق' : 'إلغاء توثيق'} المستخدم $_userLabel؟',
      actionType: 'تغيير حالة التحقق',
    );

    if (!confirmed) return;

    try {
      await _userService.updateUserVerificationStatus(_user!['id'], newStatus);
      if (!mounted) return;

      setState(() {
        _isValidated = newStatus;
        _user!['is_validated'] = newStatus;
        _hasChanges = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'تم توثيق المستخدم بنجاح' : 'تم إلغاء توثيق المستخدم',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تغيير حالة التحقق: ${_errorText(e)}'),
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
          'هل أنت متأكد أنك تريد حذف حساب $_userLabel؟ لا يمكن التراجع عن هذه العملية.',
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
            content: Text(_errorText(e)),
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

    // Retour (bouton ou geste) : indique à la liste s'il faut recharger
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_hasChanges);
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدم')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(context),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            OutlinedButton.icon(
              onPressed: () => context.pop(_hasChanges),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = _user!;
    final canEditPermissions = _isValidated == true;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(user),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildValidationSection(),
                const SizedBox(height: AppTheme.spacingM),
                _buildRoleSection(),
                if (_selectedRole == UserRole.admin) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  _buildPermissionsSection(canEditPermissions),
                ],
                const SizedBox(height: AppTheme.spacingM),
                _buildDeleteSection(),
                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // En-tête
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Map<String, dynamic> user) {
    final role = UserRole.fromString(user['role'] ?? 'membre');
    final isValidated = _isValidated == true;
    final email = (user['email'] as String?)?.trim() ?? '';
    final phone = user['phone']?.toString().trim() ?? '';
    final initial = _userLabel.isNotEmpty ? _userLabel.characters.first : '?';

    return AppGradientHeader(
      leading: CircleAvatar(
        radius: 38,
        backgroundColor: Colors.white,
        child: Text(
          initial.toUpperCase(),
          style: AppTheme.headingLarge.copyWith(
            color: _getRoleColor(role),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: _userLabel.isNotEmpty ? _userLabel : 'بدون اسم',
      subtitle: email.isNotEmpty && email != _userLabel ? email : null,
      badges: [
        AppHeaderBadge(icon: _getRoleIcon(role), text: role.displayName),
        AppHeaderBadge(
          icon: isValidated ? Icons.verified_rounded : Icons.pending_rounded,
          text: isValidated ? 'حساب موثق' : 'بانتظار التوثيق',
          highlightColor: isValidated ? null : AppTheme.warningColor,
        ),
        if (phone.isNotEmpty)
          AppHeaderBadge(
            icon: Icons.phone_rounded,
            text: '\u200E${_formatPhone(phone)}',
          ),
      ],
    );
  }

  String _formatPhone(String phone) {
    final data = _splitPhoneNumber(phone);
    final code = data['countryCode'] ?? '';
    final number = data['phoneNumber'] ?? '';
    if (code.isNotEmpty && number.isNotEmpty) return '$code $number';
    return number.isNotEmpty ? number : phone;
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.admin:
        return Icons.manage_accounts_rounded;
      case UserRole.jury:
        return Icons.gavel_rounded;
      case UserRole.member:
        return Icons.person_rounded;
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

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'كل الصلاحيات';
      case UserRole.admin:
        return 'إدارة المسابقات والمحتوى حسب الصلاحيات';
      case UserRole.jury:
        return 'تقييم المشاركين في الجولات المسندة إليه';
      case UserRole.member:
        return 'الوصول إلى صفحات المشاركين فقط';
    }
  }

  /// فصل رمز الدولة عن رقم الهاتف
  Map<String, String> _splitPhoneNumber(String phone) {
    if (phone.isEmpty) {
      return {'countryCode': '', 'phoneNumber': ''};
    }

    // إذا كان الرقم يبدأ بـ +، نفصل رمز الدولة
    if (phone.startsWith('+')) {
      final digits = phone.substring(1);

      if (digits.isEmpty) {
        return {'countryCode': '', 'phoneNumber': phone};
      }

      // تحديد رمز الدولة بناءً على أول رقم
      String countryCode;
      String phoneNumber;

      // رموز الدول التي تبدأ بـ 2 (عادة 3 أرقام: +213, +212, +216, +222)
      if (digits.startsWith('2') && digits.length >= 4) {
        countryCode = '+${digits.substring(0, 3)}';
        phoneNumber = digits.substring(3);
      }
      // رموز الدول التي تبدأ بـ 1 (عادة 1 رقم: +1)
      else if (digits.startsWith('1') && digits.length >= 4) {
        // +1 (أمريكا/كندا) - رمز دولة واحد
        countryCode = '+${digits.substring(0, 1)}';
        phoneNumber = digits.substring(1);
      }
      // رموز الدول الأخرى (عادة 2 أرقام: +33, +20, +44)
      else if (digits.length >= 3) {
        countryCode = '+${digits.substring(0, 2)}';
        phoneNumber = digits.substring(2);
      } else {
        return {'countryCode': '', 'phoneNumber': phone};
      }

      // إزالة الصفر الأول من الرقم إن وجد
      final cleanPhone =
          phoneNumber.startsWith('0') ? phoneNumber.substring(1) : phoneNumber;

      // تنسيق الرقم بفواصل
      final formatted = _formatPhoneDigits(cleanPhone);
      return {'countryCode': countryCode, 'phoneNumber': formatted};
    }

    return {'countryCode': '', 'phoneNumber': phone};
  }

  /// تنسيق أرقام الهاتف بفواصل
  String _formatPhoneDigits(String digits) {
    if (digits.isEmpty) return digits;
    if (digits.length <= 3) return digits;

    // للأرقام التي طولها 8 أرقام (مثل موريتانيا: 36361701)
    // نستخدم التنسيق: XX XX XX XX
    if (digits.length == 8) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)}';
    }
    // للأرقام التي طولها 9 أرقام: XX XXX XXXX
    else if (digits.length == 9) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 9)}';
    }
    // للأرقام التي طولها 10 أرقام: XXX XXX XXXX
    else if (digits.length == 10) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 10)}';
    }
    // للأرقام الأخرى: نستخدم فواصل كل 3 أرقام
    else {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length; i += 3) {
        if (i > 0) buffer.write(' ');
        final end = (i + 3 < digits.length) ? i + 3 : digits.length;
        buffer.write(digits.substring(i, end));
      }
      return buffer.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _buildValidationSection() {
    final isValidated = _isValidated == true;
    final color = isValidated ? AppTheme.successColor : AppTheme.warningColor;

    return AppSection(
      icon:
          isValidated
              ? Icons.verified_user_rounded
              : Icons.pending_actions_rounded,
      color: color,
      title: 'توثيق الحساب',
      subtitle: isValidated ? 'الحساب موثق' : 'الحساب بانتظار التوثيق',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNotice(
            text:
                isValidated
                    ? 'يمكن لهذا المستخدم الوصول إلى اللوحة وفق دوره وصلاحياته.'
                    : 'لن يتمكن هذا المستخدم من الوصول إلى اللوحة قبل توثيق حسابه.',
            color: color,
          ),
          const SizedBox(height: AppTheme.spacingS),
          CanValidateAccountsGuard(
            child:
                isValidated
                    ? OutlinedButton.icon(
                      onPressed: _toggleValidationStatus,
                      icon: const Icon(Icons.remove_moderator_rounded),
                      label: const Text('إلغاء التوثيق'),
                      style: AppButtonStyles.outlined(AppTheme.warningColor),
                    )
                    : ElevatedButton.icon(
                      onPressed: _toggleValidationStatus,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('توثيق الحساب'),
                      style: AppButtonStyles.filled(AppTheme.successColor),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    final roles =
        UserRole.values.where((r) => r != UserRole.superAdmin).toList();
    final currentRoleCode = _user?['role'];
    final hasChanged = _selectedRole?.code != currentRoleCode;

    return AppSection(
      icon: Icons.badge_rounded,
      color: AppTheme.primaryColor,
      title: 'الدور',
      subtitle: 'اختر دور المستخدم ثم احفظ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final role in roles) ...[
            _buildRoleOption(role, isCurrent: role.code == currentRoleCode),
            const SizedBox(height: AppTheme.spacingS),
          ],
          CanAssignRolesGuard(
            child: ElevatedButton.icon(
              onPressed: _isSavingRole || !hasChanged ? null : _saveRole,
              icon:
                  _isSavingRole
                      ? const AppButtonLoader()
                      : const Icon(Icons.save_rounded),
              label: Text(
                _isSavingRole
                    ? 'جاري الحفظ...'
                    : hasChanged
                    ? 'حفظ الدور: ${_selectedRole!.displayName}'
                    : 'حفظ الدور',
              ),
              style: AppButtonStyles.filled(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(UserRole role, {required bool isCurrent}) {
    final selected = _selectedRole == role;
    final color = _getRoleColor(role);

    return Material(
      color: selected ? color.withOpacity(0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap:
            _isSavingRole ? null : () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: selected ? color : AppTheme.dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_getRoleIcon(role), color: color, size: 18),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          role.displayName,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected ? color : AppTheme.textPrimaryColor,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: AppTheme.spacingXS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.dividerColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusS,
                              ),
                            ),
                            child: Text(
                              'الحالي',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _getRoleDescription(role),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? color : AppTheme.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsSection(bool canEditPermissions) {
    final editable = canEditPermissions && _permissionsColumnsExist;

    return AppSection(
      icon: Icons.tune_rounded,
      color: AppTheme.infoColor,
      title: 'الصلاحيات',
      subtitle: 'تخصيص ما يمكن لهذا المدير القيام به',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_permissionsColumnsExist) ...[
            AppNotice(
              text:
                  'أعمدة الصلاحيات غير موجودة في قاعدة البيانات. تُطبَّق الصلاحيات الافتراضية للدور.',
              color: AppTheme.infoColor,
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],
          if (!canEditPermissions) ...[
            AppNotice(
              text: 'لا يمكن تعديل الصلاحيات قبل توثيق الحساب.',
              color: AppTheme.warningColor,
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(children: _buildPermissionSwitches(editable)),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: editable ? _resetPermissions : null,
                  style: AppButtonStyles.outlined(AppTheme.textSecondaryColor),
                  child: const Text('الافتراضي'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      !editable ||
                              _isSavingPermissions ||
                              !_hasPermissionChanges
                          ? null
                          : _savePermissions,
                  style: AppButtonStyles.filled(AppTheme.primaryColor),
                  child:
                      _isSavingPermissions
                          ? const AppButtonLoader()
                          : const Text('حفظ الصلاحيات'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionSwitches(bool canEditPermissions) {
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

    final widgets = <Widget>[];
    for (var i = 0; i < permissionDefinitions.length; i++) {
      final definition = permissionDefinitions[i];
      if (i > 0) widgets.add(const Divider(height: 1));
      widgets.add(
        SwitchListTile.adaptive(
          value: _permissions[definition.key] ?? false,
          onChanged:
              canEditPermissions
                  ? (newValue) =>
                      setState(() => _permissions[definition.key] = newValue)
                  : null,
          dense: true,
          title: Text(
            definition.title,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            definition.description,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          activeColor: AppTheme.primaryColor,
        ),
      );
    }
    return widgets;
  }

  Widget _buildDeleteSection() {
    return CanDeleteGuard(
      child: AppSection(
        icon: Icons.delete_outline_rounded,
        color: AppTheme.errorColor,
        title: 'منطقة الخطر',
        subtitle: 'حذف الحساب نهائي ولا يمكن التراجع عنه',
        borderColor: AppTheme.errorColor,
        child: OutlinedButton.icon(
          onPressed: _isDeleting ? null : _deleteUser,
          icon:
              _isDeleting
                  ? const AppButtonLoader(color: AppTheme.errorColor)
                  : const Icon(Icons.delete_forever_rounded),
          label: Text(_isDeleting ? 'جاري الحذف...' : 'حذف المستخدم'),
          style: AppButtonStyles.outlined(AppTheme.errorColor),
        ),
      ),
    );
  }
}
