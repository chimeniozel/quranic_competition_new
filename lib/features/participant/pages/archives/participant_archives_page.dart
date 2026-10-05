import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
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
      // Les deux requêtes sont indépendantes : on les lance en parallèle
      final versionsFuture = _versionService.fetchVersions();
      final mediaFuture = _mediaService.getAllMediaSafe();
      final versions = await versionsFuture;
      final allMedia = await mediaFuture;
      if (!mounted) return;

      setState(() {
        _versions = versions;
        _allMedia = allMedia;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des archives: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل الأرشيف. تحقق من الاتصال وحاول مجدداً.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
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

  Widget _buildCompetitionCard(CompetitionVersion version) {
    final mediaForVersion = _getMediaForVersion(version.id);
    final videoCount =
        mediaForVersion.where((m) => m.type == MediaType.video).length;
    final imageCount =
        mediaForVersion.where((m) => m.type == MediaType.image).length;

    return AppListCard(
      onTap:
          () => context.push('/participant/archives/competition/${version.id}'),
      leading: const AppIconBadge(
        icon: Icons.photo_library_rounded,
        color: AppTheme.primaryColor,
        size: 24,
      ),
      title: version.name,
      subtitle:
          mediaForVersion.isEmpty
              ? 'لا توجد وسائط بعد'
              : '${mediaForVersion.length} صورة وفيديو',
      tags: [
        if (imageCount > 0)
          AppTag(
            text: '$imageCount صور',
            color: AppTheme.secondaryColor,
            icon: Icons.image_rounded,
          ),
        if (videoCount > 0)
          AppTag(
            text: '$videoCount فيديو',
            color: AppTheme.accentColor,
            icon: Icons.videocam_rounded,
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
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _refreshData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  children: [
                    const AppGradientHeader(
                      icon: Icons.photo_library_rounded,
                      title: 'أرشيف المسابقات',
                      subtitle: 'صور ومقاطع من النسخ السابقة',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ModernSearchBar(
                            controller: _searchController,
                            hintText: 'البحث في المسابقات...',
                            onChanged: _onSearchChanged,
                            onClear: () => _onSearchChanged(''),
                            margin: EdgeInsets.zero,
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          if (_filteredVersions.isEmpty)
                            EmptyState(
                              icon: Icons.photo_library_rounded,
                              title:
                                  _searchQuery.isEmpty
                                      ? 'لا توجد مسابقات'
                                      : 'لا توجد نتائج للبحث',
                              subtitle:
                                  _searchQuery.isEmpty
                                      ? 'لا توجد مسابقات متاحة حالياً'
                                      : 'جرب البحث بكلمات مختلفة',
                            )
                          else
                            ..._filteredVersions.map(_buildCompetitionCard),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
