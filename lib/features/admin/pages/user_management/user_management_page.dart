import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/features/shared/pages/access_denied_page.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _canDelete = false;
  String? _currentUserId;

  // Mode sélection : suppression groupée des comptes non confirmés
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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
    final permissions = PermissionService();
    final isAdmin = await permissions.hasAdminPermissions();
    final canDelete = isAdmin && await permissions.canDelete();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _canDelete = canDelete;
      _currentUserId = Supabase.instance.client.auth.currentUser?.id;
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
        // Une sélection ne garde que les comptes encore présents
        _selectedIds.retainWhere((id) => users.any((u) => u['id'] == id));
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

  void _toggleRoleFilter(String code) => setState(
    () => _selectedRoleFilter = _selectedRoleFilter == code ? 'all' : code,
  );

  void _toggleValidationFilter(String value) => setState(
    () =>
        _selectedValidationFilter =
            _selectedValidationFilter == value ? 'all' : value,
  );

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
  // Sélection et suppression groupée
  // ---------------------------------------------------------------------------

  /// Seuls les comptes non confirmés sont supprimables en groupe ; jamais un
  /// مدير عام ni son propre compte.
  bool _isSelectable(Map<String, dynamic> user) =>
      user['is_validated'] != true &&
      user['role'] != UserRole.superAdmin.code &&
      user['id'] != _currentUserId;

  List<Map<String, dynamic>> get _selectableUsers =>
      _filteredUsers.where(_isSelectable).toList();

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      // On n'affiche que les comptes concernés
      _selectedValidationFilter = 'unvalidated';
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(Map<String, dynamic> user) {
    if (!_isSelectable(user)) return;
    final id = user['id'] as String;
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _toggleSelectAll() {
    final selectable = _selectableUsers.map((u) => u['id'] as String).toSet();
    setState(() {
      if (selectable.every(_selectedIds.contains)) {
        _selectedIds.removeAll(selectable);
      } else {
        _selectedIds.addAll(selectable);
      }
    });
  }

  String _userLabel(Map<String, dynamic> user) {
    final name = user['full_name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : (user['email']?.toString() ?? '');
  }

  Future<void> _deleteSelected() async {
    final targets =
        _users.where((u) => _selectedIds.contains(u['id'])).toList();
    if (targets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) =>
              _BulkDeleteConfirmDialog(names: targets.map(_userLabel).toList()),
    );
    if (confirmed != true || !mounted) return;

    final ids = targets.map((u) => u['id'] as String).toList();
    final result = await showDialog<BulkDeleteResult>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _BulkDeleteProgressDialog(
            total: ids.length,
            run:
                (onProgress) => _userService.deleteUnvalidatedUsers(
                  ids,
                  onProgress: onProgress,
                ),
          ),
    );
    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حذف الحسابات، حاول مجدداً'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Retrait immédiat de la liste, puis synchronisation en arrière-plan
    final deleted = result.deletedIds.toSet();
    setState(() {
      _users.removeWhere((u) => deleted.contains(u['id']));
      _selectionMode = false;
      _selectedIds.clear();
    });
    _loadUsers();

    final parts = <String>[
      if (deleted.isNotEmpty) 'تم حذف ${deleted.length} حساب',
      if (result.skippedIds.isNotEmpty)
        '${result.skippedIds.length} محكم مسند لجولة (لم يُحذف)',
      if (result.failedIds.isNotEmpty)
        'تعذر حذف ${result.failedIds.length} حساب',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' · ')),
        backgroundColor:
            result.failedIds.isEmpty && result.skippedIds.isEmpty
                ? AppTheme.successColor
                : AppTheme.warningColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> _openUserManagement(Map<String, dynamic> user) async {
    // En mode sélection, un appui coche / décoche le compte
    if (_selectionMode) {
      _toggleSelection(user);
      return;
    }

    final canAssignRoles = await PermissionService().canAssignRoles();
    if (!mounted) return;
    if (!canAssignRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ليس لديك صلاحية إدارة المستخدمين'),
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
        return AppTheme.secondaryColor;
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

  Widget _buildHeader() {
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

    return AppGradientHeader(
      icon: Icons.manage_accounts_rounded,
      title: 'إدارة المستخدمين',
      subtitle: 'الحسابات والأدوار والتوثيق',
      // Statistiques cliquables : un appui filtre la liste
      bottom: Row(
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
            label: 'غير موثقة',
            value: _unvalidatedCount,
            icon: Icons.pending_rounded,
            color: AppTheme.warningColor,
            selected: _selectedValidationFilter == 'unvalidated',
            onTap: () => _toggleValidationFilter('unvalidated'),
          ),
          const SizedBox(width: AppTheme.spacingS),
          stat(
            label: 'المحكمون',
            value: _countByRole(UserRole.jury.code),
            icon: Icons.gavel_rounded,
            color: AppTheme.infoColor,
            selected: _selectedRoleFilter == UserRole.jury.code,
            onTap: () => _toggleRoleFilter(UserRole.jury.code),
          ),
          const SizedBox(width: AppTheme.spacingS),
          stat(
            label: 'المديرون',
            value: _countByRole(UserRole.admin.code),
            icon: Icons.manage_accounts_rounded,
            color: AppTheme.secondaryColor,
            selected: _selectedRoleFilter == UserRole.admin.code,
            onTap: () => _toggleRoleFilter(UserRole.admin.code),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppTheme.spacingXS),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return AppSection(
      icon: Icons.filter_list_rounded,
      title: 'البحث والتصفية',
      trailing:
          _hasActiveFilters && !_selectionMode
              ? TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('مسح'),
              )
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'كل الأدوار',
                  _selectedRoleFilter == 'all',
                  () => setState(() => _selectedRoleFilter = 'all'),
                ),
                for (final role in UserRole.values)
                  chip(
                    '${role.displayName} (${_countByRole(role.code)})',
                    _selectedRoleFilter == role.code,
                    () => setState(() => _selectedRoleFilter = role.code),
                  ),
              ],
            ),
          ),
          // En mode sélection, la liste reste sur les comptes non confirmés
          if (!_selectionMode)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(
                    'كل الحسابات',
                    _selectedValidationFilter == 'all',
                    () => setState(() => _selectedValidationFilter = 'all'),
                  ),
                  chip(
                    'موثقة',
                    _selectedValidationFilter == 'validated',
                    () =>
                        setState(() => _selectedValidationFilter = 'validated'),
                  ),
                  chip(
                    'غير موثقة ($_unvalidatedCount)',
                    _selectedValidationFilter == 'unvalidated',
                    () => setState(
                      () => _selectedValidationFilter = 'unvalidated',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Bandeau du mode sélection : explication + « tout sélectionner »
  Widget _buildSelectionBanner() {
    final selectable = _selectableUsers;
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every((u) => _selectedIds.contains(u['id']));

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_sweep_rounded, color: AppTheme.errorColor),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'اختر الحسابات غير الموثقة المراد حذفها',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: selectable.isEmpty ? null : _toggleSelectAll,
            icon: Icon(
              allSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
            ),
            label: Text(allSelected ? 'إلغاء الكل' : 'تحديد الكل'),
          ),
        ],
      ),
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

    final selectable = _selectionMode && _isSelectable(user);
    final selected = _selectedIds.contains(user['id']);

    final avatar = CircleAvatar(
      radius: 24,
      backgroundColor: roleColor.withValues(alpha: 0.12),
      child: Text(
        initial.toUpperCase(),
        style: AppTheme.headingSmall.copyWith(
          color: roleColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Opacity(
      // En mode sélection, les comptes non sélectionnables sont atténués
      opacity: _selectionMode && !selectable ? 0.45 : 1,
      child: AppListCard(
        onTap: () => _openUserManagement(user),
        highlightColor:
            selected
                ? AppTheme.errorColor
                : isValidated
                ? null
                : AppTheme.warningColor,
        leading:
            _selectionMode
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged:
                          selectable ? (_) => _toggleSelection(user) : null,
                      activeColor: AppTheme.errorColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    avatar,
                  ],
                )
                : avatar,
        title: label,
        subtitle: [
          if (fullName.isNotEmpty && email.isNotEmpty) email,
          if (phone.isNotEmpty) '‎$phone',
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
            text: _formatDate(user['created_at']),
            color: AppTheme.textSecondaryColor,
            icon: Icons.calendar_today_rounded,
          ),
        ],
        trailing: _selectionMode ? const SizedBox.shrink() : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_selectionMode) {
      return const EmptyState(
        icon: Icons.verified_user_rounded,
        title: 'لا توجد حسابات غير موثقة',
        subtitle: 'جميع الحسابات موثقة، لا يوجد ما يُحذف',
      );
    }
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
        icon: Icons.close_rounded,
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

    return PopScope(
      // Le retour quitte d'abord le mode sélection
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        appBar:
            _selectionMode
                ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إلغاء التحديد',
                    onPressed: _exitSelectionMode,
                  ),
                  title: Text(
                    _selectedIds.isEmpty
                        ? 'تحديد الحسابات'
                        : '${_selectedIds.length} محدد',
                  ),
                )
                : AppBar(
                  title: const Text('إدارة المستخدمين'),
                  actions: [
                    if (_canDelete && _unvalidatedCount > 0)
                      IconButton(
                        onPressed: _isLoading ? null : _enterSelectionMode,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        tooltip: 'حذف الحسابات غير الموثقة',
                      ),
                    IconButton(
                      onPressed: _isLoading ? null : _loadUsers,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'تحديث',
                    ),
                  ],
                ),
        body: _buildBody(),
        // Barre d'action de la suppression groupée
        bottomNavigationBar:
            _selectionMode
                ? Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton.icon(
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      style: AppButtonStyles.filled(AppTheme.errorColor),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: Text(
                        _selectedIds.isEmpty
                            ? 'اختر حسابات للحذف'
                            : 'حذف ${_selectedIds.length} حساب',
                      ),
                    ),
                  ),
                )
                : null,
      ),
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
          if (!_selectionMode) SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectionMode) ...[
                    _buildSelectionBanner(),
                    const SizedBox(height: AppTheme.spacingM),
                  ],
                  _buildFilters(),
                  const SizedBox(height: AppTheme.spacingM),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 18,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hasActiveFilters
                            ? '${users.length} من ${_users.length} مستخدم'
                            : '${_users.length} مستخدم',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

