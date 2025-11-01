import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementService _userService = UserManagementService();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
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

    // Exclure l'utilisateur actuel
    if (_currentUserId != null) {
      filtered =
          filtered.where((user) => user['id'] != _currentUserId).toList();
    }

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

    return filtered;
  }

  Future<void> _updateUserRole(
    Map<String, dynamic> user,
    UserRole newRole,
  ) async {
    final confirmed = await ConfirmationService.showCriticalActionConfirmation(
      context,
      title: 'تغيير دور المستخدم',
      message:
          'هل أنت متأكد من تغيير دور ${user['email']} إلى ${newRole.displayName}؟',
      actionType: 'تغيير الدور',
    );

    if (confirmed) {
      try {
        await _userService.updateUserRole(user['id'], newRole);

        // Mettre à jour localement sans recharger la page
        setState(() {
          final userIndex = _users.indexWhere((u) => u['id'] == user['id']);
          if (userIndex != -1) {
            _users[userIndex]['role'] = newRole.code;
            _users[userIndex]['role_display_name'] = newRole.displayName;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تغيير دور المستخدم بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          debugPrint('خطأ في تغيير الدور: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تغيير الدور: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleVerificationStatus(Map<String, dynamic> user) async {
    final currentStatus = user['is_validated'] == true;
    final newStatus = !currentStatus;

    final confirmed = await ConfirmationService.showCriticalActionConfirmation(
      context,
      title: 'تغيير حالة التحقق',
      message:
          'هل أنت متأكد من ${newStatus ? 'تحقق' : 'إلغاء تحقق'} المستخدم ${user['email']}؟',
      actionType: 'تغيير حالة التحقق',
    );

    if (confirmed) {
      try {
        await _userService.updateUserVerificationStatus(user['id'], newStatus);

        // Mettre à jour localement sans recharger la page
        setState(() {
          final userIndex = _users.indexWhere((u) => u['id'] == user['id']);
          if (userIndex != -1) {
            _users[userIndex]['is_validated'] = newStatus;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم ${newStatus ? 'تحقق' : 'إلغاء تحقق'} المستخدم بنجاح',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          debugPrint('خطأ في تغيير حالة التحقق: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تغيير حالة التحقق: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
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
            const SizedBox(height: AppTheme.spacingS),

            // Séparateur
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.dividerColor,
                    AppTheme.dividerColor.withOpacity(0.5),
                    AppTheme.dividerColor,
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Role Change Dropdown moderne
            CanAssignRolesGuard(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppTheme.dividerColor, width: 1),
                ),
                child: DropdownButtonFormField<UserRole>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: 'تغيير الدور',
                    labelStyle: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 11,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                  ),
                  items:
                      UserRole.values.map((role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                _getRoleIcon(role),
                                color: _getRoleColor(role),
                                size: 16,
                              ),
                              const SizedBox(width: AppTheme.spacingXS),
                              Text(
                                role.displayName,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null && newRole != role) {
                      _updateUserRole(user, newRole);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Statut de vérification
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.dividerColor, width: 1),
              ),
              child: Row(
                children: [
                  // Icône du statut
                  Container(
                    margin: const EdgeInsets.all(AppTheme.spacingXS),
                    padding: const EdgeInsets.all(AppTheme.spacingXS),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            user['is_validated'] == true
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
                      boxShadow: AppTheme.shadowS,
                    ),
                    child: Icon(
                      user['is_validated'] == true
                          ? Icons.verified
                          : Icons.pending,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),

                  // Texte du statut
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: AppTheme.spacingXS,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حالة التحقق',
                            style: AppTheme.labelSmall.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user['is_validated'] == true ? 'محقق' : 'غير محقق',
                            style: AppTheme.bodySmall.copyWith(
                              color:
                                  user['is_validated'] == true
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bouton de changement de statut
                  Container(
                    margin: const EdgeInsets.all(AppTheme.spacingXS),
                    child: ElevatedButton(
                      onPressed: () => _toggleVerificationStatus(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            user['is_validated'] == true
                                ? AppTheme.warningColor.withOpacity(0.1)
                                : AppTheme.successColor.withOpacity(0.1),
                        foregroundColor:
                            user['is_validated'] == true
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          side: BorderSide(
                            color:
                                user['is_validated'] == true
                                    ? AppTheme.warningColor.withOpacity(0.3)
                                    : AppTheme.successColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        user['is_validated'] == true ? 'إلغاء التحقق' : 'تحقق',
                        style: AppTheme.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين والأدوار'),
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
                      // Barre de recherche et filtres
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
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

                                      // Dropdown filtre
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
                                            color: AppTheme.successColor
                                                .withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.successColor
                                                  .withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedRoleFilter,
                                            isExpanded: true,
                                            icon: Container(
                                              margin: const EdgeInsets.all(
                                                AppTheme.spacingXS,
                                              ),
                                              padding: const EdgeInsets.all(
                                                AppTheme.spacingXS,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.successColor,
                                                    AppTheme.successColor
                                                        .withOpacity(0.7),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusM,
                                                    ),
                                                boxShadow: AppTheme.shadowS,
                                              ),
                                              child: const Icon(
                                                Icons.filter_list,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.textPrimaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'all',
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppTheme.spacingS,
                                                        vertical:
                                                            AppTheme.spacingXS,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme.radiusS,
                                                        ),
                                                    border: Border.all(
                                                      color: AppTheme
                                                          .primaryColor
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.all_inclusive,
                                                        size: 16,
                                                        color:
                                                            AppTheme
                                                                .primaryColor,
                                                      ),
                                                      const SizedBox(
                                                        width:
                                                            AppTheme.spacingS,
                                                      ),
                                                      Text(
                                                        'جميع الأدوار',
                                                        style: AppTheme
                                                            .bodySmall
                                                            .copyWith(
                                                              color:
                                                                  AppTheme
                                                                      .primaryColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              ...UserRole.values.map((role) {
                                                return DropdownMenuItem<String>(
                                                  value: role.code,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppTheme.spacingS,
                                                          vertical:
                                                              AppTheme
                                                                  .spacingXS,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _getRoleColor(
                                                        role,
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppTheme.radiusS,
                                                          ),
                                                      border: Border.all(
                                                        color: _getRoleColor(
                                                          role,
                                                        ).withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _getRoleIcon(role),
                                                          size: 16,
                                                          color: _getRoleColor(
                                                            role,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width:
                                                              AppTheme.spacingS,
                                                        ),
                                                        Text(
                                                          role.displayName,
                                                          style: AppTheme
                                                              .bodySmall
                                                              .copyWith(
                                                                color:
                                                                    _getRoleColor(
                                                                      role,
                                                                    ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
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
                                              color: AppTheme.successColor
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.successColor
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedRoleFilter,
                                              isExpanded: true,
                                              icon: Container(
                                                margin: const EdgeInsets.all(
                                                  AppTheme.spacingXS,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  AppTheme.spacingXS,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppTheme.successColor,
                                                      AppTheme.successColor
                                                          .withOpacity(0.7),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppTheme.radiusM,
                                                      ),
                                                  boxShadow: AppTheme.shadowS,
                                                ),
                                                child: const Icon(
                                                  Icons.filter_list,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppTheme
                                                            .textPrimaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                              items: [
                                                DropdownMenuItem(
                                                  value: 'all',
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppTheme.spacingS,
                                                          vertical:
                                                              AppTheme
                                                                  .spacingXS,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme
                                                          .primaryColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppTheme.radiusS,
                                                          ),
                                                      border: Border.all(
                                                        color: AppTheme
                                                            .primaryColor
                                                            .withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.all_inclusive,
                                                          size: 16,
                                                          color:
                                                              AppTheme
                                                                  .primaryColor,
                                                        ),
                                                        const SizedBox(
                                                          width:
                                                              AppTheme.spacingS,
                                                        ),
                                                        Text(
                                                          'جميع الأدوار',
                                                          style: AppTheme
                                                              .bodySmall
                                                              .copyWith(
                                                                color:
                                                                    AppTheme
                                                                        .primaryColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                ...UserRole.values.map((role) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: role.code,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal:
                                                                AppTheme
                                                                    .spacingS,
                                                            vertical:
                                                                AppTheme
                                                                    .spacingXS,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _getRoleColor(
                                                          role,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppTheme.radiusS,
                                                            ),
                                                        border: Border.all(
                                                          color: _getRoleColor(
                                                            role,
                                                          ).withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            _getRoleIcon(role),
                                                            size: 16,
                                                            color:
                                                                _getRoleColor(
                                                                  role,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width:
                                                                AppTheme
                                                                    .spacingS,
                                                          ),
                                                          Text(
                                                            role.displayName,
                                                            style: AppTheme
                                                                .bodySmall
                                                                .copyWith(
                                                                  color:
                                                                      _getRoleColor(
                                                                        role,
                                                                      ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
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
