import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

class TajweedRulesPage extends StatefulWidget {
  const TajweedRulesPage({super.key});

  @override
  State<TajweedRulesPage> createState() => _TajweedRulesPageState();
}

class _TajweedRulesPageState extends State<TajweedRulesPage> {
  final TajweedRuleService _ruleService = TajweedRuleService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<TajweedRule> _rules = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _searchQuery = '';
  TajweedType? _selectedType;
  Timer? _debounceTimer;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRules(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _searchText = value;
    });
    _searchQuery = value;
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadRules(reset: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreRules();
      }
    }
  }

  Future<void> _loadRules({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
      }
    });

    try {
      final result = await _ruleService.getRulesWithPagination(
        searchQuery: _searchQuery,
        typeFilter: _selectedType,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _rules = result['rules'] as List<TajweedRule>;
        } else {
          _rules.addAll(result['rules'] as List<TajweedRule>);
        }
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
            content: Text('خطأ في تحميل قواعد التجويد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreRules() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadRules(reset: false);
  }

  Future<void> _toggleRuleStatus(TajweedRule rule) async {
    try {
      await _ruleService.toggleRuleStatus(rule.id);
      await _loadRules(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rule.isActive ? 'تم إلغاء التفعيل' : 'تم التفعيل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تغيير الحالة : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRule(TajweedRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من الحذف "${rule.title}"؟'),
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
      try {
        await _ruleService.deleteRule(rule.id);
        await _loadRules(reset: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحذف بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'البحث في قواعد التجويد...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchText.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Filtres de type
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('الكل'),
                  selected: _selectedType == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('منشورات'),
                  selected: _selectedType == TajweedType.post,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? TajweedType.post : null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('فيديوهات'),
                  selected: _selectedType == TajweedType.video,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? TajweedType.video : null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(TajweedRule rule) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      onTap: () => context.push('/admin/tajweed-rules/edit/${rule.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      rule.type == TajweedType.post
                          ? AppTheme.infoColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  rule.type == TajweedType.post
                      ? Icons.auto_stories
                      : Icons.warning,
                  color:
                      rule.type == TajweedType.post
                          ? AppTheme.infoColor
                          : AppTheme.errorColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.content,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      rule.type == TajweedType.post
                          ? AppTheme.infoColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        rule.type == TajweedType.post
                            ? AppTheme.infoColor
                            : AppTheme.errorColor,
                  ),
                ),
                child: Text(
                  rule.type.displayName,
                  style: TextStyle(
                    color:
                        rule.type == TajweedType.post
                            ? AppTheme.infoColor
                            : AppTheme.errorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      rule.isActive
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        rule.isActive
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                  ),
                ),
                child: Text(
                  rule.isActive ? 'نشط' : 'غير نشط',
                  style: TextStyle(
                    color:
                        rule.isActive
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'تم الإنشاء: ${_formatDate(rule.createdAt)}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push('/admin/tajweed-rules/edit/${rule.id}');
                      break;
                    case 'toggle':
                      _toggleRuleStatus(rule);
                      break;
                    case 'delete':
                      _deleteRule(rule);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              rule.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 16,
                              color:
                                  rule.isActive
                                      ? AppTheme.warningColor
                                      : AppTheme.successColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rule.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                              style: TextStyle(
                                color:
                                    rule.isActive
                                        ? AppTheme.warningColor
                                        : AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 16,
                              color: AppTheme.errorColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'حذف',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد قواعد تجويد تطابق البحث'
                  : 'لا توجد قواعد تجويد متاحة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'ابدأ بإضافة قواعد جديدة',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أحكام التجويد',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRules(reset: true),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: ModernFAB(
        onPressed: () => context.push('/admin/tajweed-rules/add'),
        icon: Icons.add,
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () => _loadRules(reset: true),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search and Filters Section
                      DashboardSection(
                        title: 'البحث والتصفية',
                        subtitle: 'البحث في قواعد التجويد وتصفيتها',
                        child: _buildSearchAndFilters(),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Rules List Section
                      DashboardSection(
                        title: 'قواعد التجويد',
                        subtitle: '${_rules.length} قاعدة',
                        child:
                            _rules.isEmpty && !_isLoading
                                ? _buildEmptyState()
                                : Column(
                                  children: [
                                    ..._rules.map(
                                      (rule) => _buildRuleCard(rule),
                                    ),
                                    if (_isLoadingMore)
                                      const Padding(
                                        padding: EdgeInsets.all(
                                          AppTheme.spacingM,
                                        ),
                                        child: CircularProgressIndicator(),
                                      ),
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
