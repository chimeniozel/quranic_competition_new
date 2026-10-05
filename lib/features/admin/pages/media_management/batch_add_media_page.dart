import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../core/services/archive_media_service.dart';
import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/file_permission_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../models/archive_media.dart';
import '../../../../models/competition_version.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class BatchAddMediaPage extends StatefulWidget {
  const BatchAddMediaPage({super.key});

  @override
  State<BatchAddMediaPage> createState() => _BatchAddMediaPageState();
}

class _BatchAddMediaPageState extends State<BatchAddMediaPage> {
  final _formKey = GlobalKey<FormState>();
  final ArchiveMediaService _mediaService = ArchiveMediaService();
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final ImagePicker _imagePicker = ImagePicker();
  final FilePermissionService _permissionService = FilePermissionService();
  final PermissionService _permissionCheckService = PermissionService();

  List<CompetitionVersion> _versions = [];
  CompetitionVersion? _selectedVersion;
  List<MediaItem> _mediaItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
    // Ajouter un élément par défaut
    _addMediaItem();
  }

  Future<void> _loadVersions() async {
    try {
      final versions = await _versionService.fetchVersions();
      setState(() {
        _versions = versions;
        if (versions.isNotEmpty) {
          _selectedVersion = versions.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المسابقات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _addMediaItem() {
    setState(() {
      _mediaItems.add(
        MediaItem(
          type: MediaType.image,
          url: '',
          title: '',
          order: _mediaItems.length + 1,
        ),
      );
    });
  }

  void _removeMediaItem(int index) {
    if (_mediaItems.length > 1) {
      setState(() {
        _mediaItems.removeAt(index);
        // Réorganiser les ordres
        for (int i = 0; i < _mediaItems.length; i++) {
          _mediaItems[i] = _mediaItems[i].copyWith(order: i + 1);
        }
      });
    }
  }

  // Méthode pour collecter toutes les images sélectionnées
  List<File> _getAllSelectedImages() {
    List<File> allImages = [];
    for (final item in _mediaItems) {
      if (item.type == MediaType.image &&
          item.selectedFiles != null &&
          item.selectedFiles!.isNotEmpty) {
        allImages.addAll(item.selectedFiles!);
      }
    }
    return allImages;
  }

  Future<void> _pickImagesFromGallery(int index) async {
    // Demander la permission avant de charger les images
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission) {
      return; // L'utilisateur n'a pas accordé la permission
    }

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          // Ajouter les nouvelles images aux précédentes
          final currentFiles = _mediaItems[index].selectedFiles ?? <File>[];
          final newFiles = images.map((file) => File(file.path)).toList();
          final allFiles = [...currentFiles, ...newFiles];

          _mediaItems[index] = _mediaItems[index].copyWith(
            selectedFiles: allFiles,
            url: '', // Réinitialiser l'URL
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصور: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _removeImageFromMedia(int mediaIndex, int imageIndex) {
    setState(() {
      final currentFiles = _mediaItems[mediaIndex].selectedFiles ?? <File>[];
      currentFiles.removeAt(imageIndex);
      _mediaItems[mediaIndex] = _mediaItems[mediaIndex].copyWith(
        selectedFiles: currentFiles.isEmpty ? null : currentFiles,
      );
    });
  }

  void _removeImageFromGlobalGallery(int globalIndex) {
    setState(() {
      int currentIndex = 0;
      for (int mediaIndex = 0; mediaIndex < _mediaItems.length; mediaIndex++) {
        final item = _mediaItems[mediaIndex];
        if (item.type == MediaType.image &&
            item.selectedFiles != null &&
            item.selectedFiles!.isNotEmpty) {
          for (
            int imageIndex = 0;
            imageIndex < item.selectedFiles!.length;
            imageIndex++
          ) {
            if (currentIndex == globalIndex) {
              // Trouvé l'image à supprimer
              final currentFiles = item.selectedFiles!;
              currentFiles.removeAt(imageIndex);
              _mediaItems[mediaIndex] = item.copyWith(
                selectedFiles: currentFiles.isEmpty ? null : currentFiles,
              );
              return;
            }
            currentIndex++;
          }
        }
      }
    });
  }

  Future<void> _saveAllMedia() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier الصلاحيات
    final canModify = await _permissionCheckService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية إضافة الوسائط'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار النسخة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int createdImages = 0;
      int createdVideos = 0;

      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];

        // Pour les images : créer un média pour chaque image sélectionnée
        if (item.type == MediaType.image) {
          if (item.selectedFiles != null && item.selectedFiles!.isNotEmpty) {
            // Créer un média pour chaque image
            for (int j = 0; j < item.selectedFiles!.length; j++) {
              final imageFile = item.selectedFiles![j];
              final fileName =
                  'archive_media_${DateTime.now().millisecondsSinceEpoch}_${i + 1}_${j + 1}.jpg';

              final finalUrl = await _mediaService.uploadImageToStorage(
                imageFile,
                fileName,
              );

              // Créer le média pour cette image
              await _mediaService.createMedia(
                versionId: _selectedVersion!.id,
                type: item.type,
                url: finalUrl,
                title: null,
                description: '',
                order: item.order + j, // Ordre différent pour chaque image
              );

              successCount++;
              createdImages++;
            }
          } else {
            throw Exception('يرجى اختيار صورة للأرشيف ${i + 1}');
          }
        }
        // Pour les vidéos : utiliser l'URL fournie
        else if (item.type == MediaType.video) {
          final finalUrl = item.url;
          if (finalUrl.isEmpty) {
            throw Exception('يرجى إدخال رابط الفيديو للأرشيف ${i + 1}');
          }

          // Créer le média pour la vidéo
          await _mediaService.createMedia(
            versionId: _selectedVersion!.id,
            type: item.type,
            url: finalUrl,
            title: item.title,
            description: '',
            order: item.order,
          );

          successCount++;
          createdVideos++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء $successCount أرشيف بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Notification publique: إنشاء أرشيف صور/فيديو
        try {
          final push = PushNotificationService();
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          await push.sendNotification(
            title: '📦 تمت إضافة أرشيف للنسخة',
            body:
                'تمت إضافة ${createdImages > 0 ? '$createdImages صورة' : ''}${createdImages > 0 && createdVideos > 0 ? ' و ' : ''}${createdVideos > 0 ? '$createdVideos فيديو' : ''} في نسخة "${_selectedVersion!.name}"',
            type: 'info',
            payload: jsonEncode({
              'type': 'archive_media_created',
              'version_id': _selectedVersion!.id,
              'version_name': _selectedVersion!.name,
              'images': createdImages,
              'videos': createdVideos,
              'created_by': currentUserId,
            }),
            userId: null,
          );
        } catch (_) {}
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الأرشيف: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'إضافة أرشيف',
        actions: [
          PrimaryButton(
            onPressed: _isLoading ? null : _saveAllMedia,
            text: _isLoading ? '' : 'حفظ الكل',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () async {
                  await _loadVersions();
                },
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sélection de la compétition
                        ModernCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اختيار النسخة',
                                  style: AppTheme.headingMedium,
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                DropdownButtonFormField<CompetitionVersion>(
                                  value: _selectedVersion,
                                  decoration: InputDecoration(
                                    labelText: 'النسخة',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.emoji_events_rounded,
                                    ),
                                  ),
                                  items:
                                      _versions.map((version) {
                                        return DropdownMenuItem<
                                          CompetitionVersion
                                        >(
                                          value: version,
                                          child: Text(version.name),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedVersion = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'يرجى اختيار النسخة';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),

                        // Aperçu global des images sélectionnées
                        if (_getAllSelectedImages().isNotEmpty) ...[
                          AppSection(
                            margin: const EdgeInsets.only(
                              bottom: AppTheme.spacingM,
                            ),
                            icon: Icons.photo_library_rounded,
                            title:
                                'ألبوم الصور المحددة (${_getAllSelectedImages().length})',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _getAllSelectedImages().length,
                                    itemBuilder: (context, index) {
                                      final imageFile =
                                          _getAllSelectedImages()[index];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          right: AppTheme.spacingS,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          child: Stack(
                                            children: [
                                              Image.file(
                                                imageFile,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Container(
                                                    width: 120,
                                                    height: 120,
                                                    color:
                                                        AppTheme
                                                            .backgroundColor,
                                                    child: Icon(
                                                      Icons.error_rounded,
                                                      color:
                                                          AppTheme.errorColor,
                                                    ),
                                                  );
                                                },
                                              ),
                                              // Bouton de suppression
                                              Positioned(
                                                top: AppTheme.spacingS,
                                                right: AppTheme.spacingS,
                                                child: GestureDetector(
                                                  onTap:
                                                      () =>
                                                          _removeImageFromGlobalGallery(
                                                            index,
                                                          ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppTheme.errorColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppTheme.radiusS,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      color:
                                                          AppTheme.surfaceColor,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Numéro de l'image
                                              Positioned(
                                                bottom: AppTheme.spacingS,
                                                left: AppTheme.spacingS,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .textPrimaryColor
                                                        .withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme.radiusS,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: AppTheme.bodySmall
                                                        .copyWith(
                                                          color:
                                                              AppTheme
                                                                  .surfaceColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                        ],

                        // Liste des médias
                        ModernCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'الأرشيف',
                                      style: AppTheme.headingMedium,
                                    ),
                                    PrimaryButton(
                                      onPressed: _addMediaItem,
                                      text: 'إضافة',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                ...List.generate(_mediaItems.length, (index) {
                                  return _buildMediaItem(index);
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),

                        // Bouton de sauvegarde principal en bas
                        ModernCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed: _isLoading ? null : _saveAllMedia,
                                text:
                                    _isLoading ? 'جاري الحفظ...' : 'حفظ الجميع',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildMediaItem(int index) {
    final item = _mediaItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.dividerColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec type et bouton supprimer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أرشيف ${index + 1}',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_mediaItems.length > 1)
                IconButton(
                  onPressed: () => _removeMediaItem(index),
                  icon: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Sélecteur de type
          DropdownButtonFormField<MediaType>(
            value: item.type,
            decoration: InputDecoration(
              labelText: 'نوع الأرشيف',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
            items: [
              DropdownMenuItem<MediaType>(
                value: MediaType.image,
                child: Row(
                  children: [
                    Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                    const SizedBox(width: AppTheme.spacingS),
                    const Text('صورة'),
                  ],
                ),
              ),
              DropdownMenuItem<MediaType>(
                value: MediaType.video,
                child: Row(
                  children: [
                    Icon(
                      Icons.video_library_rounded,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    const Text('فيديو'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _mediaItems[index] = item.copyWith(
                    type: value,
                    title: value == MediaType.video ? item.title : '',
                  );
                });
              }
            },
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Titre (seulement pour les vidéos)
          if (item.type == MediaType.video) ...[
            TextFormField(
              initialValue: item.title,
              decoration: InputDecoration(
                labelText: 'عنوان الفيديو',
                hintText: 'أدخل عنوان الفيديو',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                prefixIcon: const Icon(Icons.title_rounded),
              ),
              validator: (value) {
                if (item.type == MediaType.video &&
                    (value == null || value.trim().isEmpty)) {
                  return 'عنوان الفيديو مطلوب';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _mediaItems[index] = item.copyWith(title: value);
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],

          // URL pour les vidéos seulement
          if (item.type == MediaType.video) ...[
            TextFormField(
              initialValue: item.url,
              decoration: InputDecoration(
                labelText: 'رابط الفيديو',
                hintText: 'أدخل رابط الفيديو',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                prefixIcon: const Icon(Icons.video_library_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'رابط الفيديو مطلوب';
                }
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasAbsolutePath) {
                  return 'يرجى إدخال رابط صحيح';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _mediaItems[index] = item.copyWith(url: value);
                });
              },
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],

          // Boutons pour les images
          if (item.type == MediaType.image) ...[
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: () => _pickImagesFromGallery(index),
                    text:
                        item.selectedFiles != null &&
                                item.selectedFiles!.isNotEmpty
                            ? 'إضافة المزيد من الصور'
                            : 'اختيار من المعرض',
                  ),
                ),
              ],
            ),
            if (item.selectedFiles != null &&
                item.selectedFiles!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'تم اختيار ${item.selectedFiles!.length} صورة',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Aperçu des images sélectionnées
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.selectedFiles!.length,
                  itemBuilder: (context, imageIndex) {
                    final imageFile = item.selectedFiles![imageIndex];
                    return Container(
                      margin: const EdgeInsets.only(right: AppTheme.spacingS),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            child: Image.file(
                              imageFile,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  color: AppTheme.backgroundColor,
                                  child: Icon(
                                    Icons.error_rounded,
                                    color: AppTheme.errorColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Bouton de suppression
                          Positioned(
                            top: AppTheme.spacingS,
                            right: AppTheme.spacingS,
                            child: GestureDetector(
                              onTap:
                                  () =>
                                      _removeImageFromMedia(index, imageIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusS,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.surfaceColor,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          // Numéro de l'image
                          Positioned(
                            bottom: AppTheme.spacingS,
                            left: AppTheme.spacingS,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.textPrimaryColor.withValues(
                                  alpha: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                              child: Text(
                                '${imageIndex + 1}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.surfaceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class MediaItem {
  final MediaType type;
  final String url;
  final String title;
  final int order;
  final List<File>? selectedFiles;

  MediaItem({
    required this.type,
    required this.url,
    required this.title,
    required this.order,
    this.selectedFiles,
  });

  MediaItem copyWith({
    MediaType? type,
    String? url,
    String? title,
    int? order,
    List<File>? selectedFiles,
  }) {
    return MediaItem(
      type: type ?? this.type,
      url: url ?? this.url,
      title: title ?? this.title,
      order: order ?? this.order,
      selectedFiles: selectedFiles ?? this.selectedFiles,
    );
  }
}
