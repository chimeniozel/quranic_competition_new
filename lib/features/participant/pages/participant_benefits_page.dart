import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

class ParticipantBenefitsPage extends StatefulWidget {
  const ParticipantBenefitsPage({super.key});

  @override
  State<ParticipantBenefitsPage> createState() =>
      _ParticipantBenefitsPageState();
}

class _ParticipantBenefitsPageState extends State<ParticipantBenefitsPage> {
  final QuranicBenefitService _benefitService = QuranicBenefitService();
  final ScrollController _scrollController = ScrollController();

  List<QuranicBenefit> _benefits = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBenefits(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
      }
    });

    try {
      // Utiliser la méthode spécifique pour les participants (seulement les bénéfices actives)
      final result = await _benefitService.getActiveBenefitsWithPagination(
        searchQuery: '',
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _benefits = result['benefits'] as List<QuranicBenefit>;
        } else {
          _benefits.addAll(result['benefits'] as List<QuranicBenefit>);
        }
        // _totalCount = result['totalCount'] as int;
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

  Widget _buildBenefitCard(QuranicBenefit benefit) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      benefit.title,
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Text(
                      'فائدة قرآنية',
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (benefit.imageUrl != null && benefit.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Image.network(
                    benefit.imageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: AppTheme.backgroundColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
              ],
              Text(
                benefit.content,
                style: AppTheme.labelMedium.copyWith(
                  height: 1.6,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'نشر بواسطة: الإدارة',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(benefit.createdAt),
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.menu_book_outlined,
      title: 'لا توجد فوائد قرآنية متاحة حالياً',
      subtitle: 'سيتم إضافة فوائد جديدة قريباً',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'الفوائد القرآنية',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBenefits(reset: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : _benefits.isEmpty && !_isLoading
              ? _buildEmptyState()
              : ModernPullToRefresh(
                onRefresh: () => _loadBenefits(reset: true),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _benefits.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _benefits.length) {
                      return _isLoadingMore
                          ? const Padding(
                            padding: EdgeInsets.all(AppTheme.spacingM),
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : _hasMore
                          ? Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            child: SizedBox(
                              width: double.infinity,
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
    );
  }
}
