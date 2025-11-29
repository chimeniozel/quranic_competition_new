import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class ParticipantArchivesPage extends StatefulWidget {
  const ParticipantArchivesPage({super.key});

  @override
  State<ParticipantArchivesPage> createState() =>
      _ParticipantArchivesPageState();
}

class _ParticipantArchivesPageState extends State<ParticipantArchivesPage> {
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();

  List<CompetitionVersion> _versions = [];
  List<ArchiveMedia> _allMedia = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final versions = await _versionService.fetchVersions();
      final allMedia = await _mediaService.getAllMediaSafe();

      setState(() {
        _versions = versions;
        _allMedia = allMedia;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  List<CompetitionVersion> get _filteredVersions {
    if (_searchQuery.isEmpty) {
      return _versions;
    }

    return _versions.where((version) {
      return version.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ArchiveMedia> _getMediaForVersion(String versionId) {
    return _allMedia.where((media) {
      return media.versionId == versionId &&
          media.isActive; // Seulement les médias actifs
    }).toList();
  }

  int _getActiveMediaCount(String versionId) {
    return _getMediaForVersion(
      versionId,
    ).length; // Tous les médias retournés sont déjà actifs
  }

  int _getTotalMediaCount(String versionId) {
    return _getMediaForVersion(versionId).length;
  }

  Widget _buildCompetitionCard(CompetitionVersion version) {
    final mediaForVersion = _getMediaForVersion(version.id);
    final activeMediaCount = _getActiveMediaCount(version.id);
    final totalMediaCount = _getTotalMediaCount(version.id);
    final videoCount =
        mediaForVersion
            .where((m) => m.type.toString().contains('video'))
            .length;
    final imageCount =
        mediaForVersion
            .where((m) => m.type.toString().contains('image'))
            .length;

    return GestureDetector(
      onTap:
          () => context.push('/participant/archives/competition/${version.id}'),
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec titre de la compétition
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Icon(
                      Icons.archive,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          version.name,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'مسابقة أهل القرآن الواتسابية',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Statistiques des médias
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.perm_media,
                      label: 'إجمالي',
                      value: '$totalMediaCount',
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'نشط',
                      value: '$activeMediaCount',
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Répartition par type
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.video_library,
                      label: 'فيديوهات',
                      value: '$videoCount',
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.image,
                      label: 'صور',
                      value: '$imageCount',
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Bouton pour voir tous les détails
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  onPressed:
                      () => context.push(
                        '/participant/archives/competition/${version.id}',
                      ),
                  text: 'عرض جميع الأرشيف',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTheme.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: AppTheme.labelSmall.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أرشيف المسابقات',
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : Column(
                children: [
                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'البحث في المسابقات...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),

                  // Liste des compétitions
                  Expanded(
                    child:
                        _filteredVersions.isEmpty
                            ? EmptyState(
                              icon: Icons.archive_outlined,
                              title:
                                  _searchQuery.isEmpty
                                      ? 'لا توجد مسابقات'
                                      : 'لا توجد نتائج للبحث',
                              subtitle:
                                  _searchQuery.isEmpty
                                      ? 'لا توجد مسابقات متاحة حالياً'
                                      : 'جرب البحث بكلمات مختلفة',
                            )
                            : ModernPullToRefresh(
                              onRefresh: _refreshData,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.spacingS,
                                ),
                                itemCount: _filteredVersions.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppTheme.spacingS,
                                    ),
                                    child: _buildCompetitionCard(
                                      _filteredVersions[index],
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
