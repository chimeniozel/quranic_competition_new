import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/features/shared/pages/access_denied_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedValidationFilter = 'all'; // all, validated, unvalidated
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializePermissions() async {
    // Admin et Super Admin ont accès à la gestion des utilisateurs
    final isAdmin = await PermissionService().hasAdminPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _isLoading = isAdmin;
    });

    if (isAdmin) _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (_isAdmin != true) return;

    // Au rafraîchissement, la liste reste affichée pendant le chargement
    setState(() {
      _isLoading = _users.isEmpty;
      _hasError = false;
    });

    try {
      final users = await _userService.getAllUsers();
      // Les comptes en attente de vérification d'abord, puis les plus récents
      users.sort((a, b) {
        final va = a['is_validated'] == true;
        final vb = b['is_validated'] == true;
        if (va != vb) return va ? 1 : -1;
        return (b['created_at']?.toString() ?? '').compareTo(
          a['created_at']?.toString() ?? '',
        );
      });
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des utilisateurs: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      if (_users.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث قائمة المستخدمين'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filtres
  // ---------------------------------------------------------------------------

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedRoleFilter != 'all' ||
      _selectedValidationFilter != 'all';

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedRoleFilter = 'all';
      _selectedValidationFilter = 'all';
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    return _users.where((user) {
      if (_selectedRoleFilter != 'all' && user['role'] != _selectedRoleFilter) {
        return false;
      }

      final isValidated = user['is_validated'] == true;
      if (_selectedValidationFilter == 'validated' && !isValidated) {
        return false;
      }
      if (_selectedValidationFilter == 'unvalidated' && isValidated) {
        return false;
      }

      if (query.isEmpty) return true;
      final email = user['email']?.toString().toLowerCase() ?? '';
      final fullName = user['full_name']?.toString().toLowerCase() ?? '';
      return email.contains(query) || fullName.contains(query);
    }).toList();
  }

  int _countByRole(String roleCode) =>
      _users.where((u) => u['role'] == roleCode).length;

  int get _unvalidatedCount =>
      _users.where((u) => u['is_validated'] != true).length;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> _openUserManagement(Map<String, dynamic> user) async {
    // Vérifier الصلاحيات
    final canAssignRoles = await PermissionService().canAssignRoles();
    if (!mounted) return;
    if (!canAssignRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية إدارة المستخدمين'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final changed = await context.push<bool>(
      '/admin/users/${user['id']}/manage',
    );

    // Utilisateur modifié ou supprimé : recharger la liste
    if (changed == true && mounted) _loadUsers();
  }

  // ---------------------------------------------------------------------------
  // Helpers d'affichage
  // ---------------------------------------------------------------------------

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.admin:
        return Icons.settings_rounded;
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

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  /// Statistiques cliquables : un appui filtre la liste
  Widget _buildStatsRow() {
    Widget stat({
      required String label,
      required int value,
      required IconData icon,
      required Color color,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: AppStatTile(
          label: label,
          value: '$value',
          icon: icon,
          color: color,
          selected: selected,
          onTap: onTap,
        ),
      );
    }

    return Row(
      children: [
        stat(
          label: 'الكل',
          value: _users.length,
          icon: Icons.people_alt_rounded,
          color: AppTheme.primaryColor,
          selected: !_hasActiveFilters,
          onTap: _clearFilters,
        ),
        const SizedBox(width: AppTheme.spacingS),
        stat(
          label: 'بانتظار التوثيق',
          value: _unvalidatedCount,
          icon: Icons.pending_rounded,
          color: AppTheme.warningColor,
          selected: _selectedValidationFilter == 'unvalidated',
          onTap:
              () => setState(() {
                _selectedValidationFilter =
                    _selectedValidationFilter == 'unvalidated'
                        ? 'all'
                        : 'unvalidated';
              }),
        ),
        const SizedBox(width: AppTheme.spacingS),
        stat(
          label: 'المحكمون',
          value: _countByRole(UserRole.jury.code),
          icon: Icons.gavel_rounded,
          color: AppTheme.infoColor,
          selected: _selectedRoleFilter == UserRole.jury.code,
          onTap:
              () => setState(() {
                _selectedRoleFilter =
                    _selectedRoleFilter == UserRole.jury.code
                        ? 'all'
                        : UserRole.jury.code;
              }),
        ),
        const SizedBox(width: AppTheme.spacingS),
        stat(
          label: 'المديرون',
          value: _countByRole(UserRole.admin.code),
          icon: Icons.admin_panel_settings_rounded,
          color: AppTheme.primaryColor,
          selected: _selectedRoleFilter == UserRole.admin.code,
          onTap:
              () => setState(() {
                _selectedRoleFilter =
                    _selectedRoleFilter == UserRole.admin.code
                        ? 'all'
                        : UserRole.admin.code;
              }),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppTheme.spacingXS),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppTheme.primaryColor.withOpacity(0.15),
          labelStyle: AppTheme.labelMedium.copyWith(
            color: selected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    void selectRole(String code) => setState(() => _selectedRoleFilter = code);
    void selectValidation(String value) =>
        setState(() => _selectedValidationFilter = value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSearchBar(
          controller: _searchController,
          hintText: 'البحث بالاسم أو البريد الإلكتروني...',
          margin: EdgeInsets.zero,
          onChanged: _onSearchChanged,
          onClear: () {
            _debounceTimer?.cancel();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: AppTheme.spacingS),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                'جميع الأدوار',
                _selectedRoleFilter == 'all',
                () => selectRole('all'),
              ),
              for (final role in UserRole.values)
                chip(
                  '${role.displayName} (${_countByRole(role.code)})',
                  _selectedRoleFilter == role.code,
                  () => selectRole(role.code),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                'كل الحسابات',
                _selectedValidationFilter == 'all',
                () => selectValidation('all'),
              ),
              chip(
                'موثقة',
                _selectedValidationFilter == 'validated',
                () => selectValidation('validated'),
              ),
              chip(
                'غير موثقة ($_unvalidatedCount)',
                _selectedValidationFilter == 'unvalidated',
                () => selectValidation('unvalidated'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = UserRole.fromString(user['role'] ?? 'membre');
    final roleColor = _getRoleColor(role);
    final isValidated = user['is_validated'] == true;
    final email = user['email']?.toString() ?? '';
    final fullName = user['full_name']?.toString().trim() ?? '';
    final phone = user['phone']?.toString().trim() ?? '';
    final label = fullName.isNotEmpty ? fullName : email;
    final initial = label.isNotEmpty ? label.characters.first : '?';

    return AppListCard(
      onTap: () => _openUserManagement(user),
      // Liseré orange : compte en attente de vérification
      highlightColor: isValidated ? null : AppTheme.warningColor,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: roleColor.withValues(alpha: 0.12),
        child: Text(
          initial.toUpperCase(),
          style: AppTheme.headingSmall.copyWith(
            color: roleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: label,
      subtitle: [
        if (fullName.isNotEmpty && email.isNotEmpty) email,
        if (phone.isNotEmpty) '\u200E$phone',
      ].join('\n'),
      tags: [
        AppTag(
          text: role.displayName,
          color: roleColor,
          icon: _getRoleIcon(role),
        ),
        AppTag(
          text: isValidated ? 'موثق' : 'غير موثق',
          color: isValidated ? AppTheme.successColor : AppTheme.warningColor,
          icon: isValidated ? Icons.verified_rounded : Icons.pending_rounded,
        ),
        AppTag(
          text: 'أنشئ ${_formatDate(user['created_at'])}',
          color: AppTheme.textSecondaryColor,
          icon: Icons.calendar_today_rounded,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (!_hasActiveFilters) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'لا يوجد مستخدمون',
        subtitle: 'لم يتم إنشاء أي حساب بعد',
      );
    }

    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'لا توجد نتائج',
      subtitle: 'لا يوجد مستخدم يطابق البحث أو المرشحات المختارة',
      action: SecondaryButton(
        text: 'مسح المرشحات',
        icon: Icons.clear_rounded,
        onPressed: _clearFilters,
      ),
    );
  }

  Widget _buildErrorState() {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      iconColor: AppTheme.errorColor,
      title: 'تعذر تحميل المستخدمين',
      subtitle: 'تحقق من الاتصال وحاول مجدداً',
      action: PrimaryButton(
        text: 'إعادة المحاولة',
        icon: Icons.refresh_rounded,
        onPressed: _loadUsers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Attendre que les permissions soient chargées
    if (_isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAdmin == false) {
      return const AccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
      return const ModernLoadingIndicator(message: 'جاري تحميل المستخدمين...');
    }

    if (_hasError && _users.isEmpty) {
      return Center(child: SingleChildScrollView(child: _buildErrorState()));
    }

    final users = _filteredUsers;

    return ModernPullToRefresh(
      onRefresh: _loadUsers,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildFilters(),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    _hasActiveFilters
                        ? '${users.length} من ${_users.length} مستخدم'
                        : '${_users.length} مستخدم',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (users.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildUserCard(users[index]),
                  childCount: users.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingL)),
        ],
      ),
    );
  }
}
