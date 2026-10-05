import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String message;
  final String updateUrl;

  const ForceUpdateDialog({
    super.key,
    required this.message,
    required this.updateUrl,
  });

  Future<void> _openStore() async {
    final uri = Uri.parse(updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('❌ Impossible d\'ouvrir l\'URL: $updateUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Empêche la fermeture du dialogue
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'alerte
              Icon(Icons.system_update_rounded, size: 64, color: AppTheme.errorColor),
              SizedBox(height: AppTheme.spacingM),

              // Titre
              Text(
                'تحديث مطلوب',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacingM),

              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacingL),

              // Bouton de mise à jour
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  onPressed: _openStore,
                  text: 'تحديث الآن',
                  icon: Icons.download_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le dialogue de mise à jour forcée
  static void show(BuildContext context, String message, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Empêche la fermeture en cliquant à l'extérieur
      builder:
          (context) =>
              ForceUpdateDialog(message: message, updateUrl: updateUrl),
    );
  }
}
