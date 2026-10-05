import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:quranic_competition/core/services/about_us_service.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/models/about_us.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class AboutUsManagementPage extends StatefulWidget {
  const AboutUsManagementPage({super.key});

  @override
  State<AboutUsManagementPage> createState() => _AboutUsManagementPageState();
}

class _AboutUsManagementPageState extends State<AboutUsManagementPage> {
  final AboutUsService _service = AboutUsService();
  final ImagePicker _imagePicker = ImagePicker();
  final FilePermissionService _permissionService = FilePermissionService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _whatsappUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _facebookUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  final _tiktokUrlController = TextEditingController();

  AboutUs? _aboutUs;
  File? _selectedImageFile;
  String? _imageUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadAboutUs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _whatsappUrlController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _facebookUrlController.dispose();
    _instagramUrlController.dispose();
    _youtubeUrlController.dispose();
    _tiktokUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadAboutUs() async {
    setState(() => _isLoading = true);
    try {
      final aboutUs = await _service.getAboutUs();
      if (mounted) {
        setState(() {
          _aboutUs = aboutUs;
          if (aboutUs != null) {
            _titleController.text = aboutUs.title;
            _contentController.text = aboutUs.content;
            _imageUrl = aboutUs.imageUrl;
            _whatsappUrlController.text = aboutUs.whatsappUrl ?? '';
            _emailController.text = aboutUs.email ?? '';
            _addressController.text = aboutUs.address ?? '';
            _websiteController.text = aboutUs.website ?? '';
            _facebookUrlController.text = aboutUs.facebookUrl ?? '';
            _instagramUrlController.text = aboutUs.instagramUrl ?? '';
            _youtubeUrlController.text = aboutUs.youtubeUrl ?? '';
            _tiktokUrlController.text = aboutUs.tiktokUrl ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المعلومات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _imageUrl =
              null; // Réinitialiser l'URL si une nouvelle image est sélectionnée
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

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      setState(() => _isUploadingImage = true);

      final supabase = Supabase.instance.client;

      // Générer un nom de fichier unique
      final fileName = 'about_us_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'about-us/$fileName';

      // Upload vers Supabase Storage
      await supabase.storage
          .from('images')
          .uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Obtenir l'URL publique
      final imageUrl = supabase.storage.from('images').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      print('❌ Erreur lors de l\'upload de l\'image: $e');
      throw Exception('خطأ في رفع الصورة: $e');
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageFile = null;
      _imageUrl = null;
    });
  }

  Future<void> _saveAboutUs() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _imageUrl;

      // Uploader l'image si une nouvelle image a été sélectionnée
      if (_selectedImageFile != null) {
        // Supprimer l'ancienne image si elle existe
        if (_imageUrl != null) {
          try {
            final uri = Uri.parse(_imageUrl!);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              final filePath = 'about-us/${pathSegments.last}';
              await Supabase.instance.client.storage.from('images').remove([
                filePath,
              ]);
            }
          } catch (e) {
            print('⚠️ Erreur lors de la suppression de l\'ancienne image: $e');
          }
        }

        // Uploader la nouvelle image
        finalImageUrl = await _uploadImageToStorage(_selectedImageFile!);
      }

      await _service.createOrUpdateAboutUs(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageUrl: finalImageUrl,
        whatsappUrl:
            _whatsappUrlController.text.trim().isEmpty
                ? null
                : _whatsappUrlController.text.trim(),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        address:
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        website:
            _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
        facebookUrl:
            _facebookUrlController.text.trim().isEmpty
                ? null
                : _facebookUrlController.text.trim(),
        instagramUrl:
            _instagramUrlController.text.trim().isEmpty
                ? null
                : _instagramUrlController.text.trim(),
        youtubeUrl:
            _youtubeUrlController.text.trim().isEmpty
                ? null
                : _youtubeUrlController.text.trim(),
        tiktokUrl:
            _tiktokUrlController.text.trim().isEmpty
                ? null
                : _tiktokUrlController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _selectedImageFile = null; // Réinitialiser après sauvegarde réussie
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ المعلومات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        await _loadAboutUs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ المعلومات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteAboutUs() async {
    final confirmed = await ModernDialog.showConfirm(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف معلومات "من نحن"؟',
      confirmText: 'حذف',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAboutUs();
      if (mounted) {
        setState(() {
          _aboutUs = null;
          _titleController.clear();
          _contentController.clear();
          _selectedImageFile = null;
          _imageUrl = null;
          _whatsappUrlController.clear();
          _emailController.clear();
          _addressController.clear();
          _websiteController.clear();
          _facebookUrlController.clear();
          _instagramUrlController.clear();
          _youtubeUrlController.clear();
          _tiktokUrlController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المعلومات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف المعلومات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: 'إدارة صفحة "من نحن"'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                // padding: const EdgeInsets.all(AppTheme.spacingS),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titre
                              TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: 'العنوان *',
                                  hintText: 'مثال: من نحن',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const Icon(Icons.title_rounded),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال العنوان';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppTheme.spacingM),

                              // Contenu
                              TextFormField(
                                controller: _contentController,
                                maxLines: 10,
                                decoration: InputDecoration(
                                  labelText: 'المحتوى *',
                                  hintText: 'اكتب محتوى صفحة "من نحن" هنا...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال المحتوى';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Sélection d'image depuis la galerie
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.image_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'الصورة',
                                    style: AppTheme.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Aperçu de l'image de couverture
                              if (_imageUrl != null ||
                                  _selectedImageFile != null)
                                Container(
                                  width: double.infinity,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    boxShadow: AppTheme.shadowM,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        child:
                                            _selectedImageFile != null
                                                ? Image.file(
                                                  _selectedImageFile!,
                                                  width: double.infinity,
                                                  height: 300,
                                                  fit: BoxFit.cover,
                                                )
                                                : Image.network(
                                                  _imageUrl!,
                                                  width: double.infinity,
                                                  height: 300,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return Container(
                                                      height: 300,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            AppTheme
                                                                .primaryGradient,
                                                      ),
                                                      child: const Center(
                                                        child: FaIcon(
                                                          FontAwesomeIcons
                                                              .image,
                                                          size: 48,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                      ),
                                      // Overlay gradient
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          color: Colors.transparent,
                                        ),
                                      ),
                                      // Bouton de suppression
                                      Positioned(
                                        top: AppTheme.spacingS,
                                        right: AppTheme.spacingS,
                                        child: CircleAvatar(
                                          backgroundColor: AppTheme.errorColor
                                              .withOpacity(0.9),
                                          radius: 18,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            onPressed: _removeSelectedImage,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_imageUrl == null &&
                                  _selectedImageFile == null)
                                Container(
                                  width: double.infinity,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.dividerColor,
                                      width: 2,
                                    ),
                                    boxShadow: AppTheme.shadowS,
                                  ),
                                  child: InkWell(
                                    onTap: _pickImageFromGallery,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            AppTheme.spacingL,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.add_circle_rounded,
                                            size: 48,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingS,
                                        ),
                                        Text(
                                          'إضافة صورة الغلاف',
                                          style: AppTheme.headingSmall.copyWith(
                                            color: AppTheme.textPrimaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingXS,
                                        ),
                                        Text(
                                          'اضغط لاختيار صورة من المعرض',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_isUploadingImage)
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: AppTheme.spacingS,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Coordonnées - Section
                              Row(
                                children: [
                                  Icon(
                                    Icons.contact_page_rounded,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'معلومات الاتصال',
                                    style: AppTheme.headingSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  hintText: 'contact@example.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const Icon(Icons.email_rounded),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Adresse
                              TextFormField(
                                controller: _addressController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'العنوان',
                                  hintText: 'العنوان الكامل...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.location_on_rounded,
                                  ),
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Site web
                              TextFormField(
                                controller: _websiteController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'الموقع الإلكتروني',
                                  hintText: 'https://www.example.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.language_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Réseaux sociaux - Section
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.share_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'وسائل التواصل الاجتماعي',
                                    style: AppTheme.headingSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // WhatsApp
                              TextFormField(
                                controller: _whatsappUrlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'رابط قناة WhatsApp',
                                  hintText:
                                      'https://wa.me/... أو https://whatsapp.com/channel/...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    color: Color(0xFF25D366), // WhatsApp green
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Facebook
                              TextFormField(
                                controller: _facebookUrlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'رابط Facebook',
                                  hintText: 'https://www.facebook.com/...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const FaIcon(
                                    FontAwesomeIcons.facebook,
                                    color: Color(0xFF1877F2), // Facebook blue
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Instagram
                              TextFormField(
                                controller: _instagramUrlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'رابط Instagram',
                                  hintText: 'https://www.instagram.com/...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const FaIcon(
                                    FontAwesomeIcons.instagram,
                                    color: Color(0xFFE4405F), // Instagram pink
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // YouTube
                              TextFormField(
                                controller: _youtubeUrlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'رابط قناة YouTube',
                                  hintText:
                                      'https://www.youtube.com/@channel... أو https://youtube.com/channel/...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const FaIcon(
                                    FontAwesomeIcons.youtube,
                                    color: Color(0xFFFF0000), // YouTube red
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // TikTok
                              TextFormField(
                                controller: _tiktokUrlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: 'رابط حساب TikTok',
                                  hintText:
                                      'https://www.tiktok.com/@username...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  prefixIcon: const FaIcon(
                                    FontAwesomeIcons.tiktok,
                                    color: Color(0xFF000000), // TikTok black
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Boutons
                              Row(
                                children: [
                                  Expanded(
                                    child: PrimaryButton(
                                      onPressed:
                                          _isSaving ? null : _saveAboutUs,
                                      text: _isSaving ? 'جاري الحفظ...' : 'حفظ',
                                      icon:
                                          _isSaving
                                              ? null
                                              : FontAwesomeIcons
                                                  .floppyDisk
                                                  .data,
                                    ),
                                  ),
                                  if (_aboutUs != null) ...[
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: SecondaryButton(
                                        onPressed:
                                            _isSaving ? null : _deleteAboutUs,
                                        text: 'حذف',
                                        icon: Icons.delete_rounded,
                                        textColor: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
