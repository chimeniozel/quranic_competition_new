import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quranic_competition/core/services/competition_archive_service.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/models/competition_archive.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/archive_media.dart';

class CompetitionArchiveFormPage extends StatefulWidget {
  final String? archiveId;

  const CompetitionArchiveFormPage({super.key, this.archiveId});

  @override
  State<CompetitionArchiveFormPage> createState() =>
      _CompetitionArchiveFormPageState();
}

class _CompetitionArchiveFormPageState
    extends State<CompetitionArchiveFormPage> {
  final CompetitionArchiveService _archiveService = CompetitionArchiveService();
  final ArchiveMediaService _mediaService = ArchiveMediaService();
  final ImagePicker _imagePicker = ImagePicker();

  List<CompetitionVersion> _versions = [];
  CompetitionVersion? _selectedVersion;
  List<MediaItem> _mediaItems = [];
  bool _isLoading = false;
  bool _isEditing = false;
  CompetitionArchive? _existingArchive;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.archiveId != null;
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadVersions();

    if (_isEditing) {
      await _loadArchive();
    } else {
      // Sélectionner la première version par défaut
      if (_versions.isNotEmpty) {
        _selectedVersion = _versions.first;
      }
    }
  }

  Future<void> _loadVersions() async {
    try {
      final versions = await _archiveService.getCompetitionVersions();
      setState(() {
        _versions = versions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الإصدارات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadArchive() async {
    if (widget.archiveId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final archive = await _archiveService.getArchiveById(widget.archiveId!);
      final media = await _mediaService.getMediaByArchiveId(archive.id);

      setState(() {
        _existingArchive = archive;
        _selectedVersion = _versions.firstWhere(
          (v) => v.id == archive.versionId,
          orElse: () => _versions.first,
        );
        _mediaItems = media.map((m) => MediaItem.fromArchiveMedia(m)).toList();
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
        context.pop();
      }
    }
  }

  void _addVideoMedia() {
    setState(() {
      _mediaItems.add(
        MediaItem(
          type: MediaType.video,
          url: '',
          title: '',
          description: '',
          order: _mediaItems.length + 1,
        ),
      );
    });
  }

  void _addImageMedia() {
    setState(() {
      _mediaItems.add(
        MediaItem(
          type: MediaType.image,
          url: '',
          title: '',
          description: '',
          order: _mediaItems.length + 1,
          imageFile: null,
        ),
      );
    });
  }

  Future<void> _pickImageForMedia(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _mediaItems[index] = _mediaItems[index].copyWith(
            imageFile: File(image.path),
            url: '', // Clear URL when file is selected
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
      // Réorganiser les ordres
      for (int i = 0; i < _mediaItems.length; i++) {
        _mediaItems[i] = _mediaItems[i].copyWith(order: i + 1);
      }
    });
  }

  void _moveMediaUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _mediaItems.removeAt(index);
        _mediaItems.insert(index - 1, item);
        // Réorganiser les ordres
        for (int i = 0; i < _mediaItems.length; i++) {
          _mediaItems[i] = _mediaItems[i].copyWith(order: i + 1);
        }
      });
    }
  }

  void _moveMediaDown(int index) {
    if (index < _mediaItems.length - 1) {
      setState(() {
        final item = _mediaItems.removeAt(index);
        _mediaItems.insert(index + 1, item);
        // Réorganiser les ordres
        for (int i = 0; i < _mediaItems.length; i++) {
          _mediaItems[i] = _mediaItems[i].copyWith(order: i + 1);
        }
      });
    }
  }

  bool _isValidYouTubeUrl(String url) {
    final youtubeRegex = RegExp(
      r'^https?://(www\.)?(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)[\w-]+',
    );
    return youtubeRegex.hasMatch(url);
  }

  Future<void> _saveArchive() async {
    if (_selectedVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار إصدار المسابقة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation des médias
    for (int i = 0; i < _mediaItems.length; i++) {
      final media = _mediaItems[i];
      if (media.type == MediaType.video) {
        if (media.url.isEmpty || !_isValidYouTubeUrl(media.url)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('يرجى إدخال رابط يوتيوب صحيح للميديا ${i + 1}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else if (media.type == MediaType.image) {
        if (media.url.isEmpty && media.imageFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'يرجى إدخال رابط صورة أو اختيار صورة للميديا ${i + 1}',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      CompetitionArchive archive;

      if (_isEditing && _existingArchive != null) {
        // Mise à jour
        archive = await _archiveService.updateArchive(
          id: _existingArchive!.id,
          versionId: _selectedVersion!.id,
          title: 'أرشيف ${_selectedVersion!.name}',
          description: 'أرشيف المسابقة',
          eventDate: DateTime.now(),
        );
      } else {
        // Création
        archive = await _archiveService.createArchive(
          versionId: _selectedVersion!.id,
          title: 'أرشيف ${_selectedVersion!.name}',
          description: 'أرشيف المسابقة',
          eventDate: DateTime.now(),
        );
      }

      // Gérer les médias
      if (_isEditing) {
        // Supprimer les anciens médias
        await _mediaService.deleteAllMediaByArchiveId(archive.id);
      }

      // Créer les nouveaux médias
      if (_mediaItems.isNotEmpty) {
        final List<Map<String, dynamic>> mediaData = [];

        for (final mediaItem in _mediaItems) {
          String url = mediaItem.url;

          // Upload de l'image si nécessaire
          if (mediaItem.type == MediaType.image &&
              mediaItem.imageFile != null) {
            final fileName =
                'archive_media_${DateTime.now().millisecondsSinceEpoch}_${mediaItem.order}.jpg';
            url = await _mediaService.uploadImageToStorage(
              mediaItem.imageFile!,
              fileName,
            );
          }

          mediaData.add({
            'type': mediaItem.type.name,
            'url': url,
            'title': '',
            'description': '',
            'order': mediaItem.order,
          });
        }

        await _mediaService.createMultipleMedia(
          archiveId: archive.id,
          mediaData: mediaData,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم التحديث بنجاح' : 'تم الإنشاء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الأرشيف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMediaItem(int index) {
    final media = _mediaItems[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec type et actions
            Row(
              children: [
                Icon(
                  media.type == MediaType.video
                      ? Icons.video_library
                      : Icons.image,
                  color:
                      media.type == MediaType.video ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'ميديا ${index + 1} - ${media.type == MediaType.video ? 'فيديو' : 'صورة'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: index > 0 ? () => _moveMediaUp(index) : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  onPressed:
                      index < _mediaItems.length - 1
                          ? () => _moveMediaDown(index)
                          : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  onPressed: () => _removeMedia(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL ou sélection d'image
            if (media.type == MediaType.video) ...[
              TextFormField(
                initialValue: media.url,
                decoration: const InputDecoration(
                  labelText: 'رابط الفيديو (YouTube)',
                  border: OutlineInputBorder(),
                  hintText: 'https://www.youtube.com/watch?v=...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رابط الفيديو';
                  }
                  if (!_isValidYouTubeUrl(value.trim())) {
                    return 'يرجى إدخال رابط يوتيوب صحيح';
                  }
                  return null;
                },
                onChanged: (value) {
                  _mediaItems[index] = media.copyWith(url: value);
                },
              ),
            ] else ...[
              if (media.imageFile != null) ...[
                // Aperçu de l'image sélectionnée
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(media.imageFile!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImageForMedia(index),
                        icon: const Icon(Icons.edit),
                        label: const Text('تغيير الصورة'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _mediaItems[index] = media.copyWith(
                              imageFile: null,
                              url: '',
                            );
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'حذف الصورة',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Bouton pour sélectionner une image
                OutlinedButton.icon(
                  onPressed: () => _pickImageForMedia(index),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('اختيار صورة من المعرض'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أو',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: media.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط الصورة',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/image.jpg',
                  ),
                  onChanged: (value) {
                    _mediaItems[index] = media.copyWith(url: value);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الأرشيف' : 'إضافة أرشيف'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body:
          _isLoading && _isEditing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélection de la version
                    DropdownButtonFormField<CompetitionVersion>(
                      value: _selectedVersion,
                      decoration: const InputDecoration(
                        labelText: 'إصدار المسابقة',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _versions.map((version) {
                            return DropdownMenuItem(
                              value: version,
                              child: Text(version.name),
                            );
                          }).toList(),
                      onChanged: (version) {
                        setState(() {
                          _selectedVersion = version;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 24),

                    // Section des médias
                    Row(
                      children: [
                        Text(
                          'الميديا',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _addVideoMedia,
                          icon: const Icon(Icons.video_library),
                          label: const Text('إضافة فيديو'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _addImageMedia,
                          icon: const Icon(Icons.image),
                          label: const Text('إضافة صورة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Liste des médias
                    if (_mediaItems.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'لا توجد ميديا. اضغط على "إضافة فيديو" أو "إضافة صورة"',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...List.generate(
                        _mediaItems.length,
                        (index) => _buildMediaItem(index),
                      ),

                    const SizedBox(height: 24),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => context.pop(),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveArchive,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(_isEditing ? 'تحديث' : 'إنشاء'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}

// Classe helper pour gérer les médias dans le formulaire
class MediaItem {
  final MediaType type;
  final String url;
  final String title;
  final String description;
  final int order;
  final File? imageFile;

  const MediaItem({
    required this.type,
    required this.url,
    required this.title,
    required this.description,
    required this.order,
    this.imageFile,
  });

  MediaItem copyWith({
    MediaType? type,
    String? url,
    String? title,
    String? description,
    int? order,
    File? imageFile,
  }) {
    return MediaItem(
      type: type ?? this.type,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      imageFile: imageFile ?? this.imageFile,
    );
  }

  static MediaItem fromArchiveMedia(ArchiveMedia media) {
    return MediaItem(
      type: media.type,
      url: media.url,
      title: '',
      description: '',
      order: media.order,
    );
  }
}