// -----------------------------------------------------------------------------
// Suppression groupée
// -----------------------------------------------------------------------------

/// Confirmation : nombre de comptes et premiers noms concernés
class _BulkDeleteConfirmDialog extends StatelessWidget {
  final List<String> names;

  const _BulkDeleteConfirmDialog({required this.names});

  @override
  Widget build(BuildContext context) {
    const shown = 5;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  size: 32,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'حذف ${names.length} حساب غير موثق',
              textAlign: TextAlign.center,
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.pageBackgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in names.take(shown))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (names.length > shown)
                    Text(
                      'و ${names.length - shown} حساب آخر',
                      style: AppTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            const AppNotice(
              text:
                  'سيتم حذف هذه الحسابات نهائياً ولا يمكن التراجع عن هذا الإجراء.',
              color: AppTheme.errorColor,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: AppButtonStyles.outlined(
                      AppTheme.textSecondaryColor,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: AppButtonStyles.filled(AppTheme.errorColor),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const FittedBox(child: Text('حذف نهائياً')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lance la suppression groupée en affichant la progression, puis renvoie
/// le bilan (null en cas d'échec global).
class _BulkDeleteProgressDialog extends StatefulWidget {
  final int total;
  final Future<BulkDeleteResult> Function(
    void Function(int done, int total) onProgress,
  )
  run;

  const _BulkDeleteProgressDialog({required this.total, required this.run});

  @override
  State<_BulkDeleteProgressDialog> createState() =>
      _BulkDeleteProgressDialogState();
}

class _BulkDeleteProgressDialogState extends State<_BulkDeleteProgressDialog> {
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    BulkDeleteResult? result;
    try {
      result = await widget.run((done, _) {
        if (mounted) setState(() => _done = done);
      });
    } catch (e) {
      debugPrint('Suppression groupée impossible: $e');
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'جاري حذف الحسابات...',
                textAlign: TextAlign.center,
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingM),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _done == 0 ? null : _done / total,
                  minHeight: 8,
                  color: AppTheme.errorColor,
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _done == 0 ? '$total حساب' : '$_done / $total',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
