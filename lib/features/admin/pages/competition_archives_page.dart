import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_archive_service.dart';
import 'package:quranic_competition/models/competition_archive.dart';

class CompetitionArchivesPage extends StatefulWidget {
  const CompetitionArchivesPage({super.key});

  @override
  State<CompetitionArchivesPage> createState() =>
      _CompetitionArchivesPageState();
}

class _CompetitionArchivesPageState extends State<CompetitionArchivesPage> {
  final CompetitionArchiveService _archiveService = CompetitionArchiveService();
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
      final newArchives = await _archiveService.getArchivesWithPagination(
        page: _currentPage,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

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

  Future<void> _toggleArchiveStatus(CompetitionArchive archive) async {
    try {
      await _archiveService.toggleArchiveStatus(archive.id);
      await _refreshArchives();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              archive.isActive ? 'تم إلغاء تفعيل الأرشيف' : 'تم تفعيل الأرشيف',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تغيير حالة الأرشيف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteArchive(CompetitionArchive archive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف الأرشيف "${archive.title}"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _archiveService.deleteArchive(archive.id);
        await _refreshArchives();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الأرشيف بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الأرشيف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildArchiveCard(CompetitionArchive archive) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec titre et statut
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
                    color: archive.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    archive.isActive ? 'نشط' : 'غير نشط',
                    style: const TextStyle(
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
              maxLines: 2,
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
            const SizedBox(height: 8),

            // Contenu multimédia
            if (archive.media.isNotEmpty) ...[
              Row(
                children: [
                  if (archive.media.any(
                    (m) => m.type.toString().contains('video'),
                  )) ...[
                    Icon(Icons.video_library, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 4),
                    Text(
                      'فيديو (${archive.media.where((m) => m.type.toString().contains('video')).length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (archive.media.any(
                    (m) => m.type.toString().contains('image'),
                  )) ...[
                    Icon(Icons.image, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      'صورة (${archive.media.where((m) => m.type.toString().contains('image')).length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _toggleArchiveStatus(archive),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          archive.isActive ? Colors.orange : Colors.green,
                    ),
                    child: Icon(
                      archive.isActive
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => context.push(
                          '/admin/archives/detail/${archive.id}',
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                    child: const Icon(Icons.info_outline, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () =>
                            context.push('/admin/archives/edit/${archive.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                    child: const Icon(Icons.edit, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteArchive(archive),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Icon(Icons.delete, size: 20),
                  ),
                ),
              ],
            ),
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
                          'لا توجد أرشيفات',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/archives/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
