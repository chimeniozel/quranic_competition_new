import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/competition_archive_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_archive.dart';
import 'package:quranic_competition/models/archive_media.dart';

class ParticipantArchivesPage extends StatefulWidget {
  const ParticipantArchivesPage({super.key});

  @override
  State<ParticipantArchivesPage> createState() =>
      _ParticipantArchivesPageState();
}

class _ParticipantArchivesPageState extends State<ParticipantArchivesPage> {
  final CompetitionArchiveService _archiveService = CompetitionArchiveService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<CompetitionArchive> _archives = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadArchives();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreArchives();
      }
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
          _currentPage = 0;
          _archives.clear();
          _hasMore = true;
        });
        _loadArchives();
      }
    });
  }

  Future<void> _loadArchives() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newArchives = await _archiveService.getActiveArchivesWithPagination(
        page: _currentPage,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Charger les médias pour chaque archive
      for (final archive in newArchives) {
        final media = await _mediaService.getMediaByArchiveId(archive.id);
        archive.media.addAll(media);
      }

      setState(() {
        if (_currentPage == 0) {
          _archives = newArchives;
        } else {
          _archives.addAll(newArchives);
        }
        _hasMore = newArchives.length == 20; // Si moins de 20, c'est la fin
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأرشيف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreArchives() async {
    setState(() {
      _currentPage++;
    });
    await _loadArchives();
  }

  Future<void> _refreshArchives() async {
    setState(() {
      _currentPage = 0;
      _archives.clear();
      _hasMore = true;
    });
    await _loadArchives();
  }

  void _openVideo(String videoUrl) {
    // Convertir l'URL YouTube en format mobile si nécessaire
    String mobileUrl = videoUrl;
    if (videoUrl.contains('youtube.com/watch?v=')) {
      final videoId = videoUrl.split('v=')[1].split('&')[0];
      mobileUrl = 'https://youtu.be/$videoId';
    }

    // Ouvrir la vidéo dans l'application YouTube ou le navigateur
    // Note: Vous devrez ajouter url_launcher pour cette fonctionnalité
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فتح الفيديو: $mobileUrl'),
        action: SnackBarAction(
          label: 'فتح',
          onPressed: () {
            // TODO: Implémenter l'ouverture de l'URL
          },
        ),
      ),
    );
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

  Widget _buildMediaGrid(List<ArchiveMedia> media) {
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'الميديا (${media.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: media.length,
          itemBuilder: (context, index) {
            final mediaItem = media[index];
            return _buildMediaCard(mediaItem);
          },
        ),
      ],
    );
  }

  Widget _buildMediaCard(ArchiveMedia media) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (media.type == MediaType.video) {
            _openVideo(media.url);
          } else {
            _showImageDialog(media.url, media.title);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image ou icône de vidéo
            Expanded(
              child:
                  media.type == MediaType.video
                      ? Container(
                        color: Colors.red[50],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 48,
                              color: Colors.red[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'فيديو',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Image.network(
                        media.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
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
            // Titre
            if (media.title != null && media.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  media.title!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveCard(CompetitionArchive archive) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec titre et version
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        archive.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        archive.versionName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'نشط',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              archive.description,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Date de l'événement
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'تاريخ الحدث: ${_formatDate(archive.eventDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            // Grille des médias
            _buildMediaGrid(archive.media),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف المسابقات'),
        actions: [
          IconButton(
            onPressed: _refreshArchives,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث في الأرشيف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 0;
                              _archives.clear();
                              _hasMore = true;
                            });
                            _loadArchives();
                          },
                          icon: const Icon(Icons.clear),
                        )
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // Liste des archives
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshArchives,
              child:
                  _archives.isEmpty && !_isLoading
                      ? const Center(
                        child: Text(
                          'لا توجد أرشيفات متاحة',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount: _archives.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _archives.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _buildArchiveCard(_archives[index]);
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
