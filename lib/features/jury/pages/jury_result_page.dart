import 'package:flutter/material.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/models/round.dart';

import '../../../core/services/competition_version_service.dart';
import '../../../core/services/round_results_service.dart';
import '../../../core/services/round_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../models/competition_version.dart';

class JuryResultPage extends StatefulWidget {
  final String? versionId;

  const JuryResultPage({super.key, this.versionId});

  @override
  State<JuryResultPage> createState() => _JuryResultPageState();
}

class _JuryResultPageState extends State<JuryResultPage> {
  final RoundResultsService _resultsService = RoundResultsService();
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final RoundService _roundService = RoundService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingFilters = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedAgeGroup = 'كبار';
  CompetitionVersion? _selectedVersion;
  Round? _selectedRound;
  List<CompetitionVersion> _versions = [];
  List<Round> _rounds = [];
  List<RoundResult> _results = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      _versions = await _versionService.fetchVersions();
      if (_versions.isNotEmpty) {
        // Si un versionId est fourni, le pré-sélectionner
        if (widget.versionId != null) {
          _selectedVersion = _versions.firstWhere(
            (v) => v.id == widget.versionId,
            orElse: () => _versions.first,
          );
          print('🔍 Version pré-sélectionnée: ${_selectedVersion?.name}');
        } else {
          _selectedVersion = _versions.first;
        }
        await _loadRounds();
      }
    } catch (e) {
      print('Erreur lors du chargement des versions: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النسخ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRounds() async {
    if (_selectedVersion == null) return;

    setState(() => _isLoading = true);
    try {
      final allRounds = await _roundService.getRoundsByVersion(
        _selectedVersion!.id,
      );
      // Filtrer seulement les rounds avec des résultats publiés
      _rounds = allRounds.where((round) => round.resultIsPublished).toList();

      if (_rounds.isNotEmpty) {
        _selectedRound = _rounds.first;
        await _loadResults();
      } else {
        setState(() {
          _results = [];
          _selectedRound = null;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des tours: $e');
      _showErrorSnackBar('خطأ أثناء تحميل الجولات');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadResults({
    bool reset = true,
    bool isFilterChange = false,
  }) async {
    if (_selectedVersion == null || _selectedRound == null) return;

    if (reset && !isFilterChange) {
      setState(() => _isLoading = true);
    } else if (isFilterChange) {
      setState(() => _isLoadingFilters = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _resultsService.getResultsWithPagination(
        roundId: _selectedRound!.id,
        ageGroup: _selectedAgeGroup,
        page: reset ? 0 : _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _results = result['results'] as List<RoundResult>;
          _currentPage = 0;
        } else {
          _results.addAll(result['results'] as List<RoundResult>);
        }
        _hasMore = result['hasMore'] as bool;
        _currentPage = result['currentPage'] as int;
      });
    } catch (e) {
      print('Erreur lors du chargement des résultats: $e');
      _showErrorSnackBar('خطأ أثناء تحميل النتائج');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _isLoadingFilters = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _currentPage++);
    await _loadResults(reset: false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  List<RoundResult> get _filteredResults {
    if (_searchQuery.isEmpty) {
      return _results;
    }
    return _results.where((result) {
      final registrationNumber =
          result.participant.registrationNumber?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return registrationNumber.contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'نتائج النسخة'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _rounds.isEmpty
              ? ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      children: [
                        _buildVersionSelector(),
                        const SizedBox(height: AppTheme.spacingXL),
                        ModernCard(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacingXL),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingL,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.emoji_events_outlined,
                                    size: 64,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingL),
                                Text(
                                  'لا توجد نتائج متاحة',
                                  style: AppTheme.headingMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'لم يتم نشر نتائج أي جولة بعد في هذه النسخة',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingXS),
                                Text(
                                  'يرجى الانتظار حتى يتم نشر النتائج',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : ModernPullToRefresh(
                onRefresh: () => _loadResults(reset: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildVersionSelector(),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildRoundSelector(),
                          _buildAgeGroupSelector(),
                          _buildSearchBar(),
                        ]),
                      ),
                    ),
                    _buildResultsSliver(),
                    if (_hasMore && _rounds.isNotEmpty)
                      SliverToBoxAdapter(
                        child:
                            _isLoadingMore
                                ? const Padding(
                                  padding: EdgeInsets.all(AppTheme.spacingS),
                                  child: Center(
                                    child: const CircularProgressIndicator(),
                                  ),
                                )
                                : const SizedBox(height: AppTheme.spacingL),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildVersionSelector() {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              Colors.transparent,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedVersion?.name ?? 'جاري التحميل...',
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'السنة: ${_selectedVersion?.year ?? '...'}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
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

  Widget _buildRoundSelector() {
    return ModernCard(
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: AppTheme.successColor, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child:
                _rounds.isEmpty
                    ? Text(
                      'لا توجد نتائج متاحة',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    )
                    : DropdownButtonHideUnderline(
                      child: DropdownButton<Round>(
                        value: _selectedRound,
                        isExpanded: true,
                        hint: Text('اختر الجولة', style: AppTheme.bodyMedium),
                        items:
                            _rounds.map((round) {
                              return DropdownMenuItem(
                                value: round,
                                child: Text(
                                  'الجولة ${round.number} - ${round.name}',
                                  style: AppTheme.bodyMedium,
                                ),
                              );
                            }).toList(),
                        onChanged: (round) {
                          if (round != null && round.id != _selectedRound?.id) {
                            setState(() {
                              _selectedRound = round;
                              _currentPage = 0;
                              _hasMore = true;
                            });
                            _loadResults(reset: true, isFilterChange: true);
                          }
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupSelector() {
    return ModernCard(
      child: Row(
        children: [
          Icon(Icons.groups, color: AppTheme.warningColor, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildAgeGroupButton(
                    'كبار',
                    _selectedAgeGroup == 'كبار',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: _buildAgeGroupButton(
                    'صغار',
                    _selectedAgeGroup == 'صغار',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (label != _selectedAgeGroup) {
          setState(() {
            _selectedAgeGroup = label;
            _currentPage = 0;
            _hasMore = true;
          });
          _loadResults(reset: true, isFilterChange: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingS,
          horizontal: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ModernCard(
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'البحث برقم التسجيل...',
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textDisabledColor,
          ),
          prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
          border: InputBorder.none,
          filled: false,
        ),
        style: AppTheme.bodyMedium,
      ),
    );
  }

  Widget _buildResultsSliver() {
    if (_isLoadingFilters) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_rounds.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    final filteredResults = _filteredResults;

    if (filteredResults.isEmpty) {
      return SliverToBoxAdapter(
        child:
            _searchQuery.isNotEmpty
                ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'لا توجد نتائج',
                  subtitle: 'لم يتم العثور على نتائج تطابق البحث',
                )
                : const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'لا توجد نتائج لهذه الجولة',
                  subtitle: 'لم يتم العثور على نتائج للجولة المحددة',
                ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final result = filteredResults[index];
          return _buildResultCard(result, index + 1);
        }, childCount: filteredResults.length),
      ),
    );
  }

  Widget _buildResultCard(RoundResult result, int rank) {
    Color medalColor;
    IconData? medalIcon;

    if (rank == 1) {
      medalColor = AppTheme.warningColor;
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      medalColor = AppTheme.textSecondaryColor;
      medalIcon = Icons.emoji_events;
    } else if (rank == 3) {
      medalColor = Colors.brown;
      medalIcon = Icons.emoji_events;
    } else {
      medalColor = AppTheme.primaryColor;
      medalIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Row(
            children: [
              // Position et médaille
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      rank <= 3
                          ? medalColor.withOpacity(0.1)
                          : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: rank <= 3 ? medalColor : AppTheme.dividerColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      medalIcon != null
                          ? Icon(medalIcon, color: medalColor, size: 20)
                          : Text(
                            '$rank',
                            style: AppTheme.labelLarge.copyWith(
                              color: medalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),

              // Informations du participant (sans nom)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المشارك رقم ${result.participant.registrationNumber ?? '؟'}',
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        Icon(
                          result.passed ? Icons.check_circle : Icons.cancel,
                          color:
                              result.passed
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                          size: 14,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          result.passed ? 'نجح' : 'لم ينجح',
                          style: AppTheme.bodySmall.copyWith(
                            color:
                                result.passed
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color:
                      result.passed
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(
                    color:
                        result.passed
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      result.score.toStringAsFixed(1),
                      style: AppTheme.headingSmall.copyWith(
                        color:
                            result.passed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'المعدل',
                      style: AppTheme.bodySmall.copyWith(
                        color:
                            result.passed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
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
}
