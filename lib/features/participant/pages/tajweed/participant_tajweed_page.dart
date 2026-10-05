import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class ParticipantTajweedPage extends StatefulWidget {
  const ParticipantTajweedPage({super.key});

  @override
  State<ParticipantTajweedPage> createState() => _ParticipantTajweedPageState();
}

class _ParticipantTajweedPageState extends State<ParticipantTajweedPage> {
  final TajweedRuleService _ruleService = TajweedRuleService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Toutes les règles actives : la recherche et le filtre par type portent
  /// ainsi sur l'ensemble des règles, et pas seulement sur une page chargée.
  List<TajweedRule> _allRules = [];
  List<TajweedRule> _filteredRules = [];
  bool _isLoading = false;
  String _searchQuery = '';
  TajweedType? _selectedType;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _applyFilters();
      });
    });
  }

  /// Recalcule la liste affichée (à appeler dans un setState)
  void _applyFilters() {
    final searchLower = _searchQuery.trim().toLowerCase();
    _filteredRules =
        _allRules.where((rule) {
          if (_selectedType != null && rule.type != _selectedType) {
            return false;
          }
          if (searchLower.isEmpty) return true;
          return rule.title.toLowerCase().contains(searchLower) ||
              rule.content.toLowerCase().contains(searchLower);
        }).toList();
  }

  Future<void> _loadRules() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final rules = await _ruleService.getActiveRules();
      if (!mounted) return;
      setState(() {
        _allRules = rules;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des règles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل أحكام التجويد. حاول مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح رابط الفيديو'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الفيديو: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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

  Widget _buildSearchAndFilters() {
    Widget chip(String label, IconData icon, TajweedType? type) {
      final selected = _selectedType == type;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppTheme.spacingXS),
        child: ChoiceChip(
          avatar: Icon(
            icon,
            size: 16,
            color:
                selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
          ),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected:
              (_) => setState(() {
                // Un second appui sur le filtre actif revient à « الكل »
                _selectedType = selected && type != null ? null : type;
                _applyFilters();
              }),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernSearchBar(
          controller: _searchController,
          hintText: 'ابحث في أحكام التجويد...',
          margin: EdgeInsets.zero,
          onChanged: _onSearchChanged,
          onClear: () => _onSearchChanged(''),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Wrap(
          children: [
            chip('الكل', Icons.apps_rounded, null),
            chip('منشورات', Icons.article_rounded, TajweedType.post),
            chip('فيديوهات', Icons.play_circle_rounded, TajweedType.video),
          ],
        ),
      ],
    );
  }

  Widget _buildRuleCard(TajweedRule rule) {
    final isVideo = rule.type == TajweedType.video;
    final hasVideo = isVideo && (rule.videoUrl?.isNotEmpty ?? false);
    final hasImage = rule.imageUrl != null && rule.imageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowM,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/participant/tajweed/detail', extra: rule),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vidéo : miniature avec bouton lecture ; sinon image éventuelle
              if (hasVideo)
                GestureDetector(
                  onTap: () => _launchVideo(rule.videoUrl!),
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
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasImage)
                Image.network(
                  rule.imageUrl!,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIconBadge(
                          icon:
                              isVideo
                                  ? Icons.play_circle_rounded
                                  : Icons.record_voice_over_rounded,
                          color:
                              isVideo
                                  ? AppTheme.accentColor
                                  : AppTheme.primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            rule.title,
                            style: AppTheme.bodyLarge.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDarkColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppTag(
                          text: rule.type.displayName,
                          color:
                              isVideo
                                  ? AppTheme.accentColor
                                  : AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      rule.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    const Divider(),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          'عرض التفاصيل',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
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
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    final videoId = _extractVideoId(videoUrl);

    if (videoId.isEmpty) {
      return Container(
        height: 200,
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
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 200,
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
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Final fallback
            return Container(
              height: 200,
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

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.auto_stories_rounded,
      title:
          _searchQuery.isNotEmpty || _selectedType != null
              ? 'لا توجد أحكام تجويد تطابق البحث'
              : 'لا توجد أحكام تجويد متاحة حالياً',
      subtitle:
          _searchQuery.isNotEmpty || _selectedType != null
              ? 'جرب البحث بكلمات مختلفة أو غير الفلتر'
              : 'سيتم إضافة أحكام جديدة قريباً',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أحكام التجويد',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _loadRules,
          ),
        ],
      ),
      body:
          _isLoading && _allRules.isEmpty
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadRules,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    const SliverToBoxAdapter(
                      child: AppGradientHeader(
                        icon: Icons.record_voice_over_rounded,
                        title: 'أحكام التجويد',
                        subtitle: 'تعلّم أحكام التلاوة بالشرح والأمثلة',
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      sliver: SliverToBoxAdapter(
                        child: _buildSearchAndFilters(),
                      ),
                    ),
                    if (_filteredRules.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildRuleCard(_filteredRules[index]),
                            childCount: _filteredRules.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppTheme.spacingL),
                    ),
                  ],
                ),
              ),
    );
  }
}
