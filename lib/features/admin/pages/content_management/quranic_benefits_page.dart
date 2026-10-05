import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';

class QuranicBenefitsPage extends StatefulWidget {
  const QuranicBenefitsPage({super.key});

  @override
  State<QuranicBenefitsPage> createState() => _QuranicBenefitsPageState();
}

class _QuranicBenefitsPageState extends State<QuranicBenefitsPage> {
  final QuranicBenefitService _benefitService = QuranicBenefitService();
  final TextEditingController _searchController = TextEditingController();
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

    // Mettre à jour la query pour la recherche
    setState(() {
      _searchQuery = value;
    });

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
            backgroundColor: AppTheme.errorColor,
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
    // Vérifier الصلاحيات
    final canDelete = await PermissionService().canDelete();
    if (!canDelete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ليس لديك صلاحية حذف الفوائد القرآنية'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    final confirmed = await ModernDialog.showConfirm(
      context,
      title: 'تأكيد الحذف',
      message:
          'هل أنت متأكد من حذف الفائدة القرآنية "${benefit.title}"؟ لا يمكن التراجع عن هذه العملية.',
      confirmText: 'حذف',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed == true) {
      try {
        // Utiliser permanentDeleteBenefit pour supprimer définitivement
        final success = await _benefitService.permanentDeleteBenefit(
          benefit.id,
        );
        if (success) {
          setState(() {
            _benefits.removeWhere((b) => b.id == benefit.id);
            _totalCount--;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الفائدة القرآنية بنجاح'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('خطأ في حذف الفائدة القرآنية'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Erreur lors de la suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الفائدة القرآنية: $e'),
              backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في تغيير حالة الفائدة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return ModernSearchBar(
      controller: _searchController,
      hintText: 'البحث في الفوائد القرآنية...',
      onChanged: _onSearchChanged,
      onClear: () => _onSearchChanged(''),
      margin: const EdgeInsets.all(AppTheme.spacingM),
    );
  }

  Widget _buildBenefitCard(QuranicBenefit benefit) {
    final statusColor =
        benefit.isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: Icons.menu_book_rounded, color: statusColor),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppTheme.spacingXS,
                      runSpacing: AppTheme.spacingXS,
                      children: [
                        AppTag(
                          text: benefit.isActive ? 'منشورة' : 'غير منشورة',
                          color: statusColor,
                          icon:
                              benefit.isActive
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                        ),
                        AppTag(
                          text: _formatDate(benefit.createdAt),
                          color: AppTheme.textSecondaryColor,
                          icon: Icons.calendar_today_rounded,
                        ),
                        if (benefit.authorName.isNotEmpty)
                          AppTag(
                            text: benefit.authorName,
                            color: AppTheme.textSecondaryColor,
                            icon: Icons.person_rounded,
                          ),
                      ],
                    ),
                  ],
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
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  final permissionService = PermissionService();

                  // إضافة عنصر التعديل فقط إذا كانت الصلاحية متوفرة
                  if (permissionService.canModifySync()) {
                    items.add(
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded),
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
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            const SizedBox(width: 8),
                            Text(benefit.isActive ? 'إلغاء التفعيل' : 'تفعيل'),
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
                            Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                            SizedBox(width: 8),
                            Text(
                              'حذف',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
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
          const SizedBox(height: AppTheme.spacingS),
          Text(
            benefit.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(height: 1.6),
          ),
        ],
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
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadBenefits(reset: true),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _isLoading
              ? Expanded(child: const LoadingOverlay(child: SizedBox()))
              : Expanded(
                child:
                    _benefits.isEmpty && !_isLoading
                        ? EmptyState(
                          icon: Icons.menu_book_rounded,
                          title: 'لا توجد فوائد قرآنية',
                          subtitle: 'لم يتم إضافة أي فوائد قرآنية بعد',
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.spacingM,
                            0,
                            AppTheme.spacingM,
                            80,
                          ),
                          itemCount: _benefits.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _benefits.length) {
                              return _isLoadingMore
                                  ? const Padding(
                                    padding: EdgeInsets.all(AppTheme.spacingM),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                  : _hasMore
                                  ? Padding(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingM,
                                    ),
                                    child: Center(
                                      child: SecondaryButton(
                                        onPressed: _loadMoreBenefits,
                                        text: 'تحميل المزيد',
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
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/admin/quranic-benefits/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('فائدة جديدة'),
        ),
      ),
    );
  }
}
