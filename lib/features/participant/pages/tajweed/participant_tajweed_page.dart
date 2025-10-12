import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

import '../../../../core/theme/app_theme.dart';
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

  List<TajweedRule> _allRules = [];
  List<TajweedRule> _filteredRules = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _searchQuery = '';
  TajweedType? _selectedType;
  Timer? _debounceTimer;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRules(reset: true);
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
    setState(() {
      _searchText = value;
      _searchQuery = value;
      _applyFilters();
    });
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredRules =
          _allRules.where((rule) {
            // Filtrage par recherche
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              if (!rule.title.toLowerCase().contains(searchLower) &&
                  !rule.content.toLowerCase().contains(searchLower)) {
                return false;
              }
            }

            // Filtrage par type
            if (_selectedType != null) {
              if (rule.type != _selectedType) {
                return false;
              }
            }

            return true;
          }).toList();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreRules();
      }
    }
  }

  Future<void> _loadRules({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _hasMore = true;
      }
    });

    try {
      final result = await _ruleService.getActiveRulesWithPagination(
        searchQuery: '', // Toujours charger toutes les règles
        typeFilter: null, // Pas de filtre côté serveur
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _allRules = result['rules'] as List<TajweedRule>;
        } else {
          _allRules.addAll(result['rules'] as List<TajweedRule>);
        }
        _hasMore = result['hasMore'] as bool;
        _isLoading = false;
        _isLoadingMore = false;

        // Appliquer les filtres après le chargement
        _applyFilters();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل قواعد التجويد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreRules() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadRules(reset: false);
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
    final uri = Uri.tryParse(url);
    if (uri == null) return '';

    if (uri.host == 'youtu.be') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    } else if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'] ?? '';
    }

    return '';
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Barre de recherche
        ModernCard(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'البحث في قواعد التجويد',
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ابحث في قواعد التجويد...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchText.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        // Filtres de type
        ModernCard(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: AppTheme.warningColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'تصفية المحتوى',
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        'الكل',
                        _selectedType == null,
                        () {
                          setState(() {
                            _selectedType = null;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: _buildFilterChip(
                        'منشورات',
                        _selectedType == TajweedType.post,
                        () {
                          setState(() {
                            _selectedType =
                                _selectedType == TajweedType.post
                                    ? null
                                    : TajweedType.post;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: _buildFilterChip(
                        'فيديوهات',
                        _selectedType == TajweedType.video,
                        () {
                          setState(() {
                            _selectedType =
                                _selectedType == TajweedType.video
                                    ? null
                                    : TajweedType.video;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color:
                  selected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleCard(TajweedRule rule) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      child: ModernCard(
        child: InkWell(
          onTap: () {
            context.push('/participant/tajweed/detail', extra: rule);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rule.title,
                        style: AppTheme.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            rule.type == TajweedType.post
                                ? AppTheme.primaryColor
                                : AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Text(
                        rule.type.displayName,
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                if (rule.imageUrl != null && rule.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: Image.network(
                      rule.imageUrl!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: AppTheme.backgroundColor,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],

                if (rule.type == TajweedType.video &&
                    rule.videoUrl != null) ...[
                  GestureDetector(
                    onTap: () => _launchVideo(rule.videoUrl!),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.video_library,
                                      color: AppTheme.errorColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'فيديو تعليمي على يوتيوب',
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.errorColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'اضغط لمشاهدة الفيديو في تطبيق يوتيوب',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _extractVideoId(rule.videoUrl!),
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.errorColor.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],

                Text(
                  rule.content,
                  style: AppTheme.labelMedium.copyWith(
                    height: 1.5,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Message pour indiquer que c'est cliquable
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'اضغط للتفاصيل',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'نشر بواسطة: الإدارة',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(rule.createdAt),
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.auto_stories,
      title:
          _searchQuery.isNotEmpty || _selectedType != null
              ? 'لا توجد قواعد تجويد تطابق البحث'
              : 'لا توجد قواعد تجويد متاحة حالياً',
      subtitle:
          _searchQuery.isNotEmpty || _selectedType != null
              ? 'جرب البحث بكلمات مختلفة أو غير الفلتر'
              : 'سيتم إضافة قواعد جديدة قريباً',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أحكام التجويد',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRules(reset: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () => _loadRules(reset: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildSearchAndFilters(),
                        ]),
                      ),
                    ),
                    if (_filteredRules.isEmpty && !_isLoading)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index < _filteredRules.length) {
                                return _buildRuleCard(_filteredRules[index]);
                              }
                              // Bouton "تحميل المزيد" pour les règles non filtrées
                              if (_hasMore &&
                                  _allRules.length < (_currentPage + 1) * 20) {
                                return _isLoadingMore
                                    ? const Padding(
                                      padding: EdgeInsets.all(
                                        AppTheme.spacingM,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                    : Padding(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingM,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: SecondaryButton(
                                          onPressed: _loadMoreRules,
                                          text: 'تحميل المزيد',
                                        ),
                                      ),
                                    );
                              }
                              return const SizedBox.shrink();
                            },
                            childCount:
                                _filteredRules.length + (_hasMore ? 1 : 0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
