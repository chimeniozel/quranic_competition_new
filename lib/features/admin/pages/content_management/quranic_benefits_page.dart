import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';

class QuranicBenefitsPage extends StatefulWidget {
  const QuranicBenefitsPage({super.key});

  @override
  State<QuranicBenefitsPage> createState() => _QuranicBenefitsPageState();
}

class _QuranicBenefitsPageState extends State<QuranicBenefitsPage> {
  final QuranicBenefitService _benefitService = QuranicBenefitService();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final ScrollController _scrollController = ScrollController();

  List<QuranicBenefit> _benefits = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBenefits(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Annuler le timer précédent s'il existe
    _debounceTimer?.cancel();

    // Mettre à jour le texte affiché immédiatement
    setState(() {
      _searchText = value;
    });

    // Mettre à jour la query pour la recherche
    _searchQuery = value;

    // Créer un nouveau timer pour la recherche avec debounce
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      print('🔍 Recherche déclenchée avec: "$value"');
      _loadBenefits(reset: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreBenefits();
      }
    }
  }

  Future<void> _loadBenefits({bool reset = true}) async {
    if (_isLoading) return;

    print('📡 _loadBenefits appelée - reset: $reset, query: "$_searchQuery"');

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
      }
    });

    try {
      final result = await _benefitService.getBenefitsWithPagination(
        searchQuery: _searchQuery,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _benefits = result['benefits'] as List<QuranicBenefit>;
        } else {
          _benefits.addAll(result['benefits'] as List<QuranicBenefit>);
        }
        _totalCount = result['totalCount'] as int;
        _hasMore = result['hasMore'] as bool;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفوائد القرآنية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreBenefits() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadBenefits(reset: false);
  }

  Future<void> _checkPermissionAndEdit(QuranicBenefit benefit) async {
    context.push('/admin/quranic-benefits/edit/${benefit.id}');
  }

  Future<void> _deleteBenefit(QuranicBenefit benefit) async {
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف الفائدة القرآنية "${benefit.title}"؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await _benefitService.deleteBenefit(benefit.id);
      if (success) {
        setState(() {
          _benefits.removeWhere((b) => b.id == benefit.id);
          _totalCount--;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الفائدة القرآنية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطأ في حذف الفائدة القرآنية'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleBenefitStatus(QuranicBenefit benefit) async {
    final success = await _benefitService.toggleBenefitStatus(
      benefit.id,
      !benefit.isActive,
    );

    if (success) {
      setState(() {
        final index = _benefits.indexWhere((b) => b.id == benefit.id);
        if (index != -1) {
          _benefits[index] = benefit.copyWith(isActive: !benefit.isActive);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              benefit.isActive ? 'تم إلغاء تفعيل الفائدة' : 'تم تفعيل الفائدة',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في تغيير حالة الفائدة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'البحث في الفوائد القرآنية...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchText.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged(
                        '',
                      ); // Déclencher la recherche avec une chaîne vide
                    },
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(QuranicBenefit benefit) {
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
                  child: Text(
                    benefit.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _checkPermissionAndEdit(benefit);
                        break;
                      case 'toggle_status':
                        _toggleBenefitStatus(benefit);
                        break;
                      case 'delete':
                        _deleteBenefit(benefit);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) {
                        final items = <PopupMenuEntry<String>>[];
                        final permissionService = PermissionService();
                        
                        // إضافة عنصر التعديل فقط إذا كانت الصلاحية متوفرة
                        if (permissionService.canModifySync()) {
                          items.add(
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('تعديل'),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        // إضافة عنصر التفعيل/إلغاء التفعيل فقط إذا كانت الصلاحية متوفرة
                        if (permissionService.canModifySync()) {
                          items.add(
                            PopupMenuItem(
                              value: 'toggle_status',
                              child: Row(
                                children: [
                                  Icon(
                                    benefit.isActive
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    benefit.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                                  ),
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
                                  Text('حذف', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        return items;
                      },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              benefit.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  benefit.authorName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: benefit.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    benefit.isActive ? 'مفعل' : 'غير مفعل',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الإنشاء: ${_formatDate(benefit.createdAt)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الفوائد القرآنية'),
            if (_totalCount > 0)
              Text(
                'إجمالي: $_totalCount فائدة',
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
            onPressed: () => _loadBenefits(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _isLoading
              ? Expanded(
                child: const Center(child: CircularProgressIndicator()),
              )
              : Expanded(
                child:
                    _benefits.isEmpty && !_isLoading
                        ? const Center(
                          child: Text(
                            'لا توجد فوائد قرآنية',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          itemCount: _benefits.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _benefits.length) {
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
                                        onPressed: _loadMoreBenefits,
                                        child: const Text('تحميل المزيد'),
                                      ),
                                    ),
                                  )
                                  : const SizedBox.shrink();
                            }
                            return _buildBenefitCard(_benefits[index]);
                          },
                        ),
              ),
        ],
      ),
      floatingActionButton: CanModifyGuard(
        child: FloatingActionButton(
          onPressed: () {
            context.push('/admin/quranic-benefits/add');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
