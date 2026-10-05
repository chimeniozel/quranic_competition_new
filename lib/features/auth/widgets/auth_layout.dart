import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';

/// Mise en page commune des pages d'authentification : en-tête dégradé
/// (logo ou icône), carte de formulaire, puis liens de bas de page.
///
/// Le contenu défile toujours : l'ouverture du clavier ne provoque plus de
/// débordement sur les petits écrans.
class AuthLayout extends StatelessWidget {
  final String title;
  final String heading;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final List<Widget> footer;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AuthLayout({
    super.key,
    required this.title,
    required this.heading,
    required this.children,
    this.subtitle,
    this.icon,
    this.footer = const [],
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        children: [
          AppGradientHeader(
            leading: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child:
                  icon != null
                      ? Icon(icon, size: 40, color: AppTheme.primaryColor)
                      : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/logos/logo.png'),
                      ),
            ),
            title: heading,
            subtitle: subtitle,
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: AppTheme.shadowS,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  ...footer,
                ],
                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal des formulaires d'authentification (pleine largeur,
/// indicateur de chargement intégré)
class AuthSubmitButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthSubmitButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: AppButtonStyles.filled(AppTheme.primaryColor),
      icon: isLoading ? const AppButtonLoader() : Icon(icon),
      label: Text(text),
    );
  }
}
