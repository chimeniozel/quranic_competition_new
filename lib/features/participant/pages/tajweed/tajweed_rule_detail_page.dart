import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

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
          if (uri.pathSegments.contains('watch') && uri.queryParameters.containsKey('v')) {
            return uri.queryParameters['v']!;
          }
        }
      }
      
      // Try to extract from any YouTube URL pattern
      final regex = RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})');
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
          child: Icon(Icons.video_library, size: 50, color: AppTheme.textSecondaryColor),
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
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
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
                child: Icon(Icons.video_library, size: 50, color: AppTheme.textSecondaryColor),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'التفاصيل',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implémenter le partage
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image principale
            if (rule.imageUrl != null && rule.imageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(AppTheme.spacingS),
                width: double.infinity,
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Image.network(
                    rule.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 250,
                        color: AppTheme.backgroundColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      );
                    },
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et type
                  ModernCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.title,
                              style: AppTheme.labelLarge.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  rule.type == TajweedType.post
                                      ? AppTheme.primaryColor
                                      : AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            child: Text(
                              rule.type.displayName,
                              style: AppTheme.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Vidéo si c'est une vidéo
                  if (rule.type == TajweedType.video &&
                      rule.videoUrl != null &&
                      rule.videoUrl!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _launchVideo(rule.videoUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildVideoThumbnail(rule.videoUrl!),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              child: Icon(
                                Icons.play_circle_filled,
                                color: Colors.white.withOpacity(0.7),
                                size: 60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                  ],

                  // Contenu principal
                  ModernCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_stories,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'المحتوى',
                                style: AppTheme.labelLarge.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            rule.content,
                            style: AppTheme.labelMedium.copyWith(
                              height: 1.8,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Informations sur la règle
                  ModernCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'نشر بواسطة: الإدارة',
                                style: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppTheme.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'تاريخ النشر: ${_formatDate(rule.createdAt)}',
                                style: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (rule.updatedAt != rule.createdAt) ...[
                            const SizedBox(height: AppTheme.spacingS),
                            Row(
                              children: [
                                Icon(
                                  Icons.update,
                                  color: AppTheme.primaryColor,
                                  size: 16,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'آخر تحديث: ${_formatDate(rule.updatedAt)}',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // Boutons d'action
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () => Navigator.of(context).pop(),
                          text: 'العودة',
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      if (rule.type == TajweedType.video &&
                          rule.videoUrl != null)
                        Expanded(
                          child: PrimaryButton(
                            onPressed: () => _launchVideo(rule.videoUrl!),
                            text: 'فتح الفيديو',
                            icon: Icons.play_arrow,
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
    );
  }
}
