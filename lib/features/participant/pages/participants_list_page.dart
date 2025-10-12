import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/participant_service.dart';
import '../../../models/participant.dart';

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
  final _scrollController = ScrollController();
  final _participantService = ParticipantService();
  Timer? _debounceTimer;

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _searchQuery = '';
  String? _selectedAgeGroup;
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    print(
      '📱 ParticipantsListPage initState - versionId: ${widget.versionId}, ageGroup: ${widget.ageGroup}',
    );
    _selectedAgeGroup = widget.ageGroup;
    _loadParticipants();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          _applyFilters();
        });
      }
    });
  }

  void _onScroll() {
    // Détecter si l'utilisateur arrive près de la fin de la liste
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      print('🔄 Déclenchement de la pagination automatique');
      _loadParticipants();
    }
  }

  void _applyFilters() {
    List<Participant> ageGroupFiltered;

    // Si un groupe d'âge est sélectionné, filtrer par groupe d'âge
    if (_selectedAgeGroup != null) {
      ageGroupFiltered =
          _allParticipants.where((participant) {
            return participant.ageGroup == _selectedAgeGroup;
          }).toList();
    } else {
      // Sinon, afficher tous les participants
      ageGroupFiltered = List.from(_allParticipants);
    }

    // Puis appliquer la recherche si nécessaire
    if (_searchQuery.isEmpty) {
      _filteredParticipants = List.from(ageGroupFiltered);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredParticipants =
          ageGroupFiltered.where((participant) {
            final name = participant.fullName.toLowerCase();
            final phone = participant.phone.toLowerCase();
            final registrationNumber =
                participant.registrationNumber.toString().toLowerCase();

            return name.contains(query) ||
                phone.contains(query) ||
                registrationNumber.contains(query);
          }).toList();
    }
  }

  Future<void> _loadParticipants({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 0;
        _allParticipants.clear();
        _filteredParticipants.clear();
        _hasMoreData = true;
      });
    }

    if (_isLoading || !_hasMoreData) return;

    setState(() => _isLoading = true);

    try {
      List<Participant> participants;

      // Si versionId = 'default', récupérer tous les participants
      if (widget.versionId == 'default') {
        participants =
            await _participantService.getAllParticipantsFromAllVersions();
        // Pour 'default', on charge tout d'un coup (pas de pagination)
        _hasMoreData = false;
      } else {
        // Sinon, utiliser la pagination normale
        participants = await _participantService.getParticipantsByVersion(
          widget.versionId,
          page: _currentPage,
          pageSize: _pageSize,
        );
        _hasMoreData = participants.length == _pageSize;
      }

      setState(() {
        if (reset || widget.versionId == 'default') {
          _allParticipants = participants;
        } else {
          _allParticipants.addAll(participants);
        }

        _currentPage++;
        _isLoading = false;

        _applyFilters();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المشاركين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAgeGroupSelector() {
    if (widget.ageGroup != null) {
      // Si un groupe d'âge est spécifié dans l'URL, ne pas afficher le sélecteur
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      child: ModernCard(
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
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'فلترة حسب الفرع',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(child: _buildAgeGroupButton('الكل', Colors.grey)),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(child: _buildAgeGroupButton('كبار', Colors.blue)),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(child: _buildAgeGroupButton('صغار', Colors.purple)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgeGroupButton(String ageGroup, Color color) {
    final bool isSelected = _selectedAgeGroup == ageGroup;
    final bool isAllSelected = ageGroup == 'الكل' && _selectedAgeGroup == null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAgeGroup = ageGroup == 'الكل' ? null : ageGroup;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color:
              (isSelected || isAllSelected)
                  ? color
                  : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color:
                (isSelected || isAllSelected)
                    ? color
                    : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
          boxShadow:
              (isSelected || isAllSelected)
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: Text(
            ageGroup,
            style: AppTheme.bodyMedium.copyWith(
              color: (isSelected || isAllSelected) ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: ModernCard(
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'البحث بالاسم، الهاتف أو رقم التسجيل',
            hintStyle: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(AppTheme.spacingM),
          ),
          style: AppTheme.bodyMedium,
          onChanged: (value) {
            // Le changement est géré par _onSearchChanged
          },
        ),
      ),
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    final isAccepted = participant.isAccepted;
    final statusColor =
        isAccepted == true
            ? Colors.green
            : isAccepted == false
            ? Colors.red
            : Colors.orange;

    final statusText =
        isAccepted == true
            ? 'مقبول'
            : isAccepted == false
            ? 'مرفوض'
            : 'قيد المراجعة';

    final statusIcon =
        isAccepted == true
            ? Icons.check_circle
            : isAccepted == false
            ? Icons.cancel
            : Icons.hourglass_empty;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: InkWell(
        onTap: () {
          print(
            '🔍 Navigation vers détails: /participant/detail/${participant.id}',
          );
          print('🔍 Participant: ${participant.fullName}');
          try {
            context.push(
              '/participant/detail/${participant.id}',
              extra: participant,
            );
            print('✅ Navigation vers détails réussie');
          } catch (e) {
            print('❌ Erreur navigation détails: $e');
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et statut
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      participant.gender == 'ذكر' ? Icons.male : Icons.female,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.fullName,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              participant.ageGroup == 'كبار'
                                  ? 'الكبار'
                                  : 'الصغار',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Statut avec icône
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          statusText,
                          style: AppTheme.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              // Numéro d'enregistrement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'رقم التسجيل: ',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      participant.registrationNumber?.toString() ?? 'غير محدد',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
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

  Widget _buildStatsHeader() {
    // Calculer les statistiques basées sur le groupe d'âge sélectionné
    List<Participant> statsParticipants;
    if (_selectedAgeGroup != null) {
      statsParticipants =
          _allParticipants
              .where((p) => p.ageGroup == _selectedAgeGroup)
              .toList();
    } else {
      statsParticipants = _allParticipants;
    }

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'إحصائيات المشاركين',
                    style: AppTheme.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'إجمالي المشاركين',
                    statsParticipants.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'المقبولون',
                    statsParticipants
                        .where((p) => p.isAccepted == true)
                        .length
                        .toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'المرفوضون',
                    statsParticipants
                        .where((p) => p.isAccepted == false)
                        .length
                        .toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => _loadParticipants(reset: true),
          ),
        ],
      ),
      body:
          _isLoading && _allParticipants.isEmpty
              ? const LoadingOverlay(child: SizedBox())
              : CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header des statistiques
                  SliverToBoxAdapter(child: _buildStatsHeader()),

                  // Sélecteur de groupe d'âge
                  SliverToBoxAdapter(child: _buildAgeGroupSelector()),

                  // Barre de recherche
                  SliverToBoxAdapter(child: _buildSearchBar()),

                  // Liste des participants ou état vide
                  _filteredParticipants.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(
                        child: EmptyState(
                          title:
                              _searchQuery.isNotEmpty
                                  ? 'لا توجد نتائج للبحث'
                                  : _allParticipants.isEmpty
                                  ? 'لا يوجد مشاركون بعد'
                                  : 'لا يوجد مشاركون في فئة ${widget.ageGroup}',
                          subtitle:
                              _searchQuery.isNotEmpty
                                  ? 'جرب البحث بكلمات أخرى'
                                  : _allParticipants.isEmpty
                                  ? 'سيظهر المشاركون هنا عند التسجيل'
                                  : 'جميع المشاركين المسجلين في فئات أخرى',
                          icon: Icons.people_outline,
                        ),
                      )
                      : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final participant = _filteredParticipants[index];
                          return _buildParticipantCard(participant);
                        }, childCount: _filteredParticipants.length),
                      ),

                  // Indicateur de chargement en bas si on charge plus de données
                  if (_isLoading && _filteredParticipants.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  // Espace en bas pour éviter que le contenu soit caché
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTheme.spacingXL),
                  ),
                ],
              ),
      bottomNavigationBar: null, // Pas de navigation bottom pour cette page
    );
  }
}
