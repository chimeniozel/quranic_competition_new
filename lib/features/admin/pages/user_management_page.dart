import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_management_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? user['email'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['email'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تم الإنشاء: ${_formatDate(user['created_at'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getRoleColor(role)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        role.displayName,
                        style: TextStyle(
                          color: _getRoleColor(role),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions disponibles selon les permissions
            CanAssignRolesGuard(
              child: Row(
                children: [
                  Expanded(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _statistics;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات المستخدمين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي المستخدمين',
                    '${stats['total_users'] ?? 0}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'مستخدمون معتمدون',
                    '${stats['validated_users'] ?? 0}',
                    Icons.verified,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'مدير عام',
                    '${(stats['role_counts'] as Map?)?['super_admin'] ?? 0}',
                    Icons.admin_panel_settings,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'مدير',
                    '${(stats['role_counts'] as Map?)?['admin'] ?? 0}',
                    Icons.settings,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'عضو لجنة التحكيم',
                    '${(stats['role_counts'] as Map?)?['jury'] ?? 0}',
                    Icons.gavel,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'عضو عادي',
                    '${(stats['role_counts'] as Map?)?['member'] ?? 0}',
                    Icons.person,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
        return Colors.purple[600]!;
      case UserRole.admin:
        return Colors.blue[600]!;
      case UserRole.jury:
        return Colors.orange[600]!;
      case UserRole.member:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين والأدوار'),
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
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Statistiques
                    _buildStatisticsCard(),

                    // Barre de recherche et filtres
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText:
                                    'البحث بالاسم أو البريد الإلكتروني...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
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

                    const SizedBox(height: 16),

                    // Liste des utilisateurs
                    _filteredUsers.isEmpty
                        ? Container(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'لا يوجد مستخدمون'
                                      : 'لا توجد نتائج للبحث',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
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
                            const SizedBox(height: 16),
                          ],
                        ),
                  ],
                ),
              ),
    );
  }
}
