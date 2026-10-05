import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';

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
    if (_isLoading || (!reset && _isLoadingMore)) return;

    final page = reset ? 0 : _currentPage + 1;
    setState(() {
      // Le chargement initial / rafraîchissement remplace la liste ; le
      // chargement de la page suivante garde la liste et la position.
      if (reset) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      // Uniquement les فوائد actives
      final result = await _benefitService.getActiveBenefitsWithPagination(
        searchQuery: '',
        page: page,
        limit: 20,
      );
      if (!mounted) return;

      setState(() {
        final benefits = result['benefits'] as List<QuranicBenefit>;
        if (reset) {
          _benefits = benefits;
        } else {
          _benefits.addAll(benefits);
        }
        // La page n'avance qu'en cas de succès
        _currentPage = page;
        _hasMore = result['hasMore'] as bool;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des فوائد: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل الفوائد القرآنية. حاول مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreBenefits() => _loadBenefits(reset: false);

  void _openBenefit(QuranicBenefit benefit) {
    context.push('/participant/benefits/${benefit.id}', extra: benefit);
  }

  /// Publiée depuis moins de 7 jours
  bool _isNew(QuranicBenefit benefit) =>
      DateTime.now().difference(benefit.createdAt).inDays < 7;

  /// Aperçu « citation » : titre, image réduite et début du texte. Le texte
  /// complet est affiché dans la page de détail.
  Widget _buildBenefitCard(QuranicBenefit benefit) {
    final hasImage = benefit.imageUrl != null && benefit.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowM,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openBenefit(benefit),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent doré, couleur du logo
                Container(width: 5, color: AppTheme.goldColor),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasImage)
                        Image.network(
                          benefit.imageUrl!,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  color: AppTheme.goldColor,
                                  size: 28,
                                ),
                                const SizedBox(width: AppTheme.spacingXS),
                                Expanded(
                                  child: Text(
                                    benefit.title,
                                    style: AppTheme.bodyLarge.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryDarkColor,
                                      height: 1.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isNew(benefit))
                                  const AppTag(
                                    text: 'جديد',
                                    color: AppTheme.secondaryColor,
                                    icon: Icons.auto_awesome_rounded,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Text(
                              benefit.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimaryColor.withValues(
                                  alpha: 0.75,
                                ),
                                height: 1.8,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            const Divider(),
                            const SizedBox(height: AppTheme.spacingXS),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(benefit.createdAt),
                                  style: AppTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  'اقرأ الفائدة',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.menu_book_rounded,
      title: 'لا توجد فوائد قرآنية متاحة حالياً',
      subtitle: 'سيتم إضافة فوائد جديدة قريباً',
    );
  }

  Widget _buildHeader() {
    return const AppGradientHeader(
      icon: Icons.menu_book_rounded,
      title: 'الفوائد القرآنية',
      subtitle: 'تأملات وفوائد من كتاب الله تعالى',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'الفوائد القرآنية',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : () => _loadBenefits(reset: true),
          ),
        ],
      ),
      body:
          _isLoading && _benefits.isEmpty
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: () => _loadBenefits(reset: true),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingL),
                  // En-tête + فوائد (ou état vide) + pied de liste
                  itemCount:
                      1 +
                      (_benefits.isEmpty ? 1 : _benefits.length) +
                      (_hasMore && _benefits.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeader();
                    if (_benefits.isEmpty) return _buildEmptyState();

                    final i = index - 1;
                    if (i == _benefits.length) {
                      return Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child:
                            _isLoadingMore
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : OutlinedButton(
                                  onPressed: _loadMoreBenefits,
                                  child: const Text('تحميل المزيد'),
                                ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTheme.spacingM,
                        i == 0 ? AppTheme.spacingM : 0,
                        AppTheme.spacingM,
                        0,
                      ),
                      child: _buildBenefitCard(_benefits[i]),
                    );
                  },
                ),
              ),
    );
  }
}
