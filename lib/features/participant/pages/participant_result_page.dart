import 'package:flutter/material.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/models/round.dart';
import '../../../core/services/round_results_service.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../core/services/round_service.dart';
import '../../../models/competition_version.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

class ParticipantResultPage extends StatefulWidget {
  const ParticipantResultPage({super.key});

  @override
  State<ParticipantResultPage> createState() => _ParticipantResultPageState();
}

class _ParticipantResultPageState extends State<ParticipantResultPage> {
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
  // int _totalCount = 0; // Temporairement commenté
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
        _selectedVersion = _versions.first;
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
      _rounds = await _roundService.getRoundsByVersion(_selectedVersion!.id);
      if (_rounds.isNotEmpty) {
        _selectedRound = _rounds.first;
        await _loadResults();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<RoundResult> get _filteredResults {
    if (_searchQuery.isEmpty) {
      return _results;
    }
    return _results.where((result) {
      final fullName = result.participant.fullName.toLowerCase();
      final registrationNumber =
          result.participant.registrationNumber?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return fullName.contains(query) || registrationNumber.contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Widget _buildVersionSelector() {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.event,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'اختر النسخة',
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: DropdownButton<CompetitionVersion>(
                value: _selectedVersion,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                items:
                    _versions.map((version) {
                      return DropdownMenuItem(
                        value: version,
                        child: Text(version.name, style: AppTheme.labelMedium),
                      );
                    }).toList(),
                onChanged: (version) {
                  if (version != null && version.id != _selectedVersion?.id) {
                    setState(() {
                      _selectedVersion = version;
                      _currentPage = 0;
                      _hasMore = true;
                    });
                    _loadRounds();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundSelector() {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'اختر الجولة',
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: DropdownButton<Round>(
                value: _selectedRound,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                items:
                    _rounds.map((round) {
                      return DropdownMenuItem(
                        value: round,
                        child: Text(
                          'الجولة ${round.number} - ${round.name}',
                          style: AppTheme.labelMedium,
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
                    // Chargement sans rechargement de page
                    _loadResults(reset: true, isFilterChange: true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeGroupSelector() {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'اختر الفئة',
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'البحث عن المشارك',
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم التسجيل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
          ],
        ),
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
          // Chargement sans rechargement de page
          _loadResults(reset: true, isFilterChange: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 16),
            if (isSelected) const SizedBox(width: AppTheme.spacingS),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color:
                    isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    if (_isLoadingFilters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'لا توجد نتائج',
        subtitle:
            _selectedRound != null
                ? 'لا توجد نتائج متاحة للجولة ${_selectedRound!.name}'
                : 'لا توجد نتائج متاحة',
      );
    }

    // En-tête avec les informations de sélection
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'نتائج ${_selectedVersion?.name ?? ""}',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Text(
                    '${_results.length}',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'الجولة: ${_selectedRound?.name ?? ""} - الفئة: $_selectedAgeGroup',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSliver() {
    if (_isLoadingFilters) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final filteredResults = _filteredResults;

    if (filteredResults.isEmpty) {
      return SliverToBoxAdapter(
        child:
            _searchQuery.isNotEmpty
                ? EmptyState(
                  icon: Icons.search_off,
                  title: 'لا توجد نتائج',
                  subtitle: 'لم يتم العثور على نتائج تطابق البحث',
                )
                : const SizedBox(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = filteredResults[index];
        return _buildResultCard(result, index + 1);
      }, childCount: filteredResults.length),
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
      margin: const EdgeInsets.only(bottom: 4),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Position et médaille
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      rank <= 3
                          ? medalColor.withValues(alpha: 0.1)
                          : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: rank <= 3 ? medalColor : AppTheme.dividerColor,
                  ),
                ),
                child: Center(
                  child:
                      medalIcon != null
                          ? Icon(medalIcon, color: medalColor, size: 16)
                          : Text(
                            '$rank',
                            style: AppTheme.labelMedium.copyWith(
                              color: medalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),

              // Informations du participant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.participant.fullName,
                      style: AppTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'رقم التسجيل: ${result.participant.registrationNumber ?? 'غير محدد'}',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          result.passed ? Icons.check_circle : Icons.cancel,
                          color:
                              result.passed
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          result.passed ? 'نجح' : 'لم ينجح',
                          style: AppTheme.labelSmall.copyWith(
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

              // Score et rang
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          result.passed
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      result.score.toStringAsFixed(1),
                      style: AppTheme.labelSmall.copyWith(
                        color:
                            result.passed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'المركز $rank',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: 'نتائج المسابقة'),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
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
                          const SizedBox(height: AppTheme.spacingS),
                          _buildAgeGroupSelector(),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildSearchBar(),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildResultsHeader(),
                          const SizedBox(height: AppTheme.spacingS),
                        ]),
                      ),
                    ),
                    _buildResultsSliver(),
                    if (_hasMore)
                      SliverToBoxAdapter(
                        child:
                            _isLoadingMore
                                ? const Padding(
                                  padding: EdgeInsets.all(AppTheme.spacingM),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : Padding(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingM,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: SecondaryButton(
                                      onPressed: _loadMoreResults,
                                      text: 'تحميل المزيد',
                                    ),
                                  ),
                                ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 20,
                      ), // Espace en bas pour le scroll
                    ),
                  ],
                ),
              ),
    );
  }
}
