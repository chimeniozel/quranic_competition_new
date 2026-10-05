import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/youtube_utils.dart';

/// Image réseau avec indicateur de chargement commun à l'application :
/// fond qui pulse doucement + icône du média + progression, puis apparition
/// en fondu ; état d'erreur propre si l'image ne peut pas être chargée.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Icône affichée pendant le chargement (image, vidéo...)
  final IconData placeholderIcon;

  /// Remplace l'état d'erreur par défaut (ex. : essayer une autre URL)
  final ImageErrorWidgetBuilder? errorBuilder;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderIcon = Icons.image_rounded,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      // Apparition en fondu une fois la première image décodée
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final total = progress.expectedTotalBytes;
        return MediaLoadingPlaceholder(
          width: width,
          height: height,
          icon: placeholderIcon,
          progress:
              total != null && total > 0
                  ? progress.cumulativeBytesLoaded / total
                  : null,
        );
      },
      errorBuilder:
          errorBuilder ??
          (context, error, stackTrace) => MediaErrorPlaceholder(
            width: width,
            height: height,
            icon: Icons.broken_image_rounded,
          ),
    );
  }
}

/// Miniature d'une vidéo YouTube, avec indicateur de chargement.
///
/// Utilise directement la miniature standard (toujours disponible) : la
/// haute résolution n'existe que pour les vidéos HD et répondait 404 pour la
/// plupart des vidéos de l'archive.
class YoutubeThumbnail extends StatelessWidget {
  final String videoId;
  final BoxFit fit;

  const YoutubeThumbnail({
    super.key,
    required this.videoId,
    this.fit = BoxFit.cover,
  });

  /// À partir d'un lien YouTube complet
  factory YoutubeThumbnail.fromUrl(String url, {BoxFit fit = BoxFit.cover}) =>
      YoutubeThumbnail(videoId: YoutubeUtils.videoId(url), fit: fit);

  @override
  Widget build(BuildContext context) {
    if (videoId.isEmpty) {
      return const MediaErrorPlaceholder(icon: Icons.videocam_off_rounded);
    }
    return AppNetworkImage(
      url: YoutubeUtils.thumbnailUrl(videoId),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholderIcon: Icons.smart_display_rounded,
      errorBuilder:
          (context, error, stackTrace) => AppNetworkImage(
            url: YoutubeUtils.fallbackThumbnailUrl(videoId),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            placeholderIcon: Icons.smart_display_rounded,
            errorBuilder:
                (context, error, stackTrace) => const MediaErrorPlaceholder(
                  icon: Icons.videocam_off_rounded,
                ),
          ),
    );
  }
}

/// Fond de chargement animé (pulsation douce)
class MediaLoadingPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final double? progress;

  const MediaLoadingPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.image_rounded,
    this.progress,
  });

  @override
  State<MediaLoadingPlaceholder> createState() =>
      _MediaLoadingPlaceholderState();
}

class _MediaLoadingPlaceholderState extends State<MediaLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height ?? double.infinity,
          color: Color.lerp(
            AppTheme.primaryColor.withValues(alpha: 0.05),
            AppTheme.primaryColor.withValues(alpha: 0.12),
            t,
          ),
          child: child,
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 30,
              color: AppTheme.primaryColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: AppTheme.spacingS),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: widget.progress,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État d'erreur d'un média
class MediaErrorPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;

  const MediaErrorPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.broken_image_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: AppTheme.dividerColor.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: AppTheme.textDisabledColor),
            const SizedBox(height: 4),
            Text(
              'تعذر التحميل',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
