import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/participant_service.dart';
import '../../../../core/services/competition_version_service.dart';
import '../../../../models/participant.dart';
import '../../../../models/competition_version.dart';
import 'package:quranic_competition/core/utils/search_utils.dart';

class ParticipantsListPage extends StatefulWidget {
  final String versionId;
  final String? ageGroup;

  const ParticipantsListPage({
    super.key,
    required this.versionId,
    this.ageGroup,
  });

  @override
  State<ParticipantsListPage> createState() => _ParticipantsListPageState();
}

class _ParticipantsListPageState extends State<ParticipantsListPage> {
  final _searchController = TextEditingController();
  final _participantService = ParticipantService();
  final _competitionService = CompetitionVersionService();
  Timer? _debounceTimer;

  /// Tous les participants de la version affichée. La liste est chargée en
  /// entier pour que la recherche, les filtres et les statistiques portent
  /// sur l'ensemble des inscrits, et pas seulement sur une page déjà chargée.
  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _searchQuery = '';
  String? _selectedAgeGroup;
  bool _isLoading = true;
  String? _errorMessage;

  CompetitionVersion? _displayedVersion;
  bool _isActiveVersion = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeGroup = widget.ageGroup;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _applyFilters();
      });
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  /// Détermine la version à afficher : celle demandée, sinon (versionId
  /// 'default') la version active, sinon la dernière version.
  Future<void> _resolveVersion() async {
    if (widget.versionId != 'default') {
      _displayedVersion = await _competitionService.getVersionById(
        widget.versionId,
      );
      _isActiveVersion = _displayedVersion?.isActive ?? false;
      return;
    }

    final activeVersions =
        await _competitionService.fetchActiveVersionsWithOpenRegistration();
    if (activeVersions.isNotEmpty) {
      _displayedVersion = activeVersions.first;
      _isActiveVersion = true;
      return;
    }

    final allVersions = await _competitionService.fetchVersions();
    _displayedVersion = allVersions.isNotEmpty ? allVersions.first : null;
    _isActiveVersion = false;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _resolveVersion();

      // Chaque version possède sa propre liste : on ne mélange jamais les
      // versions. Sans version, la liste est vide.
      final versionId =
          widget.versionId != 'default'
              ? widget.versionId
              : _displayedVersion?.id;
      final participants =
          versionId == null
              ? <Participant>[]
              : await _participantService.getAllParticipantsByVersion(
                versionId,
              );

      // Ordre des numéros d'inscription, les participants sans numéro à la fin
      participants.sort((a, b) {
        final ra = a.registrationNumber;
        final rb = b.registrationNumber;
        if (ra == null && rb == null) return 0;
        if (ra == null) return 1;
        if (rb == null) return -1;
        return ra.compareTo(rb);
      });

      if (!mounted) return;
      setState(() {
        _allParticipants = participants;
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des participants: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'تعذر تحميل قائمة المشاركين. تحقق من الاتصال وحاول مجدداً.';
      });
    }
  }

  List<Participant> get _ageGroupParticipants {
    if (_selectedAgeGroup == null) return _allParticipants;
    return _allParticipants
        .where((p) => p.ageGroup == _selectedAgeGroup)
        .toList();
  }

  void _applyFilters() {
    final base = _ageGroupParticipants;
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredParticipants = List.of(base);
      return;
    }

    // Recherche par numéro : numéro d'inscription exact uniquement
    final digits = SearchUtils.numericQuery(query);
    _filteredParticipants =
        base.where((participant) {
          if (digits != null) {
            return SearchUtils.numberMatches(
              participant.registrationNumber,
              digits,
            );
          }
          return participant.fullName.toLowerCase().contains(query);
        }).toList();
  }

  void _selectAgeGroup(String? ageGroup) {
    setState(() {
      _selectedAgeGroup = ageGroup;
      _applyFilters();
    });
  }

  int _countByAgeGroup(String? ageGroup) {
    if (ageGroup == null) return _allParticipants.length;
    return _allParticipants.where((p) => p.ageGroup == ageGroup).length;
  }

  // ---------------------------------------------------------------------------
  // En-tête : version affichée + statistiques
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final stats = _ageGroupParticipants;
    final accepted = stats.where((p) => p.isAccepted).length;
    final rejected = stats.length - accepted;
    final versionColor = _isActiveVersion ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingS),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_displayedVersion != null) ...[
                Row(
                  children: [
                    Icon(
                      _isActiveVersion ? Icons.emoji_events_rounded : Icons.history_rounded,
                      color: versionColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        _displayedVersion!.name,
                        style: AppTheme.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: versionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Text(
                        _isActiveVersion ? 'نسخة نشطة' : 'آخر نسخة',
                        style: AppTheme.bodySmall.copyWith(
                          color: versionColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
              ],
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'إجمالي المشاركين',
                      stats.length,
                      Icons.people_rounded,
                      AppTheme.infoColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildStatItem(
                      'المقبولون',
                      accepted,
                      Icons.check_circle_rounded,
                      AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildStatItem(
                      'المرفوضون',
                      rejected,
                      Icons.cancel_rounded,
                      AppTheme.errorColor,
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

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingS,
        horizontal: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            '$value',
            style: AppTheme.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filtres et recherche
  // ---------------------------------------------------------------------------

  Widget _buildAgeGroupSelector() {
    // Un groupe d'âge imposé par l'URL : pas de sélecteur
    if (widget.ageGroup != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(child: _buildAgeGroupChip(null, 'الكل', AppTheme.textSecondaryColor)),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(child: _buildAgeGroupChip('كبار', 'الكبار', AppTheme.infoColor)),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(child: _buildAgeGroupChip('صغار', 'الصغار', AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildAgeGroupChip(String? ageGroup, String label, Color color) {
    final isSelected = _selectedAgeGroup == ageGroup;

    return Material(
      color: isSelected ? color : color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: () => _selectAgeGroup(ageGroup),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
          child: Center(
            child: Text(
              '$label (${_countByAgeGroup(ageGroup)})',
              style: AppTheme.bodyMedium.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ModernSearchBar(
      controller: _searchController,
      hintText: 'البحث بالاسم أو رقم التسجيل',
      onChanged: _onSearchChanged,
      onClear: _clearSearch,
      margin: const EdgeInsets.all(AppTheme.spacingS),
    );
  }

  Widget _buildResultsCount() {
    if (_searchQuery.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Text(
        'عدد النتائج: ${_filteredParticipants.length}',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carte participant
  // ---------------------------------------------------------------------------

  Widget _buildParticipantCard(Participant participant) {
    final isAccepted = participant.isAccepted;
    final statusColor = isAccepted ? AppTheme.successColor : AppTheme.errorColor;
    final isAdult = participant.ageGroup == 'كبار';
    final groupColor = isAdult ? AppTheme.infoColor : AppTheme.primaryColor;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap:
            () => context.push(
              '/participant/detail/${participant.id}',
              extra: participant,
            ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Row(
            children: [
              // Numéro d'inscription, mis en avant
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'رقم',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                      ),
                    ),
                    FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          participant.registrationNumber?.toString() ?? '-',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.fullName,
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Wrap(
                      spacing: AppTheme.spacingXS,
                      runSpacing: AppTheme.spacingXS,
                      children: [
                        _buildTag(
                          isAdult ? 'الكبار' : 'الصغار',
                          Icons.people_rounded,
                          groupColor,
                        ),
                        _buildTag(
                          isAccepted ? 'مقبول' : 'مرفوض',
                          isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: AppTheme.textDisabledColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // États vides / erreur
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final String title;
    final String subtitle;
    if (_searchQuery.trim().isNotEmpty) {
      title = 'لا توجد نتائج للبحث';
      subtitle = 'تحقق من الاسم أو من رقم التسجيل';
    } else if (_allParticipants.isEmpty) {
      title = 'لا يوجد مشاركون بعد';
      subtitle = 'سيظهر المشاركون هنا عند التسجيل';
    } else {
      title = 'لا يوجد مشاركون في هذا الفرع';
      subtitle = 'جميع المشاركين المسجلين في فروع أخرى';
    }

    return EmptyState(
      title: title,
      subtitle: subtitle,
      icon:
          _searchQuery.trim().isNotEmpty
              ? Icons.search_off_rounded
              : Icons.people_outline_rounded,
    );
  }

  Widget _buildErrorState() {
    return EmptyState(
      title: 'حدث خطأ',
      subtitle: _errorMessage,
      icon: Icons.wifi_off_rounded,
      iconColor: AppTheme.errorColor,
      action: PrimaryButton(
        text: 'إعادة المحاولة',
        icon: Icons.refresh_rounded,
        onPressed: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'قائمة المشاركين',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allParticipants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _allParticipants.isEmpty) {
      return Center(child: SingleChildScrollView(child: _buildErrorState()));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildAgeGroupSelector()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildResultsCount()),

          if (_filteredParticipants.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildParticipantCard(_filteredParticipants[index]),
                childCount: _filteredParticipants.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingXL)),
        ],
      ),
    );
  }
}
