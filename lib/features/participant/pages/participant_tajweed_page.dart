import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

class ParticipantTajweedPage extends StatefulWidget {
  const ParticipantTajweedPage({super.key});

  @override
  State<ParticipantTajweedPage> createState() => _ParticipantTajweedPageState();
}

class _ParticipantTajweedPageState extends State<ParticipantTajweedPage> {
  final TajweedRuleService _ruleService = TajweedRuleService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<TajweedRule> _rules = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
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
    });
    _searchQuery = value;
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadRules(reset: true);
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
        searchQuery: _searchQuery,
        typeFilter: _selectedType,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (reset) {
          _rules = result['rules'] as List<TajweedRule>;
        } else {
          _rules.addAll(result['rules'] as List<TajweedRule>);
        }
        _totalCount = result['totalCount'] as int;
        _hasMore = result['hasMore'] as bool;
        _isLoading = false;
        _isLoadingMore = false;
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'البحث في قواعد التجويد...',
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Filtres de type
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('الكل'),
                  selected: _selectedType == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('منشورات'),
                  selected: _selectedType == TajweedType.post,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? TajweedType.post : null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('فيديوهات'),
                  selected: _selectedType == TajweedType.video,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? TajweedType.video : null;
                    });
                    _loadRules(reset: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(TajweedRule rule) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/participant/tajweed/detail', extra: rule);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          rule.type == TajweedType.post
                              ? Colors.blue
                              : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rule.type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (rule.imageUrl != null && rule.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    rule.imageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (rule.type == TajweedType.video && rule.videoUrl != null) ...[
                GestureDetector(
                  onTap: () => _launchVideo(rule.videoUrl!),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.video_library,
                                    color: Colors.red[600],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'فيديو تعليمي على يوتيوب',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'اضغط لمشاهدة الفيديو في تطبيق يوتيوب',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _extractVideoId(rule.videoUrl!),
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.open_in_new,
                          color: Colors.red[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(
                rule.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Message pour indiquer que c'est cliquable
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      'اضغط للتفاصيل',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'نشر بواسطة: الإدارة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(rule.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد قواعد تجويد تطابق البحث'
                  : 'لا توجد قواعد تجويد متاحة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'سيتم إضافة قواعد جديدة قريباً',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أحكام التجويد'),
            if (_totalCount > 0)
              Text(
                '$_totalCount أحكام متاحة',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRules(reset: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildSearchAndFilters(),
                  Expanded(
                    child:
                        _rules.isEmpty && !_isLoading
                            ? _buildEmptyState()
                            : RefreshIndicator(
                              onRefresh: () => _loadRules(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _rules.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _rules.length) {
                                    return _isLoadingMore
                                        ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                        : _hasMore
                                        ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: ElevatedButton.icon(
                                              onPressed: _loadMoreRules,
                                              icon: const Icon(
                                                Icons.expand_more,
                                              ),
                                              label: const Text('تحميل المزيد'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink();
                                  }
                                  return _buildRuleCard(_rules[index]);
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
