import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/models/competition_version.dart';

class EditMediaPage extends StatefulWidget {
  final ArchiveMedia media;

  const EditMediaPage({super.key, required this.media});

  @override
  State<EditMediaPage> createState() => _EditMediaPageState();
}

class _EditMediaPageState extends State<EditMediaPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();

  final ArchiveMediaService _mediaService = ArchiveMediaService();
  final CompetitionVersionService _versionService = CompetitionVersionService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImageFile;
  bool _useImageFile = false;
  List<CompetitionVersion> _versions = [];
  CompetitionVersion? _selectedVersion;
  MediaType _selectedMediaType = MediaType.image; // Type de média sélectionné

  // Déterminer si c'est une création ou une modification
  bool get _isCreate => widget.media.id.isEmpty;
  bool get _needsVersionSelection =>
      widget.media.versionId.isEmpty && _isCreate;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.media.title ?? '';
    _urlController.text = widget.media.url;

    if (_needsVersionSelection) {
      _loadVersions();
    }
  }

  Future<void> _loadVersions() async {
    try {
      final versions = await _versionService.fetchVersions();
      setState(() {
        _versions = versions;
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

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier qu'une version est sélectionnée si nécessaire
    if (_needsVersionSelection && _selectedVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مسابقة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier que versionId n'est pas vide
    final finalVersionId =
        _needsVersionSelection ? _selectedVersion!.id : widget.media.versionId;
    if (finalVersionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: معرف المسابقة فارغ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String finalUrl = _urlController.text.trim();
      String? oldImageUrl;

      final currentType = _isCreate ? _selectedMediaType : widget.media.type;

      // Si c'est une image et qu'un nouveau fichier a été sélectionné depuis la galerie
      if (currentType.toString().contains('image') &&
          _useImageFile &&
          _selectedImageFile != null) {
        // Sauvegarder l'URL de l'ancienne image pour la supprimer plus tard
        oldImageUrl = widget.media.url;

        final fileName =
            'archive_media_${DateTime.now().millisecondsSinceEpoch}_${widget.media.order}.jpg';
        finalUrl = await _mediaService.uploadImageToStorage(
          _selectedImageFile!,
          fileName,
        );
      }
      // Si c'est une image et qu'aucune image de galerie n'est sélectionnée, utiliser l'URL manuelle
      else if (currentType.toString().contains('image')) {
        finalUrl = _urlController.text.trim();
      }

      if (_isCreate) {
        // Créer un nouveau média
        print('🔍 Création de média:');
        print('  - versionId: $finalVersionId');
        print('  - type: ${widget.media.type}');
        print('  - url: $finalUrl');
        print(
          '  - title: ${widget.media.type.toString().contains('video') ? _titleController.text.trim() : null}',
        );
        print('  - order: ${widget.media.order}');

        await _mediaService.createMedia(
          versionId: finalVersionId,
          type: _isCreate ? _selectedMediaType : widget.media.type,
          url: finalUrl,
          title:
              (_isCreate ? _selectedMediaType : widget.media.type)
                      .toString()
                      .contains('video')
                  ? _titleController.text.trim()
                  : null,
          description: '', // Description vide pour ajout rapide
          order: widget.media.order,
        );
      } else {
        // Modifier un média existant
        await _mediaService.updateMedia(
          id: widget.media.id,
          title:
              widget.media.type.toString().contains('video')
                  ? _titleController.text.trim()
                  : null,
          description: '', // Description vide pour ajout rapide
          url: finalUrl,
        );
      }

      // Supprimer l'ancienne image si une nouvelle a été uploadée
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          await _deleteOldImage(oldImageUrl);
        } catch (e) {
          print('Erreur lors de la suppression de l\'ancienne image: $e');
          // Ne pas faire échouer la mise à jour pour cette erreur
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isCreate
                  ? 'تم إنشاء ${(_selectedMediaType.toString().contains('video') ? 'الفيديو' : 'الصورة')} بنجاح'
                  : 'تم تحديث الأرشيف بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true); // Retour avec succès
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الأرشيف: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _useImageFile = true;
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

  void _removeSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _useImageFile = false;
    });
  }

  Future<void> _deleteOldImage(String imageUrl) async {
    try {
      // Extraire le nom du fichier depuis l'URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2) {
        // Pour Supabase Storage, le format est généralement: /storage/v1/object/public/bucket/path
        final fileName = pathSegments.last;
        final filePath = 'archive-media/$fileName';

        // Supprimer le fichier du stockage Supabase
        await Supabase.instance.client.storage.from('images').remove([
          filePath,
        ]);
      }
    } catch (e) {
      print('Erreur lors de la suppression de l\'image: $e');
      throw Exception('Impossible de supprimer l\'ancienne image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCreate
              ? ((_selectedMediaType.toString().contains('video'))
                  ? 'إضافة فيديو جديد'
                  : 'إضافة صورة جديدة')
              : (widget.media.type.toString().contains('video')
                  ? 'تعديل الفيديو'
                  : 'تعديل الصورة'),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('حفظ'),
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
              // Aperçu du média
              Card(
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        widget.media.type.toString().contains('video')
                            ? Colors.red[600]
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      widget.media.type.toString().contains('video')
                          ? const Column(
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
                          )
                          : Stack(
                            children: [
                              // Image affichée (nouvelle ou actuelle)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    _useImageFile && _selectedImageFile != null
                                        ? Image.file(
                                          _selectedImageFile!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                        : Image.network(
                                          widget.media.url,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return const Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 64,
                                              ),
                                            );
                                          },
                                        ),
                              ),
                              // Boutons d'action pour les images
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.photo_library,
                                          color: Colors.blue,
                                        ),
                                        onPressed: _pickImageFromGallery,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ),
                                    if (_useImageFile &&
                                        _selectedImageFile != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: _removeSelectedImage,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Indicateur de nouvelle image
                              if (_useImageFile && _selectedImageFile != null)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'صورة جديدة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 24),

              // Formulaire de modification
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCreate ? 'إضافة أرشيف جديدة' : 'تعديل المحتوى',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Sélecteur de version (seulement si nécessaire)
                      if (_needsVersionSelection) ...[
                        DropdownButtonFormField<CompetitionVersion>(
                          value: _selectedVersion,
                          decoration: const InputDecoration(
                            labelText: 'اختيار المسابقة',
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
                        const SizedBox(height: 16),
                      ],

                      // Sélecteur de type de média (seulement en création)
                      if (_isCreate) ...[
                        DropdownButtonFormField<MediaType>(
                          value: _selectedMediaType,
                          decoration: const InputDecoration(
                            labelText: 'نوع الأرشيف',
                            border: OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.category),
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
                                  const Icon(
                                    Icons.video_library,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('فيديو'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMediaType = value;
                                // Réinitialiser l'image sélectionnée si on change de type
                                if (value == MediaType.video) {
                                  _selectedImageFile = null;
                                  _useImageFile = false;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Titre (seulement pour les vidéos)
                      if ((_isCreate ? _selectedMediaType : widget.media.type)
                          .toString()
                          .contains('video'))
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان الفيديو',
                            hintText: 'أدخل عنوان الفيديو',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'عنوان الفيديو مطلوب';
                            }
                            return null;
                          },
                        ),
                      if ((_isCreate ? _selectedMediaType : widget.media.type)
                          .toString()
                          .contains('video'))
                        const SizedBox(height: 16),

                      // URL
                      if ((_isCreate ? _selectedMediaType : widget.media.type)
                              .toString()
                              .contains('image') &&
                          _useImageFile &&
                          _selectedImageFile != null) ...[
                        // Message informatif quand une image de galerie est sélectionnée
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تم اختيار صورة من المعرض. الرابط أدناه اختياري.',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText:
                              (_isCreate
                                          ? _selectedMediaType
                                          : widget.media.type)
                                      .toString()
                                      .contains('video')
                                  ? 'رابط الفيديو'
                                  : 'رابط الصورة',
                          hintText:
                              (_isCreate
                                          ? _selectedMediaType
                                          : widget.media.type)
                                      .toString()
                                      .contains('video')
                                  ? 'أدخل رابط الفيديو'
                                  : (_useImageFile &&
                                      _selectedImageFile != null)
                                  ? 'رابط اختياري (سيتم استخدام الصورة المحددة)'
                                  : 'أدخل رابط الصورة أو اختر صورة من المعرض',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            (_isCreate ? _selectedMediaType : widget.media.type)
                                    .toString()
                                    .contains('video')
                                ? Icons.video_library
                                : Icons.image,
                          ),
                        ),
                        validator: (value) {
                          final currentType =
                              _isCreate
                                  ? _selectedMediaType
                                  : widget.media.type;

                          // Pour les vidéos, l'URL est toujours requise
                          if (currentType.toString().contains('video')) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رابط الفيديو مطلوب';
                            }
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null || !uri.hasAbsolutePath) {
                              return 'يرجى إدخال رابط صحيح';
                            }
                            return null;
                          }

                          // Pour les images, l'URL n'est requise que si aucune image de galerie n'est sélectionnée
                          if (currentType.toString().contains('image')) {
                            if ((value == null || value.trim().isEmpty) &&
                                !(_useImageFile &&
                                    _selectedImageFile != null)) {
                              return 'يرجى إدخال رابط الصورة أو اختيار صورة من المعرض';
                            }
                            if (value != null && value.trim().isNotEmpty) {
                              final uri = Uri.tryParse(value.trim());
                              if (uri == null || !uri.hasAbsolutePath) {
                                return 'يرجى إدخال رابط صحيح';
                              }
                            }
                            return null;
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bouton de sélection d'image (seulement pour les images)
                      if ((_isCreate ? _selectedMediaType : widget.media.type)
                          .toString()
                          .contains('image')) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImageFromGallery,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('اختيار صورة من المعرض'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_useImageFile && _selectedImageFile != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.green[300]!),
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
                                Expanded(
                                  child: Text(
                                    'تم اختيار صورة جديدة من المعرض',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _removeSelectedImage,
                                  child: const Text('إلغاء'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
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
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('حفظ التغييرات'),
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
}
