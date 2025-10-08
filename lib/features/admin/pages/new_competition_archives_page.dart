import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';

class NewCompetitionArchivesPage extends StatefulWidget {
  const NewCompetitionArchivesPage({super.key});

  @override
  State<NewCompetitionArchivesPage> createState() =>
      _NewCompetitionArchivesPageState();
}

class _NewCompetitionArchivesPageState
    extends State<NewCompetitionArchivesPage> {
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();

  List<CompetitionVersion> _versions = [];
  List<ArchiveMedia> _allMedia = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final versions = await _versionService.fetchVersions();
      final allMedia = await _mediaService.getAllMediaSafe();

      setState(() {
        _versions = versions;
        _allMedia = allMedia;
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
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  List<CompetitionVersion> get _filteredVersions {
    if (_searchQuery.isEmpty) {
      return _versions;
    }

    return _versions.where((version) {
      return version.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ArchiveMedia> _getMediaForVersion(String versionId) {
    return _allMedia.where((media) {
      return media.versionId == versionId;
    }).toList();
  }

  int _getActiveMediaCount(String versionId) {
    return _getMediaForVersion(
      versionId,
    ).where((media) => media.isActive).length;
  }

  int _getTotalMediaCount(String versionId) {
    return _getMediaForVersion(versionId).length;
  }

  Widget _buildCompetitionCard(CompetitionVersion version) {
    final mediaForVersion = _getMediaForVersion(version.id);
    final activeMediaCount = _getActiveMediaCount(version.id);
    final totalMediaCount = _getTotalMediaCount(version.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/admin/archives/competition/${version.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec titre de la compétition
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          version.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مسابقة قرآنية',
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
                      color: activeMediaCount > 0 ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      activeMediaCount > 0
                          ? 'نشط ($activeMediaCount)'
                          : 'غير نشط',
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

              // Statistiques des médias
              Row(
                children: [
                  Icon(Icons.perm_media, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'إجمالي الأرشيف: $totalMediaCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'نشط: $activeMediaCount',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.cancel, size: 16, color: Colors.red[600]),
                  const SizedBox(width: 4),
                  Text(
                    'غير نشط: ${totalMediaCount - activeMediaCount}',
                    style: TextStyle(fontSize: 12, color: Colors.red[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Répartition par type
              Row(
                children: [
                  Icon(
                    Icons.video_library,
                    size: 16,
                    color: Colors.purple[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'فيديوهات: ${mediaForVersion.where((m) => m.type.toString().contains('video')).length}',
                    style: TextStyle(fontSize: 12, color: Colors.purple[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.image, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 4),
                  Text(
                    'صور: ${mediaForVersion.where((m) => m.type.toString().contains('image')).length}',
                    style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          () => context.push(
                            '/admin/archives/competition/${version.id}',
                          ),
                      icon: const Icon(Icons.perm_media),
                      label: const Text('إدارة الأرشيف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          () => context.push('/admin/archives/batch-add'),
                      icon: const Icon(Icons.add_box),
                      label: const Text('إضافة أرشيف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف المسابقات'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث في المسابقات...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Liste des compétitions
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredVersions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد مسابقات'
                                : 'لا توجد نتائج للبحث',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshData,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredVersions.length,
                        itemBuilder: (context, index) {
                          return _buildCompetitionCard(
                            _filteredVersions[index],
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/archives/batch-add'),
        tooltip: 'إضافة أرشيف',
        child: const Icon(Icons.add_box),
      ),
    );
  }
}
