import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementService _userService = UserManagementService();

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _statistics = {};
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
      final stats = await _userService.getUserStatistics();

      setState(() {
        _users = users;
        _statistics = stats;
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
        await _loadUsers(); // Rafraîchir la liste

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

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = UserRole.fromString(user['role']);

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  _getRoleIcon(role),
                  color: _getRoleColor(role),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['full_name'] ?? user['email'],
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'],
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تم الإنشاء: ${_formatDate(user['created_at'])}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getRoleColor(role)),
                ),
                child: Text(
                  role.displayName,
                  style: TextStyle(
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Role Change Dropdown
          CanAssignRolesGuard(
            child: DropdownButtonFormField<UserRole>(
              value: role,
              decoration: const InputDecoration(
                labelText: 'تغيير الدور',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items:
                  UserRole.values.map((role) {
                    return DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
              onChanged: (newRole) {
                if (newRole != null && newRole != role) {
                  _updateUserRole(user, newRole);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _statistics;

    return DashboardSection(
      title: 'إحصائيات المستخدمين',
      subtitle: 'نظرة عامة على المستخدمين والأدوار',
      child: StatsGrid(
        stats: [
          StatCard(
            title: 'إجمالي المستخدمين',
            value: '${stats['total_users'] ?? 0}',
            icon: Icons.people,
            color: AppTheme.primaryColor,
          ),
          StatCard(
            title: 'مستخدمون معتمدون',
            value: '${stats['validated_users'] ?? 0}',
            icon: Icons.verified,
            color: AppTheme.successColor,
          ),
          StatCard(
            title: 'مدير عام',
            value: '${(stats['role_counts'] as Map?)?['super_admin'] ?? 0}',
            icon: Icons.admin_panel_settings,
            color: AppTheme.warningColor,
          ),
          StatCard(
            title: 'مدير',
            value: '${(stats['role_counts'] as Map?)?['admin'] ?? 0}',
            icon: Icons.settings,
            color: AppTheme.primaryColor,
          ),
          StatCard(
            title: 'عضو لجنة التحكيم',
            value: '${(stats['role_counts'] as Map?)?['jury'] ?? 0}',
            icon: Icons.gavel,
            color: AppTheme.infoColor,
          ),
          StatCard(
            title: 'عضو عادي',
            value: '${(stats['role_counts'] as Map?)?['member'] ?? 0}',
            icon: Icons.person,
            color: AppTheme.textSecondaryColor,
          ),
        ],
        crossAxisCount: 2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'إدارة المستخدمين والأدوار',
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
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadUsers,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistiques
                      _buildStatisticsCard(),

                      const SizedBox(height: AppTheme.spacingL),

                      // Barre de recherche et filtres
                      DashboardSection(
                        title: 'البحث والتصفية',
                        subtitle: 'البحث عن المستخدمين وتصفيتهم حسب الدور',
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText:
                                      'البحث بالاسم أو البريد الإلكتروني...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.backgroundColor,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            DropdownButton<String>(
                              value: _selectedRoleFilter,
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('جميع الأدوار'),
                                ),
                                ...UserRole.values.map((role) {
                                  return DropdownMenuItem<String>(
                                    value: role.code,
                                    child: Text(role.displayName),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRoleFilter = value ?? 'all';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Liste des utilisateurs
                      DashboardSection(
                        title: 'قائمة المستخدمين',
                        subtitle: '${_filteredUsers.length} مستخدم',
                        child:
                            _filteredUsers.isEmpty
                                ? Container(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 64,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'لا يوجد مستخدمون'
                                              : 'لا توجد نتائج للبحث',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'لم يتم إضافة أي مستخدمين بعد'
                                              : 'جرب تغيير معايير البحث',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children: [
                                    ..._filteredUsers.map(
                                      (user) => _buildUserCard(user),
                                    ),
                                    const SizedBox(height: AppTheme.spacingM),
                                  ],
                                ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
    );
  }
}
