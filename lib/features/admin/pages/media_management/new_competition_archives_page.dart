import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

class NewCompetitionArchivesPage extends StatefulWidget {
  const NewCompetitionArchivesPage({super.key});

  @override
  State<NewCompetitionArchivesPage> createState() =>
      _NewCompetitionArchivesPageState();
}

class _NewCompetitionArchivesPageState
    extends State<NewCompetitionArchivesPage> {
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
      return media.versionId == versionId;
    }).toList();
  }

  int _getActiveMediaCount(String versionId) {
    return _getMediaForVersion(
      versionId,
    ).where((media) => media.isActive).length;
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

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      onTap: () => context.push('/admin/archives/competition/${version.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Icons.archive,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.name,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مسابقة أهل القرآن الواتسابية',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.infoColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      activeMediaCount > 0
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        activeMediaCount > 0
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                  ),
                ),
                child: Text(
                  activeMediaCount > 0 ? 'نشط ($activeMediaCount)' : 'غير نشط',
                  style: TextStyle(
                    color:
                        activeMediaCount > 0
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingS),

          // Statistiques des médias
          Row(
            children: [
              Icon(
                Icons.perm_media,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                'إجمالي: $totalMediaCount',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
              const SizedBox(width: 4),
              Text(
                'نشط: $activeMediaCount',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.cancel, size: 16, color: AppTheme.errorColor),
              const SizedBox(width: 4),
              Text(
                'غير نشط: ${totalMediaCount - activeMediaCount}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.errorColor),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Répartition par type
          Row(
            children: [
              Icon(Icons.video_library, size: 16, color: AppTheme.infoColor),
              const SizedBox(width: 4),
              Text(
                'فيديوهات: $videoCount',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.infoColor),
              ),
              const SizedBox(width: 16),
              Icon(Icons.image, size: 16, color: AppTheme.warningColor),
              const SizedBox(width: 4),
              Text(
                'صور: $imageCount',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingS),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'إدارة الأرشيف',
                  onPressed:
                      () => context.push(
                        '/admin/archives/competition/${version.id}',
                      ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: PrimaryButton(
                  text: 'إضافة أرشيف',
                  onPressed: () => context.push('/admin/archives/batch-add'),
                ),
              ),
            ],
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
      floatingActionButton: ModernFAB(
        onPressed: () => context.push('/admin/archives/batch-add'),
        icon: Icons.add_box,
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      DashboardSection(
                        title: 'أرشيف المسابقات',
                        subtitle: 'إدارة أرشيف المسابقات والوسائط',
                        child: Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي المسابقات',
                                value: '${_versions.length}',
                                icon: Icons.emoji_events,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي الوسائط',
                                value: '${_allMedia.length}',
                                icon: Icons.perm_media,
                                color: AppTheme.infoColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Search Section
                      DashboardSection(
                        title: 'البحث والتصفية',
                        subtitle: 'البحث في المسابقات',
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'البحث في المسابقات...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Competitions List Section
                      DashboardSection(
                        title: 'قائمة المسابقات',
                        subtitle: '${_filteredVersions.length} مسابقة',
                        child:
                            _filteredVersions.isEmpty
                                ? SizedBox(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.archive_outlined,
                                          size: 64,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'لا توجد مسابقات'
                                              : 'لا توجد نتائج للبحث',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'لم يتم إضافة أي مسابقات بعد'
                                              : 'جرب تغيير معايير البحث',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children: [
                                    ..._filteredVersions.map(
                                      (version) =>
                                          _buildCompetitionCard(version),
                                    ),
                                    const SizedBox(height: AppTheme.spacingS),
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
