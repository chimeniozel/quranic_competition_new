import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/archive_media.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';

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
  String _selectedFilter = 'all';
  // Vidéo en cours d'ouverture (indicateur sur sa vignette)
  String? _openingVideoUrl; // 'all', 'video', 'image'

  @override
  void initState() {
    super.initState();
    _loadCompetitionArchives();
  }

  Future<void> _loadCompetitionArchives() async {
    try {
      // Version et médias chargés en parallèle ; seule la version demandée
      // est récupérée (et non plus la liste complète des versions).
      final versionFuture = _versionService.getVersionById(widget.versionId);
      final mediaFuture = _mediaService.getMediaByVersionId(widget.versionId);
      final version = await versionFuture;
      final media = await mediaFuture;
      if (version == null) throw Exception('Version non trouvée');

      // Seulement les médias actifs
      final activeMedia = media.where((m) => m.isActive).toList();
      if (!mounted) return;

      setState(() {
        _competitionName = version.name;
        _allMedia = activeMedia;
        _isLoading = false;
        _applyFilter();
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
      context.pop();
    }
  }


  Widget _buildVideoThumbnail(String videoUrl) {
    // Miniature standard (toujours disponible) + indicateur de chargement
    return YoutubeThumbnail.fromUrl(videoUrl);
  }

  Future<void> _launchVideo(String url) async {
    if (_openingVideoUrl != null) return;
    setState(() => _openingVideoUrl = url);
    try {
      // Convertir l'URL YouTube en format mobile
      String mobileUrl = url;
      if (url.contains('youtube.com/watch?v=')) {
        final videoId = url.split('v=')[1].split('&')[0];
        mobileUrl = 'https://youtu.be/$videoId';
      }

      final uri = Uri.parse(mobileUrl);
      final opened =
          await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح الفيديو'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture de la vidéo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الفيديو'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingVideoUrl = null);
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
                      gradient: AppTheme.primaryGradient,
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
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
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
                          child: AppNetworkImage(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
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
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textPrimaryColor,
                          ),
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
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            } else {
              _showImageDialog(media.url, media.title);
            }
          },
          child:
              media.type == MediaType.video
                  ? // Vidéo : thumbnail avec bouton play transparent
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildVideoThumbnail(media.url),
                      // Bouton lecture, ou indicateur pendant l'ouverture
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child:
                              _openingVideoUrl == media.url
                                  ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                        ),
                      ),
                      // Titre en bas
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.95),
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
                      ),
                    ],
                  )
                  : // Image : expansion complète sans titre
                  AppNetworkImage(
                    url: media.url,
                    width: double.infinity,
                    height: double.infinity,
                  ),
        ),
      ),
    );
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  /// Recalcule la liste affichée selon le filtre sélectionné
  void _applyFilter() {
    switch (_selectedFilter) {
      case 'video':
        _filteredMedia =
            _allMedia.where((media) => media.type == MediaType.video).toList();
        break;
      case 'image':
        _filteredMedia =
            _allMedia.where((media) => media.type == MediaType.image).toList();
        break;
      default:
        _filteredMedia = _allMedia;
        break;
    }
  }

  Widget _buildFilterButton(
    String filter,
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return AppStatTile(
      label: label,
      value: '$count',
      icon: icon,
      color: color,
      selected: _selectedFilter == filter,
      onTap: () => _selectFilter(filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _competitionName ?? 'الأرشيف';

    if (_isLoading) {
      return Scaffold(
        appBar: ModernAppBar(title: title),
        body: const ModernLoadingIndicator(),
      );
    }

    final videoCount = _allMedia.where((m) => m.type == MediaType.video).length;
    final imageCount = _allMedia.where((m) => m.type == MediaType.image).length;

    return Scaffold(
      appBar: ModernAppBar(title: 'أرشيف المسابقات'),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppGradientHeader(
            icon: Icons.photo_library_rounded,
            title: title,
            subtitle:
                _allMedia.isEmpty
                    ? 'لا توجد وسائط بعد'
                    : '${_allMedia.length} صورة وفيديو',
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child:
                _allMedia.isEmpty
                    ? const EmptyState(
                      icon: Icons.photo_library_rounded,
                      title: 'لا توجد أرشيفات',
                      subtitle: 'لا توجد أرشيفات متاحة لهذه النسخة',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Filtres : un appui affiche le type choisi
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterButton(
                                'all',
                                'الكل',
                                _allMedia.length,
                                Icons.apps_rounded,
                                AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: _buildFilterButton(
                                'image',
                                'صور',
                                imageCount,
                                Icons.image_rounded,
                                AppTheme.secondaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: _buildFilterButton(
                                'video',
                                'فيديو',
                                videoCount,
                                Icons.videocam_rounded,
                                AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        if (_filteredMedia.isEmpty)
                          const EmptyState(
                            icon: Icons.filter_alt_off_rounded,
                            title: 'لا توجد عناصر',
                            subtitle: 'لا توجد عناصر للعرض بالفلتر المحدد',
                          )
                        else
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
                            itemBuilder:
                                (context, index) =>
                                    _buildMediaCard(_filteredMedia[index]),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
