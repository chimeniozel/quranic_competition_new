import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            backgroundColor: AppTheme.errorColor,
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
        mediaForVersion.where((m) => m.type == MediaType.video).length;
    final imageCount =
        mediaForVersion.where((m) => m.type == MediaType.image).length;

    final inactiveCount = totalMediaCount - activeMediaCount;

    return AppListCard(
      onTap: () => context.push('/admin/archives/competition/${version.id}'),
      leading: AppIconBadge(
        icon: Icons.photo_library_rounded,
        color:
            activeMediaCount > 0
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
        size: 24,
      ),
      title: version.name,
      subtitle: totalMediaCount == 0 ? 'لا توجد وسائط بعد' : null,
      tags: [
        AppTag(
          text: '$totalMediaCount وسائط',
          color: AppTheme.primaryColor,
          icon: Icons.perm_media_rounded,
        ),
        if (videoCount > 0)
          AppTag(
            text: '$videoCount فيديو',
            color: AppTheme.accentColor,
            icon: Icons.videocam_rounded,
          ),
        if (imageCount > 0)
          AppTag(
            text: '$imageCount صور',
            color: AppTheme.warningColor,
            icon: Icons.image_rounded,
          ),
        if (inactiveCount > 0)
          AppTag(
            text: '$inactiveCount مخفية',
            color: AppTheme.textSecondaryColor,
            icon: Icons.visibility_off_rounded,
          ),
      ],
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: ModernFAB(
        onPressed: () => context.push('/admin/archives/batch-add'),
        icon: Icons.add_box_rounded,
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
                                icon: Icons.emoji_events_rounded,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي الوسائط',
                                value: '${_allMedia.length}',
                                icon: Icons.perm_media_rounded,
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
                        child: ModernSearchBar(
                          controller: _searchController,
                          hintText: 'البحث في المسابقات...',
                          onChanged: _onSearchChanged,
                          onClear: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          margin: EdgeInsets.zero,
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
                                          Icons.archive_rounded,
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
