import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';

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

  CompetitionVersion? _version;
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
        _version = version;
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
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.error, size: 50, color: Colors.red),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildMediaCard(ArchiveMedia media) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
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
                  color: Colors.red[600],
                  child: Column(
                    children: [
                      // Zone principale avec icône de lecture
                      Expanded(
                        child: Container(
                          color: Colors.red[600],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 64,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
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
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          media.title != null && media.title!.isNotEmpty
                              ? media.title!
                              : 'فيديو ${media.order}',
                          style: const TextStyle(
                            fontSize: 12,
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
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 32),
                      ),
                    );
                  },
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
    return ElevatedButton(
      onPressed: () => _applyFilter(filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue[600] : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text('$label ($count)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_allMedia.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_competitionName ?? 'المسابقة'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'لا توجد أرشيفات متاحة لهذه المسابقة',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_competitionName ?? 'المسابقة'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statistiques
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _competitionName!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${_allMedia.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                              ),
                            ),
                            const Text(
                              'أرشيف متاحة',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Boutons de filtre
            if (_allMedia.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterButton('all', 'الكل', _allMedia.length),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    'video',
                    'فيديو',
                    _allMedia.where((m) => m.type == MediaType.video).length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    'image',
                    'صور',
                    _allMedia.where((m) => m.type == MediaType.image).length,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Grille des médias filtrés
            if (_filteredMedia.isNotEmpty) ...[
              Text(
                _selectedFilter == 'all'
                    ? 'جميع الأرشيف (${_filteredMedia.length})'
                    : _selectedFilter == 'video'
                    ? 'الفيديوهات (${_filteredMedia.length})'
                    : 'الصور (${_filteredMedia.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: _filteredMedia.length,
                itemBuilder: (context, index) {
                  final mediaItem = _filteredMedia[index];
                  return _buildMediaCard(mediaItem);
                },
              ),
            ] else if (_allMedia.isNotEmpty) ...[
              const Center(
                child: Text(
                  'لا توجد عناصر للعرض',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
