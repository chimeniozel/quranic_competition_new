import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/competition_archive_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_archive.dart';
import 'package:quranic_competition/models/archive_media.dart';

class ParticipantArchiveDetailPage extends StatefulWidget {
  final String archiveId;

  const ParticipantArchiveDetailPage({super.key, required this.archiveId});

  @override
  State<ParticipantArchiveDetailPage> createState() =>
      _ParticipantArchiveDetailPageState();
}

class _ParticipantArchiveDetailPageState
    extends State<ParticipantArchiveDetailPage> {
  final CompetitionArchiveService _archiveService = CompetitionArchiveService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();

  CompetitionArchive? _archive;
  List<ArchiveMedia> _media = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchiveDetails();
  }

  Future<void> _loadArchiveDetails() async {
    try {
      final archive = await _archiveService.getArchiveById(widget.archiveId);
      final media = await _mediaService.getMediaByArchiveId(widget.archiveId);

      setState(() {
        _archive = archive;
        _media = media;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل تفاصيل الأرشيف: $e'),
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

  Widget _buildMediaItem(ArchiveMedia media) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec type et ordre
            Row(
              children: [
                Icon(
                  media.type == MediaType.video
                      ? Icons.video_library
                      : Icons.image,
                  color:
                      media.type == MediaType.video ? Colors.red : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  media.type == MediaType.video ? 'فيديو' : 'صورة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        media.type == MediaType.video
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ترتيب: ${media.order}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contenu du média
            if (media.type == MediaType.video) ...[
              // Vidéo
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: InkWell(
                  onTap: () => _launchVideo(media.url),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: Colors.red[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط لمشاهدة الفيديو',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        media.url,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: InkWell(
                  onTap: () => _showImageDialog(media.url, media.title),
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      media.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_archive == null) {
      return const Scaffold(
        body: Center(
          child: Text('الأرشيف غير موجود', style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الأرشيف'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations de l'archive
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      _archive!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Version
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 20,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الإصدار: ${_archive!.versionName}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تاريخ الحدث: ${_formatDate(_archive!.eventDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    if (_archive!.description.isNotEmpty) ...[
                      const Text(
                        'الوصف:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _archive!.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section des médias
            Text(
              'الميديا (${_media.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_media.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'لا توجد ميديا في هذا الأرشيف',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ] else ...[
              // Liste des médias
              ..._media.map((media) => _buildMediaItem(media)),
            ],
          ],
        ),
      ),
    );
  }
}
