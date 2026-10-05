import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
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
      _searchQuery = value;
    });
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
            content: Text('خطأ في تحميل أحكام التجويد: $e'),
            backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تغيير الحالة : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _checkPermissionAndEdit(TajweedRule rule) async {
    context.push('/admin/tajweed-rules/edit/${rule.id}');
  }

  Future<void> _deleteRule(TajweedRule rule) async {
    final confirmed = await ModernDialog.showConfirm(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من الحذف "${rule.title}"؟',
      confirmText: 'حذف',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed == true) {
      try {
        await _ruleService.deleteRule(rule.id);
        await _loadRules(reset: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحذف بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف : $e'),
              backgroundColor: AppTheme.errorColor,
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
        ModernSearchBar(
          controller: _searchController,
          hintText: 'البحث في أحكام التجويد...',
          onChanged: _onSearchChanged,
          onClear: () => _onSearchChanged(''),
          margin: const EdgeInsets.all(16.0),
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
    final isVideo = rule.type == TajweedType.video;
    final typeColor = isVideo ? AppTheme.accentColor : AppTheme.infoColor;

    return AppListCard(
      onTap: () => context.push('/admin/tajweed-rules/edit/${rule.id}'),
      leading: AppIconBadge(
        icon:
            isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.auto_stories_rounded,
        color: typeColor,
        size: 24,
      ),
      title: rule.title,
      subtitle: rule.content,
      tags: [
        AppTag(
          text: rule.type.displayName,
          color: typeColor,
          icon: isVideo ? Icons.videocam_rounded : Icons.article_rounded,
        ),
        AppTag(
          text: rule.isActive ? 'منشور' : 'غير منشور',
          color:
              rule.isActive
                  ? AppTheme.successColor
                  : AppTheme.textSecondaryColor,
          icon:
              rule.isActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
        ),
        AppTag(
          text: _formatDate(rule.createdAt),
          color: AppTheme.textSecondaryColor,
          icon: Icons.calendar_today_rounded,
        ),
      ],
      trailing: PopupMenuButton<String>(
        icon: appMenuIcon,
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _checkPermissionAndEdit(rule);
              break;
            case 'toggle':
              _toggleRuleStatus(rule);
              break;
            case 'delete':
              _deleteRule(rule);
              break;
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];
          final permissionService = PermissionService();

          // إضافة عنصر التعديل فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canModifySync()) {
            items.add(
              appMenuItem(
                value: 'edit',
                icon: Icons.edit_rounded,
                label: 'تعديل',
              ),
            );
          }

          // إضافة عنصر التفعيل/إلغاء التفعيل فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canModifySync()) {
            items.add(
              appMenuItem(
                value: 'toggle',
                icon:
                    rule.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                label: rule.isActive ? 'إلغاء التفعيل' : 'تفعيل',
              ),
            );
          }

          // إضافة عنصر الحذف فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canDeleteSync()) {
            items.add(
              appMenuItem(
                value: 'delete',
                icon: Icons.delete_rounded,
                label: 'حذف',
                color: AppTheme.errorColor,
              ),
            );
          }

          return items;
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon:
          _searchQuery.isNotEmpty
              ? Icons.search_off_rounded
              : Icons.auto_stories_rounded,
      title:
          _searchQuery.isNotEmpty
              ? 'لا توجد أحكام تجويد تطابق البحث'
              : 'لا توجد أحكام تجويد حالياً',
      subtitle:
          _searchQuery.isNotEmpty
              ? 'جرب البحث بكلمات مختلفة'
              : 'ابدأ بإضافة أحكام جديدة',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أحكام التجويد',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadRules(reset: true),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: CanModifyGuard(
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/admin/tajweed-rules/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('حكم جديد'),
        ),
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () => _loadRules(reset: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingM,
                    AppTheme.spacingS,
                    AppTheme.spacingM,
                    80,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search and Filters Section
                      DashboardSection(
                        title: 'البحث والتصفية',
                        subtitle: 'البحث في أحكام التجويد وتصفيتها',
                        child: _buildSearchAndFilters(),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Rules List Section
                      DashboardSection(
                        title: 'أحكام التجويد',
                        subtitle: '${_rules.length} حكم',
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
                                          AppTheme.spacingS,
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
