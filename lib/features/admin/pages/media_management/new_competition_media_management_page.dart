import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(ArchiveMedia media) {
    return GestureDetector(
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
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenu principal
            media.type.toString().contains('video')
                ? // Vidéo : fond avec icône de lecture
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        size: 48,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'فيديو',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        media.title != null && media.title!.isNotEmpty
                            ? media.title!
                            : 'فيديو ${media.order}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                : // Image
                Image.network(
                  media.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            media.title ?? 'صورة',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),

            // Badge de statut
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      media.isActive
                          ? AppTheme.successColor.withValues(alpha: 0.9)
                          : AppTheme.errorColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  media.isActive ? 'نشط' : 'غير نشط',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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
                    color: AppTheme.surfaceColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: AppTheme.textPrimaryColor,
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

                  // Option d'édition
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                  );

                  // Option de changement de statut
                  items.add(
                    PopupMenuItem<String>(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            media.isActive
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color:
                                media.isActive
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(media.isActive ? 'إلغاء التفعيل' : 'تفعيل'),
                        ],
                      ),
                    ),
                  );

                  // Option de suppression
                  if (permissionService.canDelete()) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: AppTheme.errorColor,
                              size: 16,
                            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'إدارة الأرشيف',
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
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadCompetitionMedia,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      DashboardSection(
                        title: 'إدارة الأرشيف',
                        subtitle: 'إدارة وسائط الأرشيف للمسابقة',
                        child: Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي الوسائط',
                                value: '${_allMedia.length}',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: StatCard(
                                title: 'وسائط نشطة',
                                value:
                                    '${_allMedia.where((m) => m.isActive).length}',
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Filters Section
                      DashboardSection(
                        title: 'التصفية والبحث',
                        subtitle: 'تصفية الوسائط حسب النوع والحالة',
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterButton(
                                'الكل',
                                'all',
                                _selectedTypeFilter,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              _buildFilterButton(
                                'فيديوهات',
                                'video',
                                _selectedTypeFilter,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              _buildFilterButton(
                                'صور',
                                'image',
                                _selectedTypeFilter,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              _buildFilterButton(
                                'نشط',
                                'active',
                                _selectedStatusFilter,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              _buildFilterButton(
                                'غير نشط',
                                'inactive',
                                _selectedStatusFilter,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Media Grid Section
                      DashboardSection(
                        title: 'الوسائط',
                        subtitle: '${_filteredMedia.length} وسيط',
                        child:
                            _filteredMedia.isEmpty
                                ? SizedBox(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.perm_media_outlined,
                                          size: 64,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد وسائط',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'ابدأ بإضافة وسائط جديدة',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: AppTheme.spacingM,
                                        mainAxisSpacing: AppTheme.spacingM,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemCount: _filteredMedia.length,
                                  itemBuilder: (context, index) {
                                    return _buildMediaCard(
                                      _filteredMedia[index],
                                    );
                                  },
                                ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
    );
  }
}
