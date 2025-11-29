import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';

class UserManagePage extends StatefulWidget {
  const UserManagePage({super.key});

  @override
  State<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends State<UserManagePage> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AppUser> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _selectedFilter = 'all'; // all, verified, unverified, jury, admin
  String _searchQuery = '';
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _users.clear();
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _userService.getUsersWithPagination(
        page: _currentPage,
        limit: 20,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        filter: _selectedFilter != 'all' ? _selectedFilter : null,
      );

      setState(() {
        if (reset) {
          _users = result['users'] as List<AppUser>;
        } else {
          _users.addAll(result['users'] as List<AppUser>);
        }
        _totalCount = result['totalCount'] as int;
        _hasMore = result['hasMore'] as bool;
        _currentPage = result['currentPage'] as int;
      });
    } catch (e) {
      _showErrorSnackBar('خطأ أثناء تحميل المستخدمين: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    _loadUsers(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreUsers();
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _currentPage++);
    await _loadUsers(reset: false);
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    _loadUsers(reset: true);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _toggleUserVerification(AppUser user) async {
    // Vérifier الصلاحيات
    final canValidate = await PermissionService().canValidateAccounts();
    if (!canValidate) {
      _showErrorSnackBar('ليس لديك صلاحية التحقق من الحسابات');
      return;
    }

    try {
      await _userService.updateUserVerificationStatus(
        userId: user.id,
        isVerified: !user.isVerified,
      );

      // Mettre à jour la liste locale
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = AppUser(
          id: user.id,
          fullName: user.fullName,
          phone: user.phone,
          email: user.email,
          role: user.role,
          isVerified: !user.isVerified,
          createdAt: user.createdAt,
        );
        setState(() {});
      }

      _showSuccessSnackBar(
        user.isVerified ? 'تم إلغاء توثيق المستخدم' : 'تم توثيق المستخدم بنجاح',
      );
    } catch (e) {
      _showErrorSnackBar('خطأ أثناء تحديث حالة المستخدم: $e');
    }
  }

  Future<void> _updateUserRole(AppUser user, String newRole) async {
    // Vérifier الصلاحيات
    final canAssignRoles = await PermissionService().canAssignRoles();
    if (!canAssignRoles) {
      _showErrorSnackBar('ليس لديك صلاحية تعيين الأدوار');
      return;
    }

    try {
      await _userService.updateUserRole(userId: user.id, newRole: newRole);

      // Mettre à jour la liste locale
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = AppUser(
          id: user.id,
          fullName: user.fullName,
          phone: user.phone,
          email: user.email,
          role: newRole,
          isVerified: user.isVerified,
          createdAt: user.createdAt,
        );
        setState(() {});
      }

      _showSuccessSnackBar('تم تحديث دور المستخدم بنجاح');
    } catch (e) {
      _showErrorSnackBar('خطأ أثناء تحديث دور المستخدم: $e');
    }
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('موثق', 'verified'),
          _buildFilterChip('غير موثق', 'unverified'),
          _buildFilterChip('محكم', 'jury'),
          _buildFilterChip('مدير', 'admin'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          _onFilterChanged(value);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return ModernSearchBar(
      controller: _searchController,
      hintText: 'البحث عن المستخدمين...',
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.orange;
      case 'admin':
        return Colors.blue;
      case 'jury':
        return Colors.purple;
      case 'membre_ordinaire':
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'admin':
        return Icons.settings;
      case 'jury':
        return Icons.gavel;
      case 'membre_ordinaire':
      default:
        return Icons.person;
    }
  }

  Widget _buildUserCard(AppUser user) {
    final roleColor = _getRoleColor(user.role);
    final roleIcon = _getRoleIcon(user.role);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isVerified ? Colors.green : Colors.orange,
          child: Icon(
            user.isVerified ? Icons.verified : Icons.pending,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon, size: 14, color: roleColor),
                  const SizedBox(width: 4),
                  Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('البريد: ${user.email}'),
            Text('الهاتف: ${user.phone}'),
            const SizedBox(height: 4),
            Text(
              'الحالة: ${user.isVerified ? "موثق" : "غير موثق"}',
              style: TextStyle(
                color: user.isVerified ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle_verification':
                _toggleUserVerification(user);
                break;
              case 'change_role':
                _showRoleChangeDialog(user);
                break;
              case 'delete':
                _showDeleteConfirmation(user);
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            final permissionService = PermissionService();

            // إضافة عنصر التوثيق فقط إذا كانت الصلاحية متوفرة
            if (permissionService.canValidateAccountsSync()) {
              items.add(
                PopupMenuItem(
                  value: 'toggle_verification',
                  child: Row(
                    children: [
                      Icon(user.isVerified ? Icons.block : Icons.verified),
                      const SizedBox(width: 8),
                      Text(
                        user.isVerified ? 'إلغاء التوثيق' : 'توثيق المستخدم',
                      ),
                    ],
                  ),
                ),
              );
            }

            // إضافة عنصر تغيير الدور فقط إذا كانت الصلاحية متوفرة والمستخدم موثق
            if (user.isVerified && permissionService.canAssignRolesSync()) {
              items.add(
                PopupMenuItem(
                  value: 'change_role',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings),
                      SizedBox(width: 8),
                      Text('تغيير الدور'),
                    ],
                  ),
                ),
              );
            }

            // إضافة عنصر الحذف فقط إذا كانت الصلاحية متوفرة
            if (permissionService.canDeleteSync()) {
              items.add(
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف المستخدم', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            }

            return items;
          },
        ),
      ),
    );
  }

  void _showRoleChangeDialog(AppUser user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تغيير دور ${user.fullName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('محكم'),
                  leading: Radio<String>(
                    value: 'jury',
                    groupValue: user.role,
                    onChanged: (value) {
                      if (value != null) {
                        _updateUserRole(user, value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('مدير'),
                  leading: Radio<String>(
                    value: 'admin',
                    groupValue: user.role,
                    onChanged: (value) {
                      if (value != null) {
                        _updateUserRole(user, value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('مستخدم عادي'),
                  leading: Radio<String>(
                    value: 'membre_ordinaire',
                    groupValue: user.role,
                    onChanged: (value) {
                      if (value != null) {
                        _updateUserRole(user, value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(AppUser user) async {
    // Vérifier الصلاحيات
    final canDelete = await PermissionService().canDelete();
    if (!canDelete) {
      _showErrorSnackBar('ليس لديك صلاحية حذف المستخدمين');
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف المستخدم ${user.fullName}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _userService.deleteUser(user.id);
                    _users.removeWhere((u) => u.id == user.id);
                    setState(() {});
                    _showSuccessSnackBar('تم حذف المستخدم بنجاح');
                  } catch (e) {
                    _showErrorSnackBar('خطأ أثناء حذف المستخدم: $e');
                  }
                },
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'jury':
        return 'محكم';
      case 'admin':
        return 'مدير';
      case 'super_admin':
        return 'مدير عام';
      case 'membre_ordinaire':
        return 'مستخدم عادي';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة المستخدمين'),
            if (_totalCount > 0)
              Text(
                'إجمالي: $_totalCount مستخدم',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUsers(reset: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  Expanded(
                    child:
                        _users.isEmpty && !_isLoading
                            ? const Center(
                              child: Text(
                                'لا توجد مستخدمين',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            : RefreshIndicator(
                              onRefresh: () => _loadUsers(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _users.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _users.length) {
                                    // Indicateur de chargement en bas
                                    return _isLoadingMore
                                        ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                        : _hasMore
                                        ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: ElevatedButton(
                                              onPressed: _loadMoreUsers,
                                              child: const Text('تحميل المزيد'),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink();
                                  }
                                  return _buildUserCard(_users[index]);
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
