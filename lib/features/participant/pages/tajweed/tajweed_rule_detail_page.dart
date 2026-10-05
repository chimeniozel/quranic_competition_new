import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/modern_navigation.dart';

class TajweedRuleDetailPage extends StatelessWidget {
  final TajweedRule rule;

  const TajweedRuleDetailPage({super.key, required this.rule});

  Future<void> _launchVideo(String url) async {
    try {
      // Convertir le lien YouTube en format mobile si nécessaire
      String finalUrl = _convertToMobileYouTubeUrl(url);
      final uri = Uri.parse(finalUrl);

      if (await canLaunchUrl(uri)) {
        // Essayer d'ouvrir dans l'application YouTube d'abord
        final youtubeUri = Uri.parse('vnd.youtube:${_extractVideoId(url)}');
        if (await canLaunchUrl(youtubeUri)) {
          await launchUrl(youtubeUri);
        } else {
          // Sinon ouvrir dans le navigateur
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Fallback: essayer d'ouvrir l'URL originale
        final originalUri = Uri.parse(url);
        if (await canLaunchUrl(originalUri)) {
          await launchUrl(originalUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Gérer l'erreur silencieusement ou afficher un message
      print('Erreur lors de l\'ouverture de la vidéo: $e');
    }
  }

  String _convertToMobileYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    // Si c'est déjà un lien mobile, le retourner tel quel
    if (uri.host == 'm.youtube.com') return url;

    // Convertir youtube.com en m.youtube.com
    if (uri.host == 'www.youtube.com' || uri.host == 'youtube.com') {
      return url.replaceFirst(RegExp(r'(www\.)?youtube\.com'), 'm.youtube.com');
    }

    // Convertir youtu.be en m.youtube.com
    if (uri.host == 'youtu.be') {
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return 'https://m.youtube.com/watch?v=$videoId';
    }

    return url;
  }

  String _extractVideoId(String url) {
    if (url.isEmpty) return '';

    try {
      // Handle youtu.be short URLs
      if (url.contains('youtu.be/')) {
        final parts = url.split('youtu.be/');
        if (parts.length > 1) {
          final videoId = parts[1].split('?')[0].split('&')[0];
          return videoId;
        }
      }

      // Handle youtube.com URLs
      if (url.contains('youtube.com')) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          // Try query parameter first
          final videoId = uri.queryParameters['v'];
          if (videoId != null && videoId.isNotEmpty) {
            return videoId;
          }

          // Try path segments for embed URLs
          if (uri.pathSegments.contains('embed')) {
            final embedIndex = uri.pathSegments.indexOf('embed');
            if (embedIndex + 1 < uri.pathSegments.length) {
              return uri.pathSegments[embedIndex + 1].split('?')[0];
            }
          }

          // Try watch path
          if (uri.pathSegments.contains('watch') &&
              uri.queryParameters.containsKey('v')) {
            return uri.queryParameters['v']!;
          }
        }
      }

      // Try to extract from any YouTube URL pattern
      final regex = RegExp(
        r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})',
      );
      final match = regex.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1) ?? '';
      }
    } catch (e) {
      print('Error extracting video ID: $e');
    }

    return '';
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    final videoId = _extractVideoId(videoUrl);

    if (videoId.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,
        color: AppTheme.backgroundColor,
        child: const Center(
          child: Icon(
            Icons.video_library_rounded,
            size: 50,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      );
    }

    // Try maxresdefault first, then hqdefault as fallback
    return Image.network(
      'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      width: double.infinity,
      height: 250,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 250,
          width: double.infinity,
          color: AppTheme.backgroundColor,
          child: Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Fallback to hqdefault if maxresdefault fails
        return Image.network(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Final fallback
            return Container(
              height: 250,
              width: double.infinity,
              color: AppTheme.backgroundColor,
              child: const Center(
                child: Icon(
                  Icons.video_library_rounded,
                  size: 50,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _share() {
    final video = rule.videoUrl;
    SharePlus.instance.share(
      ShareParams(
        text: [
          rule.title,
          rule.content,
          if (video != null && video.isNotEmpty) video,
        ].join('\n\n'),
        subject: rule.title,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = rule.type == TajweedType.video;
    final hasVideo = isVideo && (rule.videoUrl?.isNotEmpty ?? false);
    final hasImage = rule.imageUrl != null && rule.imageUrl!.isNotEmpty;

    return Scaffold(
      appBar: ModernAppBar(
        title: 'أحكام التجويد',
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة',
            onPressed: _share,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppGradientHeader(
            icon:
                isVideo
                    ? Icons.play_circle_rounded
                    : Icons.record_voice_over_rounded,
            title: rule.title,
            badges: [
              AppHeaderBadge(
                icon: isVideo ? Icons.videocam_rounded : Icons.article_rounded,
                text: rule.type.displayName,
              ),
              AppHeaderBadge(
                icon: Icons.calendar_today_rounded,
                text: _formatDate(rule.createdAt),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasVideo) ...[
                  GestureDetector(
                    onTap: () => _launchVideo(rule.videoUrl!),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        boxShadow: AppTheme.shadowM,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildVideoThumbnail(rule.videoUrl!),
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ] else if (hasImage) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      boxShadow: AppTheme.shadowM,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      rule.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            height: 180,
                            color: AppTheme.dividerColor,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 48,
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
                AppSection(
                  icon: Icons.auto_stories_rounded,
                  title: 'الشرح',
                  child: SelectableText(
                    rule.content,
                    textAlign: TextAlign.justify,
                    style: AppTheme.bodyLarge.copyWith(
                      fontSize: 17,
                      height: 1.9,
                    ),
                  ),
                ),
                if (rule.updatedAt != rule.createdAt) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'آخر تحديث: ${_formatDate(rule.updatedAt)}',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        style: AppButtonStyles.outlined(AppTheme.primaryColor),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('مشاركة'),
                      ),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchVideo(rule.videoUrl!),
                          style: AppButtonStyles.filled(AppTheme.primaryColor),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('مشاهدة الفيديو'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
