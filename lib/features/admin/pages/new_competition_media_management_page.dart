import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';

class NewCompetitionMediaManagementPage extends StatefulWidget {
  final String versionId;

  const NewCompetitionMediaManagementPage({super.key, required this.versionId});

  @override
  State<NewCompetitionMediaManagementPage> createState() =>
      _NewCompetitionMediaManagementPageState();
}

class _NewCompetitionMediaManagementPageState
    extends State<NewCompetitionMediaManagementPage> {
  final ArchiveMediaService _mediaService = ArchiveMediaService();

  List<ArchiveMedia> _allMedia = [];
  List<ArchiveMedia> _filteredMedia = [];
  bool _isLoading = true;
  String _selectedTypeFilter = 'all';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCompetitionMedia();
  }

  Future<void> _loadCompetitionMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final media = await _mediaService.getMediaByCompetitionVersion(
        widget.versionId,
      );
      setState(() {
        _allMedia = media;
        _applyFilters();
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

  void _applyFilters() {
    setState(() {
      _filteredMedia =
          _allMedia.where((media) {
            bool typeMatch = true;
            bool statusMatch = true;

            // Filtre par type
            if (_selectedTypeFilter != 'all') {
              if (_selectedTypeFilter == 'video') {
                typeMatch = media.type.toString().contains('video');
              } else if (_selectedTypeFilter == 'image') {
                typeMatch = media.type.toString().contains('image');
              }
            }

            // Filtre par statut
            if (_selectedStatusFilter != 'all') {
              if (_selectedStatusFilter == 'active') {
                statusMatch = media.isActive;
              } else if (_selectedStatusFilter == 'inactive') {
                statusMatch = !media.isActive;
              }
            }

            return typeMatch && statusMatch;
          }).toList();
    });
  }

  Future<void> _toggleMediaStatus(ArchiveMedia media) async {
    try {
      final updatedMedia = await _mediaService.toggleMediaStatus(media.id);

      setState(() {
        final index = _allMedia.indexWhere((m) => m.id == media.id);
        if (index != -1) {
          _allMedia[index] = updatedMedia;
          _applyFilters();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedMedia.isActive
                  ? 'تم تفعيل الأرشيف'
                  : 'تم إلغاء تفعيل الأرشيف',
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

  void _editMedia(ArchiveMedia media) {
    context.push('/admin/media/edit', extra: media).then((result) {
      if (result == true) {
        _loadCompetitionMedia();
      }
    });
  }

  void _addNewMedia() {
    context.push('/admin/archives/add/${widget.versionId}').then((result) {
      if (result == true) {
        _loadCompetitionMedia();
      }
    });
  }

  Future<void> _deleteMedia(ArchiveMedia media) async {
    final confirmed = await ConfirmationService.showDeleteConfirmation(
      context,
      title: 'تأكيد حذف الميديا',
      message:
          'هل أنت متأكد من حذف هذا الميديا؟\n\nهذا الإجراء لا يمكن التراجع عنه.',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _mediaService.deleteMedia(media.id);
        setState(() {
          _allMedia.removeWhere((m) => m.id == media.id);
          _applyFilters();
        });

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

  Future<void> _launchVideo(String url) async {
    try {
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
                InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 64),
                        ),
                      );
                    },
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

  Widget _buildFilterButton(String label, String value, String currentValue) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        if (value == _selectedTypeFilter) {
          setState(() {
            _selectedTypeFilter = 'all';
          });
        } else if (value == _selectedStatusFilter) {
          setState(() {
            _selectedStatusFilter = 'all';
          });
        } else {
          if (['video', 'image'].contains(value)) {
            setState(() {
              _selectedTypeFilter = value;
              _selectedStatusFilter = 'all';
            });
          } else if (['active', 'inactive'].contains(value)) {
            setState(() {
              _selectedStatusFilter = value;
              _selectedTypeFilter = 'all';
            });
          }
        }
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(ArchiveMedia media) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Stack(
        children: [
          // Contenu principal
          InkWell(
            onTap: () {
              if (media.type.toString().contains('video')) {
                if (media.url.isNotEmpty) {
                  _launchVideo(media.url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('خطأ: رابط الفيديو غير متوفر'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                _showImageDialog(media.url, media.title);
              }
            },
            child:
                media.type.toString().contains('video')
                    ? // Vidéo : fond rouge avec titre en bas
                    Container(
                      color: Colors.red[600],
                      child: Column(
                        children: [
                          // Zone principale avec icône de lecture
                          Expanded(
                            child: Container(
                              color: Colors.red[600],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_filled,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'فيديو',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Titre en bas
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              media.title != null && media.title!.isNotEmpty
                                  ? media.title!
                                  : 'فيديو ${media.order}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                    : // Image : expansion complète sans titre
                    Image.network(
                      media.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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

          // Badge de statut
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: media.isActive ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                media.isActive ? 'نشط' : 'غير نشط',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Menu d'actions
          Positioned(
            top: 8,
            right: 8,
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.black54,
                  size: 16,
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editMedia(media);
                    break;
                  case 'toggle_status':
                    _toggleMediaStatus(media);
                    break;
                  case 'delete':
                    _deleteMedia(media);
                    break;
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                final permissionService = PermissionService();

                // Option d'édition - disponible pour tous les admins
                items.add(
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                );

                // Option de changement de statut - disponible pour tous les admins
                items.add(
                  PopupMenuItem<String>(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(
                          media.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: media.isActive ? Colors.orange : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(media.isActive ? 'إلغاء التفعيل' : 'تفعيل'),
                      ],
                    ),
                  ),
                );

                // Option de suppression - seulement pour Super Admin
                if (permissionService.canDelete()) {
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                    ),
                  );
                }

                return items;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأرشيف'),
        actions: [
          IconButton(
            onPressed: _addNewMedia,
            icon: const Icon(Icons.add),
            tooltip: 'إضافة أرشيف جديدة',
          ),
          IconButton(
            onPressed: _loadCompetitionMedia,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Statistiques
                Row(
                  children: [
                    Icon(Icons.perm_media, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'إجمالي: ${_allMedia.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'نشط: ${_allMedia.where((m) => m.isActive).length}',
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.cancel, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 4),
                    Text(
                      'غير نشط: ${_allMedia.where((m) => !m.isActive).length}',
                      style: TextStyle(fontSize: 12, color: Colors.red[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Boutons de filtre
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('الكل', 'all', _selectedTypeFilter),
                      const SizedBox(width: 8),
                      _buildFilterButton(
                        'فيديوهات',
                        'video',
                        _selectedTypeFilter,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterButton('صور', 'image', _selectedTypeFilter),
                      const SizedBox(width: 8),
                      _buildFilterButton(
                        'نشط',
                        'active',
                        _selectedStatusFilter,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterButton(
                        'غير نشط',
                        'inactive',
                        _selectedStatusFilter,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grille des médias
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMedia.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.perm_media_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد أرشيف',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: _filteredMedia.length,
                      itemBuilder: (context, index) {
                        return _buildMediaCard(_filteredMedia[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
