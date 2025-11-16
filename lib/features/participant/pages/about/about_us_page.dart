import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/about_us_service.dart';
import 'package:quranic_competition/models/about_us.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  final AboutUsService _service = AboutUsService();
  AboutUs? _aboutUs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAboutUs();
  }

  Future<void> _loadAboutUs() async {
    setState(() => _isLoading = true);
    try {
      final aboutUs = await _service.getAboutUs();
      if (mounted) {
        setState(() {
          _aboutUs = aboutUs;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: 'من نحن'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _aboutUs == null
              ? EmptyState(
                icon: Icons.info_outline,
                title: 'لا توجد معلومات',
                subtitle: 'لم يتم إضافة معلومات "من نحن" بعد',
              )
              : ModernPullToRefresh(
                onRefresh: _loadAboutUs,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image de couverture (si disponible)
                      if (_aboutUs!.imageUrl != null) ...[
                        Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            boxShadow: AppTheme.shadowL,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image de couverture
                                Image.network(
                                  _aboutUs!.imageUrl!,
                                  width: double.infinity,
                                  height: 300,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 300,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.primaryColor.withOpacity(
                                              0.3,
                                            ),
                                            AppTheme.secondaryColor.withOpacity(
                                              0.3,
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 300,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.secondaryColor,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(
                                              height: AppTheme.spacingS,
                                            ),
                                            Text(
                                              'فشل تحميل الصورة',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Overlay gradient pour meilleure lisibilité
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusL,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                      ],

                      // Titre - Design moderne
                      ModernCard(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: AppTheme.spacingS,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusS,
                                  ),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  _aboutUs!.title,
                                  style: AppTheme.headingSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingS),

                      // Contenu - Design moderne
                      ModernCard(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Text(
                            _aboutUs!.content,
                            style: AppTheme.bodyMedium.copyWith(
                              height: 1.8,
                              color: AppTheme.textPrimaryColor,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ),

                      // Coordonnées (si disponibles)
                      if (_aboutUs!.email != null ||
                          _aboutUs!.address != null ||
                          _aboutUs!.website != null ||
                          _aboutUs!.whatsappUrl != null ||
                          _aboutUs!.facebookUrl != null ||
                          _aboutUs!.instagramUrl != null ||
                          _aboutUs!.youtubeUrl != null ||
                          _aboutUs!.tiktokUrl != null) ...[
                        const SizedBox(height: AppTheme.spacingS),
                        ModernCard(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.contact_phone,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Text(
                                      'معلومات الاتصال',
                                      style: AppTheme.headingSmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                // Email
                                if (_aboutUs!.email != null) ...[
                                  _buildContactRow(
                                    icon: Icons.email,
                                    label: 'البريد الإلكتروني',
                                    value: _aboutUs!.email!,
                                    onTap: () => _launchEmail(_aboutUs!.email!),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                ],
                                // Adresse
                                if (_aboutUs!.address != null) ...[
                                  _buildContactRow(
                                    icon: Icons.location_on,
                                    label: 'العنوان',
                                    value: _aboutUs!.address!,
                                    onTap:
                                        () =>
                                            _launchAddress(_aboutUs!.address!),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                ],
                                // Réseaux sociaux
                                if (_aboutUs!.whatsappUrl != null ||
                                    _aboutUs!.facebookUrl != null ||
                                    _aboutUs!.instagramUrl != null ||
                                    _aboutUs!.youtubeUrl != null ||
                                    _aboutUs!.tiktokUrl != null ||
                                    _aboutUs!.website != null) ...[
                                  const SizedBox(height: AppTheme.spacingS),
                                  Divider(
                                    color: AppTheme.dividerColor,
                                    height: AppTheme.spacingS,
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppTheme.spacingS,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusS,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.share,
                                          color: AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Text(
                                        'وسائل التواصل الاجتماعي',
                                        style: AppTheme.labelMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  if (_aboutUs!.whatsappUrl != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.whatsapp,
                                      label: 'WhatsApp',
                                      url: _aboutUs!.whatsappUrl!,
                                      backgroundColor: const Color(
                                        0xFF25D366,
                                      ), // Vert WhatsApp
                                      textColor: Colors.white,
                                    ),
                                  if (_aboutUs!.facebookUrl != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.facebook,
                                      label: 'Facebook',
                                      url: _aboutUs!.facebookUrl!,
                                      backgroundColor: const Color(
                                        0xFF1877F2,
                                      ), // Bleu Facebook
                                      textColor: Colors.white,
                                    ),
                                  if (_aboutUs!.instagramUrl != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.instagram,
                                      label: 'Instagram',
                                      url: _aboutUs!.instagramUrl!,
                                      backgroundColor: const Color(
                                        0xFFE4405F,
                                      ), // Rose Instagram
                                      textColor: Colors.white,
                                    ),
                                  if (_aboutUs!.youtubeUrl != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.youtube,
                                      label: 'YouTube',
                                      url: _aboutUs!.youtubeUrl!,
                                      backgroundColor: const Color(
                                        0xFFFF0000,
                                      ), // Rouge YouTube
                                      textColor: Colors.white,
                                    ),
                                  if (_aboutUs!.tiktokUrl != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.tiktok,
                                      label: 'TikTok',
                                      url: _aboutUs!.tiktokUrl!,
                                      backgroundColor: const Color(
                                        0xFF000000,
                                      ), // Noir TikTok
                                      textColor: Colors.white,
                                    ),
                                  if (_aboutUs!.website != null)
                                    _buildSocialMediaButton(
                                      iconData: FontAwesomeIcons.globe,
                                      label: 'الموقع الإلكتروني',
                                      url: _aboutUs!.website!,
                                      backgroundColor: const Color(
                                        0xFF6B46C1,
                                      ), // Couleur primaire de l'app
                                      textColor: Colors.white,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '$label: ',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildSocialMediaButton({
    required IconData iconData,
    required String label,
    required String url,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final defaultBackgroundColor =
        backgroundColor ?? AppTheme.primaryColor.withOpacity(0.1);
    final defaultTextColor = textColor ?? AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: FaIcon(iconData, color: defaultTextColor, size: 20),
        label: Text(label, style: TextStyle(color: defaultTextColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: defaultBackgroundColor,
          foregroundColor: defaultTextColor,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: AppTheme.spacingS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      // S'assurer que l'URL a un schéma
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }

      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يمكن فتح الرابط: $urlString'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الرابط: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    try {
      final uri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يمكن فتح البريد الإلكتروني: $email'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح البريد الإلكتروني: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _launchAddress(String address) async {
    try {
      // Encoder l'adresse pour une recherche Google Maps
      final encodedAddress = Uri.encodeComponent(address);
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يمكن فتح العنوان: $address'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح العنوان: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
