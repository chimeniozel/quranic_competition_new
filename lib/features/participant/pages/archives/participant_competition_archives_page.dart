import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/archive_media.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class ParticipantCompetitionArchivesPage extends StatefulWidget {
  final String versionId;

  const ParticipantCompetitionArchivesPage({
    super.key,
    required this.versionId,
  });

  @override
  State<ParticipantCompetitionArchivesPage> createState() =>
      _ParticipantCompetitionArchivesPageState();
}

class _ParticipantCompetitionArchivesPageState
    extends State<ParticipantCompetitionArchivesPage> {
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();

  List<ArchiveMedia> _allMedia = [];
  List<ArchiveMedia> _filteredMedia = [];
  String? _competitionName;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'video', 'image'

  @override
  void initState() {
    super.initState();
    _loadCompetitionArchives();
  }

  Future<void> _loadCompetitionArchives() async {
    try {
      // Charger la version de la compétition
      final versions = await _versionService.fetchVersions();
      final version = versions.firstWhere(
        (v) => v.id == widget.versionId,
        orElse: () => throw Exception('Version non trouvée'),
      );

      // Charger tous les médias pour cette version
      final media = await _mediaService.getMediaByVersionId(widget.versionId);

      // Filtrer pour ne garder que les médias actifs
      final activeMedia = media.where((media) => media.isActive).toList();

      setState(() {
        _competitionName = version.name;
        _allMedia = activeMedia; // Seulement les médias actifs
        _filteredMedia = activeMedia; // Seulement les médias actifs
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
        context.pop();
      }
    }
  }

  Future<void> _launchVideo(String url) async {
    try {
      // Convertir l'URL YouTube en format mobile
      String mobileUrl = url;
      if (url.contains('youtube.com/watch?v=')) {
        final videoId = url.split('v=')[1].split('&')[0];
        mobileUrl = 'https://youtu.be/$videoId';
      }

      final uri = Uri.parse(mobileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح الفيديو'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الفيديو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageDialog(String imageUrl, String? title) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image_viewer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        final mediaQuery = MediaQuery.of(context);
        final dialogWidth = mediaQuery.size.width * 0.9;
        final dialogHeight = mediaQuery.size.height * 0.8;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title?.trim().isNotEmpty == true
                                ? title!.trim()
                                : 'عرض الصورة',
                            style: AppTheme.headingSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: AppTheme.backgroundColor,
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        child: InteractiveViewer(
                          clipBehavior: Clip.none,
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.image_not_supported, size: 64),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon:
                              const Icon(Icons.close, color: AppTheme.textPrimaryColor),
                          label: Text(
                            'إغلاق',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimaryColor,
                            ),
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
      },
    );
  }

  Widget _buildMediaCard(ArchiveMedia media) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: InkWell(
          onTap: () {
            if (media.type == MediaType.video) {
              if (media.url.isNotEmpty) {
                _launchVideo(media.url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('خطأ: رابط الفيديو غير متوفر'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              _showImageDialog(media.url, media.title);
            }
          },
          child:
              media.type == MediaType.video
                  ? // Vidéo : fond rouge avec titre en bas
                  Container(
                    height: double.infinity,
                    width: double.infinity,
                    color: AppTheme.errorColor,
                    child: Column(
                      children: [
                        // Zone principale avec icône de lecture
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: AppTheme.errorColor,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_filled,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'فيديو',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Titre en bas
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Text(
                            media.title != null && media.title!.isNotEmpty
                                ? media.title!
                                : 'فيديو ${media.order}',
                            style: AppTheme.labelSmall.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                  : // Image : expansion complète sans titre
                  Image.network(
                    media.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: AppTheme.backgroundColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 32),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'video':
          _filteredMedia =
              _allMedia
                  .where((media) => media.type == MediaType.video)
                  .toList();
          break;
        case 'image':
          _filteredMedia =
              _allMedia
                  .where((media) => media.type == MediaType.image)
                  .toList();
          break;
        default:
          _filteredMedia = _allMedia;
          break;
      }
    });
  }

  Widget _buildFilterButton(String filter, String label, int count) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => _applyFilter(filter),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
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
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTheme.labelLarge.copyWith(
                color:
                    isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.labelSmall.copyWith(
                color:
                    isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: ModernAppBar(title: _competitionName ?? 'المسابقة'),
        body: const LoadingOverlay(child: SizedBox()),
      );
    }

    if (_allMedia.isEmpty) {
      return Scaffold(
        appBar: ModernAppBar(title: _competitionName ?? 'المسابقة'),
        body: EmptyState(
          icon: Icons.archive_outlined,
          title: 'لا توجد أرشيفات',
          subtitle: 'لا توجد أرشيفات متاحة لهذه المسابقة',
        ),
      );
    }

    return Scaffold(
      appBar: ModernAppBar(title: _competitionName ?? 'المسابقة'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statistiques
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                          child: Icon(
                            Icons.archive,
                            color: AppTheme.successColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            _competitionName!,
                            style: AppTheme.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_allMedia.length}',
                                style: AppTheme.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                  fontSize: 24,
                                ),
                              ),
                              Text(
                                'أرشيف متاحة',
                                style: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Boutons de filtre
            if (_allMedia.isNotEmpty) ...[
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'تصفية الأرشيف',
                            style: AppTheme.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterButton(
                              'all',
                              'الكل',
                              _allMedia.length,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: _buildFilterButton(
                              'video',
                              'فيديو',
                              _allMedia
                                  .where((m) => m.type == MediaType.video)
                                  .length,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: _buildFilterButton(
                              'image',
                              'صور',
                              _allMedia
                                  .where((m) => m.type == MediaType.image)
                                  .length,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
            ],

            // Grille des médias filtrés
            if (_filteredMedia.isNotEmpty) ...[
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            child: Icon(
                              Icons.grid_view,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              _selectedFilter == 'all'
                                  ? 'جميع الأرشيف (${_filteredMedia.length})'
                                  : _selectedFilter == 'video'
                                  ? 'الفيديوهات (${_filteredMedia.length})'
                                  : 'الصور (${_filteredMedia.length})',
                              style: AppTheme.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppTheme.spacingS,
                              mainAxisSpacing: AppTheme.spacingS,
                              childAspectRatio: 1.1,
                            ),
                        itemCount: _filteredMedia.length,
                        itemBuilder: (context, index) {
                          final mediaItem = _filteredMedia[index];
                          return _buildMediaCard(mediaItem);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_allMedia.isNotEmpty) ...[
              EmptyState(
                icon: Icons.filter_alt_off,
                title: 'لا توجد عناصر',
                subtitle: 'لا توجد عناصر للعرض بالفلتر المحدد',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
