import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/archive_media_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';

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
  final FilePermissionService _permissionService = FilePermissionService();
  final PermissionService _permissionCheckService = PermissionService();
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
            backgroundColor: AppTheme.errorColor,
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

    // Vérifier الصلاحيات
    final canModify = await _permissionCheckService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل الوسائط'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Vérifier qu'une version est sélectionnée si nécessaire
    if (_needsVersionSelection && _selectedVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نسخة'),
          backgroundColor: AppTheme.errorColor,
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
          content: Text('خطأ: معرف النسخة فارغ'),
          backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.successColor,
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
            backgroundColor: AppTheme.errorColor,
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
    // Demander la permission avant de charger l'image
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission) {
      return; // L'utilisateur n'a pas accordé la permission
    }

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
            backgroundColor: AppTheme.errorColor,
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
      appBar: ModernAppBar(
        title:
            _isCreate
                ? ((_selectedMediaType.toString().contains('video'))
                    ? 'إضافة فيديو جديد'
                    : 'إضافة صورة جديدة')
                : (widget.media.type.toString().contains('video')
                    ? 'تعديل الفيديو'
                    : 'تعديل الصورة'),
        actions: [
          PrimaryButton(
            onPressed: _isLoading ? null : _saveChanges,
            text: _isLoading ? '' : 'حفظ',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () async {
                  // Recharger les versions si nécessaire
                  if (_needsVersionSelection) {
                    await _loadVersions();
                  }
                },
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Aperçu du média
                        ModernCard(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  widget.media.type.toString().contains('video')
                                      ? AppTheme.errorColor.withValues(
                                        alpha: 0.8,
                                      )
                                      : AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            child:
                                widget.media.type.toString().contains('video')
                                    ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_filled_rounded,
                                          size: 64,
                                          color: AppTheme.surfaceColor,
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingS,
                                        ),
                                        Text(
                                          'فيديو',
                                          style: AppTheme.headingSmall.copyWith(
                                            color: AppTheme.surfaceColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Stack(
                                      children: [
                                        // Image affichée (nouvelle ou actuelle)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          child:
                                              _useImageFile &&
                                                      _selectedImageFile != null
                                                  ? Image.file(
                                                    _selectedImageFile!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  )
                                                  : AppNetworkImage(
                                                    url: widget.media.url,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  ),
                                        ),
                                        // Boutons d'action pour les images
                                        Positioned(
                                          top: AppTheme.spacingS,
                                          right: AppTheme.spacingS,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: AppTheme.surfaceColor
                                                      .withValues(alpha: 0.9),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.photo_library_rounded,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                  onPressed:
                                                      _pickImageFromGallery,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                ),
                                              ),
                                              if (_useImageFile &&
                                                  _selectedImageFile !=
                                                      null) ...[
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.surfaceColor
                                                        .withValues(alpha: 0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.close_rounded,
                                                      color:
                                                          AppTheme.errorColor,
                                                    ),
                                                    onPressed:
                                                        _removeSelectedImage,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    constraints:
                                                        const BoxConstraints(
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
                                        if (_useImageFile &&
                                            _selectedImageFile != null)
                                          Positioned(
                                            bottom: AppTheme.spacingS,
                                            left: AppTheme.spacingS,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        AppTheme.spacingS,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.successColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusS,
                                                    ),
                                              ),
                                              child: Text(
                                                'صورة جديدة',
                                                style: AppTheme.bodySmall
                                                    .copyWith(
                                                      color:
                                                          AppTheme.surfaceColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),

                        // Formulaire de modification
                        ModernCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCreate
                                      ? 'إضافة أرشيف جديدة'
                                      : 'تعديل المحتوى',
                                  style: AppTheme.headingMedium,
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                // Sélecteur de version (seulement si nécessaire)
                                if (_needsVersionSelection) ...[
                                  DropdownButtonFormField<CompetitionVersion>(
                                    value: _selectedVersion,
                                    decoration: InputDecoration(
                                      labelText: 'اختيار النسخة',
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
                                        return 'يرجى اختيار نسخة';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                ],

                                // Sélecteur de type de média (seulement en création)
                                if (_isCreate) ...[
                                  DropdownButtonFormField<MediaType>(
                                    value: _selectedMediaType,
                                    decoration: InputDecoration(
                                      labelText: 'نوع الأرشيف',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.category_rounded,
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<MediaType>(
                                        value: MediaType.image,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.image_rounded,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(
                                              width: AppTheme.spacingS,
                                            ),
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
                                            const SizedBox(
                                              width: AppTheme.spacingS,
                                            ),
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
                                  const SizedBox(height: AppTheme.spacingS),
                                ],

                                // Titre (seulement pour les vidéos)
                                if ((_isCreate
                                        ? _selectedMediaType
                                        : widget.media.type)
                                    .toString()
                                    .contains('video'))
                                  TextFormField(
                                    controller: _titleController,
                                    decoration: InputDecoration(
                                      labelText: 'عنوان الفيديو',
                                      hintText: 'أدخل عنوان الفيديو',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.title_rounded,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'عنوان الفيديو مطلوب';
                                      }
                                      return null;
                                    },
                                  ),
                                if ((_isCreate
                                        ? _selectedMediaType
                                        : widget.media.type)
                                    .toString()
                                    .contains('video'))
                                  const SizedBox(height: AppTheme.spacingS),

                                // URL
                                if ((_isCreate
                                            ? _selectedMediaType
                                            : widget.media.type)
                                        .toString()
                                        .contains('image') &&
                                    _useImageFile &&
                                    _selectedImageFile != null) ...[
                                  // Message informatif quand une image de galerie est sélectionnée
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.infoColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: AppTheme.infoColor,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingS,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'تم اختيار صورة من المعرض. الرابط أدناه اختياري.',
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.infoColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      (_isCreate
                                                  ? _selectedMediaType
                                                  : widget.media.type)
                                              .toString()
                                              .contains('video')
                                          ? Icons.video_library_rounded
                                          : Icons.image_rounded,
                                    ),
                                  ),
                                  validator: (value) {
                                    final currentType =
                                        _isCreate
                                            ? _selectedMediaType
                                            : widget.media.type;

                                    // Pour les vidéos, l'URL est toujours requise
                                    if (currentType.toString().contains(
                                      'video',
                                    )) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'رابط الفيديو مطلوب';
                                      }
                                      final uri = Uri.tryParse(value.trim());
                                      if (uri == null || !uri.hasAbsolutePath) {
                                        return 'يرجى إدخال رابط صحيح';
                                      }
                                      return null;
                                    }

                                    // Pour les images, l'URL n'est requise que si aucune image de galerie n'est sélectionnée
                                    if (currentType.toString().contains(
                                      'image',
                                    )) {
                                      if ((value == null ||
                                              value.trim().isEmpty) &&
                                          !(_useImageFile &&
                                              _selectedImageFile != null)) {
                                        return 'يرجى إدخال رابط الصورة أو اختيار صورة من المعرض';
                                      }
                                      if (value != null &&
                                          value.trim().isNotEmpty) {
                                        final uri = Uri.tryParse(value.trim());
                                        if (uri == null ||
                                            !uri.hasAbsolutePath) {
                                          return 'يرجى إدخال رابط صحيح';
                                        }
                                      }
                                      return null;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingS),

                                // Bouton de sélection d'image (seulement pour les images)
                                if ((_isCreate
                                        ? _selectedMediaType
                                        : widget.media.type)
                                    .toString()
                                    .contains('image')) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SecondaryButton(
                                          onPressed: _pickImageFromGallery,
                                          text: 'اختيار صورة من المعرض',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  if (_useImageFile &&
                                      _selectedImageFile != null)
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.successColor
                                              .withValues(alpha: 0.3),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: AppTheme.successColor,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),
                                          Expanded(
                                            child: Text(
                                              'تم اختيار صورة جديدة من المعرض',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppTheme.successColor,
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
                        const SizedBox(height: AppTheme.spacingL),

                        // Boutons d'action
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                onPressed:
                                    _isLoading ? null : () => context.pop(),
                                text: 'إلغاء',
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: PrimaryButton(
                                onPressed: _isLoading ? null : _saveChanges,
                                text: _isLoading ? '' : 'حفظ التغييرات',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
