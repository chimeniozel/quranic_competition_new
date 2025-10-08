import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/services/archive_media_service.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/archive_media.dart';
import '../../../models/competition_version.dart';

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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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

    if (_selectedVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مسابقة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;

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
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء $successCount أرشيف بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الأرشيف: $e'),
            backgroundColor: Colors.red,
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
      appBar: AppBar(
        title: const Text('إضافة أرشيف'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveAllMedia,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('حفظ الكل'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélection de la compétition
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اختيار المسابقة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<CompetitionVersion>(
                        value: _selectedVersion,
                        decoration: const InputDecoration(
                          labelText: 'المسابقة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.emoji_events),
                        ),
                        items:
                            _versions.map((version) {
                              return DropdownMenuItem<CompetitionVersion>(
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
                            return 'يرجى اختيار مسابقة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Aperçu global des images sélectionnées
              if (_getAllSelectedImages().isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ألبوم الصور المحددة (${_getAllSelectedImages().length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _getAllSelectedImages().length,
                            itemBuilder: (context, index) {
                              final imageFile = _getAllSelectedImages()[index];
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
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
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.error,
                                              color: Colors.red,
                                            ),
                                          );
                                        },
                                      ),
                                      // Bouton de suppression
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap:
                                              () =>
                                                  _removeImageFromGlobalGallery(
                                                    index,
                                                  ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Numéro de l'image
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
                ),
                const SizedBox(height: 16),
              ],

              // Liste des médias
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الأرشيف',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addMediaItem,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_mediaItems.length, (index) {
                        return _buildMediaItem(index);
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton de sauvegarde principal en bas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveAllMedia,
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'جاري الحفظ...' : 'حفظ الجميع',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(int index) {
    final item = _mediaItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_mediaItems.length > 1)
                IconButton(
                  onPressed: () => _removeMediaItem(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Sélecteur de type
          DropdownButtonFormField<MediaType>(
            value: item.type,
            decoration: const InputDecoration(
              labelText: 'نوع الأرشيف',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<MediaType>(
                value: MediaType.image,
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('صورة'),
                  ],
                ),
              ),
              DropdownMenuItem<MediaType>(
                value: MediaType.video,
                child: Row(
                  children: [
                    const Icon(Icons.video_library, color: Colors.red),
                    const SizedBox(width: 8),
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
          const SizedBox(height: 16),

          // Titre (seulement pour les vidéos)
          if (item.type == MediaType.video) ...[
            TextFormField(
              initialValue: item.title,
              decoration: const InputDecoration(
                labelText: 'عنوان الفيديو',
                hintText: 'أدخل عنوان الفيديو',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
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
            const SizedBox(height: 16),
          ],

          // URL pour les vidéos seulement
          if (item.type == MediaType.video) ...[
            TextFormField(
              initialValue: item.url,
              decoration: const InputDecoration(
                labelText: 'رابط الفيديو',
                hintText: 'أدخل رابط الفيديو',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.video_library),
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
            const SizedBox(height: 16),
          ],

          // Boutons pour les images
          if (item.type == MediaType.image) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImagesFromGallery(index),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(
                      item.selectedFiles != null &&
                              item.selectedFiles!.isNotEmpty
                          ? 'إضافة المزيد من الصور'
                          : 'اختيار من المعرض',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (item.selectedFiles != null &&
                item.selectedFiles!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تم اختيار ${item.selectedFiles!.length} صورة',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Aperçu des images sélectionnées
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.selectedFiles!.length,
                  itemBuilder: (context, imageIndex) {
                    final imageFile = item.selectedFiles![imageIndex];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imageFile,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Bouton de suppression
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap:
                                  () =>
                                      _removeImageFromMedia(index, imageIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          // Numéro de l'image
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${imageIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
