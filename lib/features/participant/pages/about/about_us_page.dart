import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/about_us_service.dart';
import 'package:quranic_competition/models/about_us.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAboutUs();
  }

  Future<void> _loadAboutUs() async {
    // Au rafraîchissement, le contenu reste affiché pendant le chargement
    setState(() {
      _isLoading = _aboutUs == null;
      _hasError = false;
    });
    try {
      final aboutUs = await _service.getAboutUs();
      if (mounted) {
        setState(() {
          _aboutUs = aboutUs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de « من نحن »: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
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
              : _aboutUs == null && _hasError
              ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'تعذر تحميل المعلومات',
                    subtitle: 'تحقق من الاتصال وحاول مجدداً',
                    action: PrimaryButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: _loadAboutUs,
                    ),
                  ),
                ),
              )
              : _aboutUs == null
              ? EmptyState(
                icon: Icons.info_outline_rounded,
                title: 'لا توجد معلومات',
                subtitle: 'لم يتم إضافة معلومات "من نحن" بعد',
              )
              : ModernPullToRefresh(
                onRefresh: _loadAboutUs,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
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
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
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
                                        gradient: AppTheme.primaryGradient,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported_rounded,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                      ],

                      // Présentation
                      AppSection(
                        icon: Icons.info_rounded,
                        title: _aboutUs!.title,
                        child: SelectableText(
                          _aboutUs!.content,
                          textAlign: TextAlign.justify,
                          style: AppTheme.bodyLarge.copyWith(height: 1.9),
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
                                        Icons.contact_phone_rounded,
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
                                    icon: Icons.email_rounded,
                                    label: 'البريد الإلكتروني',
                                    value: _aboutUs!.email!,
                                    onTap: () => _launchEmail(_aboutUs!.email!),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                ],
                                // Adresse
                                if (_aboutUs!.address != null) ...[
                                  _buildContactRow(
                                    icon: Icons.location_on_rounded,
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
                                          Icons.share_rounded,
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
                                      backgroundColor:
                                          AppTheme
                                              .primaryColor, // Couleur primaire de l'app
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
    required FaIconData iconData,
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
