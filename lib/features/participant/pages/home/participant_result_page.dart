import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/models/round.dart';

import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/round_results_service.dart';
import '../../../../core/services/round_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../models/competition_version.dart';

class ParticipantResultPage extends StatefulWidget {
  final String? versionId;

  const ParticipantResultPage({super.key, this.versionId});

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
  Timer? _searchDebounce;
  // int _totalCount = 0; // Temporairement commenté
  String _selectedAgeGroup = 'كبار';
  CompetitionVersion? _selectedVersion;
  Round? _selectedRound;
  List<CompetitionVersion> _versions = [];
  List<Round> _rounds = [];
  List<RoundResult> _results = [];
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      _versions = await _versionService.fetchVersions();
      if (_versions.isNotEmpty) {
        // Si un versionId est fourni, le pré-sélectionner
        _selectedVersion =
            widget.versionId != null
                ? _versions.firstWhere(
                  (v) => v.id == widget.versionId,
                  orElse: () => _versions.first,
                )
                : _versions.first;
        await _loadRounds();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des versions: $e');
      _hasError = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRounds() async {
    if (_selectedVersion == null) return;

    setState(() => _isLoading = true);
    try {
      final allRounds = await _roundService.getRoundsByVersion(
        _selectedVersion!.id,
      );
      // Seulement les rounds avec des résultats publiés, la plus récente
      // d'abord : c'est généralement celle que l'on vient consulter.
      _rounds =
          allRounds.where((round) => round.resultIsPublished).toList()
            ..sort((a, b) => b.number.compareTo(a.number));

      if (_rounds.isNotEmpty) {
        _selectedRound = _rounds.first;
        await _loadResults();
      } else if (mounted) {
        // Aucun round avec résultats publiés
        setState(() {
          _results = [];
          _selectedRound = null;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des tours: $e');
      _hasError = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadResults({
    bool reset = true,
    bool isFilterChange = false,
    int page = 0,
  }) async {
    if (_selectedVersion == null || _selectedRound == null) return;

    if (reset && !isFilterChange) {
      setState(() => _isLoading = true);
    } else if (isFilterChange) {
      setState(() => _isLoadingFilters = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    // Permet d'ignorer la réponse d'une recherche déjà remplacée par une autre.
    final requestedQuery = _searchQuery;

    try {
      final result = await _resultsService.getResultsWithPagination(
        roundId: _selectedRound!.id,
        ageGroup: _selectedAgeGroup,
        page: reset ? 0 : page,
        limit: 20,
        searchQuery: _searchQuery,
      );

      if (!mounted || requestedQuery != _searchQuery) return;

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
      debugPrint('Erreur lors du chargement des résultats: $e');
      if (mounted) _showErrorSnackBar('خطأ أثناء تحميل النتائج');
    } finally {
      if (mounted && requestedQuery == _searchQuery) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _isLoadingFilters = false;
        });
      }
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
    if (!_hasMore || _isLoadingMore || _isLoadingFilters) return;

    // La page courante n'avance qu'en cas de succès (voir _loadResults) :
    // un échec réseau ne fait plus sauter de page.
    await _loadResults(reset: false, page: _currentPage + 1);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // La recherche est effectuée en base de données : la liste reçue du
  // serveur est déjà filtrée, il n'y a plus de filtrage local à faire.
  List<RoundResult> get _filteredResults => _results;

  void _onSearchChanged(String query) {
    if (query == _searchQuery) return;

    setState(() => _searchQuery = query);

    // On attend une courte pause de saisie avant d'interroger la base.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _currentPage = 0;
      _hasMore = true;
      _loadResults(isFilterChange: true);
    });
  }

  Widget _buildVersionSelector() {
    final version = _selectedVersion;
    return AppGradientHeader(
      shape: AppHeaderShape.card,
      compact: true,
      icon: Icons.leaderboard_rounded,
      title: version?.name ?? 'جاري التحميل...',
      subtitle:
          version != null
              ? 'السنة ${version.year} · ${_rounds.length} جولة منشورة'
              : null,
    );
  }

  void _selectRound(Round round) {
    if (round.id == _selectedRound?.id) return;
    setState(() {
      _selectedRound = round;
      _currentPage = 0;
      _hasMore = true;
    });
    _loadResults(reset: true, isFilterChange: true);
  }

  /// Tour, فئة et recherche regroupés dans une seule carte compacte
  Widget _buildFiltersCard() {
    return AppSection(
      icon: Icons.filter_list_rounded,
      title: 'عرض النتائج',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Un seul tour publié : simple libellé, sinon menu déroulant
          if (_rounds.length == 1)
            AppNotice(
              text: 'الجولة ${_rounds.first.number} - ${_rounds.first.name}',
              icon: Icons.flag_rounded,
              color: AppTheme.primaryColor,
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedRound?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الجولة',
                prefixIcon: Icon(Icons.flag_rounded),
                isDense: true,
              ),
              items: [
                for (final round in _rounds)
                  DropdownMenuItem(
                    value: round.id,
                    child: Text(
                      'الجولة ${round.number} - ${round.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final match = _rounds.where((r) => r.id == id);
                if (match.isNotEmpty) _selectRound(match.first);
              },
            ),
          const SizedBox(height: AppTheme.spacingS),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'كبار',
                label: Text('الكبار'),
                icon: Icon(Icons.person_rounded),
              ),
              ButtonSegment(
                value: 'صغار',
                label: Text('الصغار'),
                icon: Icon(Icons.child_care_rounded),
              ),
            ],
            selected: {_selectedAgeGroup},
            showSelectedIcon: false,
            onSelectionChanged: (value) => _selectAgeGroup(value.first),
          ),
          ModernSearchBar(
            controller: _searchController,
            hintText: 'ابحث بالاسم أو رقم التسجيل...',
            margin: const EdgeInsets.only(top: AppTheme.spacingS),
            onChanged: _onSearchChanged,
            onClear: () => _onSearchChanged(''),
          ),
        ],
      ),
    );
  }

  void _selectAgeGroup(String group) {
    if (group == _selectedAgeGroup) return;
    setState(() {
      _selectedAgeGroup = group;
      _currentPage = 0;
      _hasMore = true;
    });
    _loadResults(reset: true, isFilterChange: true);
  }

  Widget _buildResultsSliver() {
    if (_isLoadingFilters) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingS),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Si aucun round publié, afficher un message approprié
    if (_rounds.isEmpty) {
      return const SliverToBoxAdapter(
        child:
            SizedBox(), // Le message est déjà affiché dans _buildRoundSelector
      );
    }

    final filteredResults = _filteredResults;

    if (filteredResults.isEmpty) {
      return SliverToBoxAdapter(
        child:
            _searchQuery.isNotEmpty
                ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج',
                  subtitle: 'لم يتم العثور على نتائج تطابق البحث',
                )
                : EmptyState(
                  icon: Icons.emoji_events_rounded,
                  title: 'لا توجد نتائج لهذه الجولة',
                  subtitle: 'لم يتم العثور على نتائج للجولة المحددة',
                ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = filteredResults[index];
        return _buildResultCard(
          result,
          // Rang réel calculé côté serveur (reste juste même quand le
          // résultat provient d'une recherche sur toute la base).
          result.rank ?? index + 1,
        );
      }, childCount: filteredResults.length),
    );
  }

  Widget _buildResultCard(RoundResult result, int rank) {
    // Or, argent, bronze pour les trois premiers
    final medalColor = switch (rank) {
      1 => const Color(0xFFD4A84B),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => AppTheme.primaryColor,
    };
    final statusColor =
        result.passed ? AppTheme.successColor : AppTheme.errorColor;

    return AppListCard(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        0,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: medalColor.withValues(alpha: rank <= 3 ? 0.15 : 0.08),
          shape: BoxShape.circle,
        ),
        child: Center(
          child:
              rank <= 3
                  ? Icon(
                    Icons.emoji_events_rounded,
                    color: medalColor,
                    size: 22,
                  )
                  : Text(
                    '$rank',
                    style: AppTheme.bodyLarge.copyWith(
                      color: medalColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ),
      title: result.participant.fullName,
      tags: [
        AppTag(
          text: 'رقم ${result.participant.registrationNumber ?? '؟'}',
          color: AppTheme.textSecondaryColor,
          icon: Icons.badge_rounded,
        ),
        AppTag(
          text: result.passed ? 'ناجح' : 'لم ينجح',
          color: statusColor,
          icon:
              result.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
        ),
      ],
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.score.toStringAsFixed(1),
            style: AppTheme.headingSmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('المعدل', style: AppTheme.labelSmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: 'نتائج المسابقة'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _hasError && _results.isEmpty
              ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'تعذر تحميل النتائج',
                    subtitle: 'تحقق من الاتصال وحاول مجدداً',
                    action: PrimaryButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: _loadVersions,
                    ),
                  ),
                ),
              )
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
                                    color: AppTheme.warningColor.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.emoji_events_rounded,
                                    size: 64,
                                    color: AppTheme.warningColor,
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
                // Recharge aussi les jولات : un nouveau tour a pu être publié
                onRefresh: _loadRounds,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildVersionSelector(),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildFiltersCard(),
                        ]),
                      ),
                    ),
                    _buildResultsSliver(),
                    if (_hasMore)
                      SliverToBoxAdapter(
                        child:
                            _isLoadingMore
                                ? const Padding(
                                  padding: EdgeInsets.all(AppTheme.spacingS),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : Padding(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingS,
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
