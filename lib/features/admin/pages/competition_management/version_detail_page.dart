import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import '../../../../models/competition_version.dart';
import '../../../../models/participant.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

class VersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionDetailPage({super.key, required this.version});

  @override
  State<VersionDetailPage> createState() => _VersionDetailPageState();
}

class _VersionDetailPageState extends State<VersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedGroup = 'كبار';
  bool _isLoading = false;
  int _totalCount = 0;
  String _searchQuery = '';
  AppUser? appUser;
  bool _dataLoaded = false;

  // Pagination settings
  static const int _itemsPerPage = 10;
  int _totalPages = 0;
  int _currentPageIndex = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadParticipants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants({
    bool reset = true,
    bool forceReload = false,
  }) async {
    // Si les données sont déjà chargées et qu'on ne force pas le rechargement,
    // on applique seulement le filtrage
    if (_dataLoaded && !forceReload) {
      _applyFilter(reset: reset);
      return;
    }

    if (reset) {
      setState(() => _isLoading = true);
    }

    try {
      AuthService authService = AuthService();
      AppUser? user = await authService.getUserProfile();

      // Charger tous les participants (seulement si pas encore chargés ou rechargement forcé)
      if (reset || forceReload) {
        final participants = await _participantService
            .fetchParticipantsByVersion(widget.version.id);
        setState(() {
          appUser = user;
          _allParticipants = participants;
          _dataLoaded = true;
        });
      }

      // Appliquer les filtres et la pagination
      _applyFilter(reset: reset);
    } catch (e) {
      print("Erreur lors du chargement des participants: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter({bool reset = true}) {
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedGroup).toList();

    // Appliquer la recherche
    if (_searchQuery.isNotEmpty) {
      int? searchTerm = int.tryParse(_searchQuery.trim());
      if (searchTerm != null) {
        filtered =
            filtered.where((p) => p.registrationNumber == searchTerm).toList();
      }
    }

    // Calculer la pagination
    final totalCount = filtered.length;
    _totalPages = (totalCount / _itemsPerPage).ceil();

    if (reset) {
      _currentPageIndex = 1;
    }

    // S'assurer que la page actuelle ne dépasse pas le nombre total de pages
    if (_currentPageIndex > _totalPages && _totalPages > 0) {
      _currentPageIndex = _totalPages;
    }

    // Appliquer la pagination
    final startIndex = (_currentPageIndex - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalCount);

    final paginatedParticipants =
        totalCount > 0
            ? filtered.sublist(startIndex, endIndex)
            : <Participant>[];

    setState(() {
      _filteredParticipants = paginatedParticipants;
      _totalCount = totalCount;
    });
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text;
    // Appliquer seulement le filtrage côté client, pas de rechargement serveur
    _applyFilter(reset: true);
  }

  void _selectGroup(String group) {
    if (group != _selectedGroup) {
      setState(() {
        _selectedGroup = group;
      });
      // Appliquer seulement le filtrage côté client, pas de rechargement serveur
      _applyFilter(reset: true);
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPageIndex = page;
      });
      _applyFilter(reset: false);

      // Scroll vers le haut de la liste
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _totalPages) {
      _goToPage(_currentPageIndex + 1);
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 1) {
      _goToPage(_currentPageIndex - 1);
    }
  }

  void _navigateToParticipantDetail(Participant participant) {
    context.pushNamed(
      'participant-detail',
      pathParameters: {'participantId': participant.id},
      extra: {'participant': participant, 'version': widget.version},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: widget.version.name,
        actions: [
          IconButton(
            onPressed: () {
              context.pushNamed('jury-version-jurys', extra: widget.version);
            },
            icon: Icon(Icons.groups, color: AppTheme.surfaceColor),
            tooltip: 'لجنة التحكيم',
          ),
        ],
      ),
      floatingActionButton: ModernFAB(
        icon: Icons.analytics,
        onPressed: () async {
          context.push('/admin/version_results', extra: widget.version);
        },
        tooltip: 'النتائج',
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh:
                    () => _loadParticipants(reset: true, forceReload: true),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Header avec statistiques
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.version.name,
                              style: AppTheme.headingSmall.copyWith(
                                color: AppTheme.surfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سنة ${widget.version.year}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.surfaceColor.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                            if (_totalCount > 0) ...[
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Text(
                                  '${_totalCount} مشارك',
                                  style: AppTheme.labelLarge.copyWith(
                                    color: AppTheme.surfaceColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Statut d'inscription
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      widget.version.isRegistrationOpen
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Icon(
                                  widget.version.isRegistrationOpen
                                      ? Icons.lock_open
                                      : Icons.lock,
                                  color:
                                      widget.version.isRegistrationOpen
                                          ? AppTheme.successColor
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
                                      'حالة التسجيل',
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.version.isRegistrationOpen
                                          ? 'مفتوح'
                                          : 'مغلق',
                                      style: AppTheme.labelLarge.copyWith(
                                        color:
                                            widget.version.isRegistrationOpen
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section de filtrage moderne
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'تصفية المشاركين',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingM),

                              // Boutons de catégorie modernisés
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _selectGroup('كبار'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppTheme.spacingM,
                                            horizontal: AppTheme.spacingL,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _selectedGroup == 'كبار'
                                                    ? AppTheme.primaryColor
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                          ),
                                          child: Text(
                                            'كبار',
                                            textAlign: TextAlign.center,
                                            style: AppTheme.labelLarge.copyWith(
                                              color:
                                                  _selectedGroup == 'كبار'
                                                      ? AppTheme.surfaceColor
                                                      : AppTheme
                                                          .textPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _selectGroup('صغار'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppTheme.spacingM,
                                            horizontal: AppTheme.spacingL,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _selectedGroup == 'صغار'
                                                    ? AppTheme.secondaryColor
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                          ),
                                          child: Text(
                                            'صغار',
                                            textAlign: TextAlign.center,
                                            style: AppTheme.labelLarge.copyWith(
                                              color:
                                                  _selectedGroup == 'صغار'
                                                      ? AppTheme.surfaceColor
                                                      : AppTheme
                                                          .textPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingM),

                              // Champ de recherche modernisé
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  keyboardType: TextInputType.number,
                                  style: AppTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    hintText: 'ابحث برقم التسجيل...',
                                    hintStyle: AppTheme.labelMedium.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: AppTheme.primaryColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingM,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Header des participants
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المشاركون',
                                      style: AppTheme.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _totalCount > 0
                                          ? 'عرض ${_filteredParticipants.length} من $_totalCount مشارك في فئة ${_selectedGroup}'
                                          : 'لا يوجد مشاركون في فئة ${_selectedGroup}',
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_filteredParticipants.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  child: Text(
                                    '${_filteredParticipants.length}',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Liste des participants modernisée
                      if (_filteredParticipants.isEmpty && !_isLoading)
                        EmptyState(
                          icon: Icons.people_outline,
                          title: 'لا يوجد مشاركون',
                          subtitle:
                              'لا يوجد مشاركون في فئة ${_selectedGroup} حالياً',
                        )
                      else
                        Column(
                          children: [
                            // Liste des participants
                            ...List.generate(_filteredParticipants.length, (
                              index,
                            ) {
                              final participant = _filteredParticipants[index];
                              return GestureDetector(
                                onTap:
                                    () => _navigateToParticipantDetail(
                                      participant,
                                    ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ModernCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar avec numéro
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color:
                                                  participant.ageGroup == 'كبار'
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.secondaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                participant.registrationNumber
                                                    .toString(),
                                                style: AppTheme.labelSmall
                                                    .copyWith(
                                                      color:
                                                          AppTheme.surfaceColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),

                                          // Informations du participant
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  participant.fullName,
                                                  style: AppTheme.labelLarge
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            participant.ageGroup ==
                                                                    'كبار'
                                                                ? AppTheme
                                                                    .primaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    )
                                                                : AppTheme
                                                                    .secondaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppTheme.radiusS,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        participant.ageGroup,
                                                        style: AppTheme.labelSmall.copyWith(
                                                          color:
                                                              participant.ageGroup ==
                                                                      'كبار'
                                                                  ? AppTheme
                                                                      .primaryColor
                                                                  : AppTheme
                                                                      .secondaryColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: AppTheme.spacingS,
                                                    ),
                                                    Text(
                                                      'رقم ${participant.registrationNumber}',
                                                      style: AppTheme.labelSmall
                                                          .copyWith(
                                                            color:
                                                                AppTheme
                                                                    .textSecondaryColor,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Icône d'action
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color: AppTheme.textSecondaryColor,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // Widget de pagination moderne
                            if (_totalPages > 1) _buildPaginationWidget(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildPaginationWidget() {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          // Informations de pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الصفحة $_currentPageIndex من $_totalPages',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                'إجمالي $_totalCount مشارك',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Contrôles de pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton page précédente
              IconButton(
                onPressed: _currentPageIndex > 1 ? _goToPreviousPage : null,
                icon: Icon(
                  Icons.chevron_right,
                  color:
                      _currentPageIndex > 1
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _currentPageIndex > 1
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingS),

              // Numéros de pages
              Row(children: _buildPageNumbers()),

              const SizedBox(width: AppTheme.spacingS),

              // Bouton page suivante
              IconButton(
                onPressed:
                    _currentPageIndex < _totalPages ? _goToNextPage : null,
                icon: Icon(
                  Icons.chevron_left,
                  color:
                      _currentPageIndex < _totalPages
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _currentPageIndex < _totalPages
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];

    // Calculer la plage de pages à afficher
    int startPage = (_currentPageIndex - 2).clamp(1, _totalPages);
    int endPage = (_currentPageIndex + 2).clamp(1, _totalPages);

    // Ajuster la plage si on est près du début ou de la fin
    if (endPage - startPage < 4) {
      if (startPage == 1) {
        endPage = (startPage + 4).clamp(1, _totalPages);
      } else {
        startPage = (endPage - 4).clamp(1, _totalPages);
      }
    }

    // Ajouter "..." au début si nécessaire
    if (startPage > 1) {
      pageNumbers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '...',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    // Ajouter les numéros de pages
    for (int i = startPage; i <= endPage; i++) {
      final isCurrentPage = i == _currentPageIndex;
      pageNumbers.add(
        GestureDetector(
          onTap: () => _goToPage(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCurrentPage ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border:
                  isCurrentPage
                      ? null
                      : Border.all(color: AppTheme.dividerColor),
            ),
            child: Text(
              '$i',
              style: AppTheme.labelMedium.copyWith(
                color:
                    isCurrentPage
                        ? AppTheme.surfaceColor
                        : AppTheme.textPrimaryColor,
                fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    // Ajouter "..." à la fin si nécessaire
    if (endPage < _totalPages) {
      pageNumbers.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '...',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    return pageNumbers;
  }
}
