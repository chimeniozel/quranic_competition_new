import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

/// Fenêtre de déconnexion commune à toute l'application.
///
/// Affiche le compte concerné, se déconnecte dans la fenêtre même (indicateur
/// de chargement, appuis répétés ignorés) puis redirige vers [redirectTo].
/// Avec [redirectTo] à null, l'appelant reste sur sa page (accueil
/// participant, accessible sans compte).
///
/// Retourne true si la déconnexion a eu lieu.
Future<bool> confirmAndSignOut(
  BuildContext context, {
  String? redirectTo = '/login',
}) async {
  final signedOut = await showDialog<bool>(
    context: context,
    builder: (_) => const _LogoutDialog(),
  );
  if (signedOut != true || !context.mounted) return false;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('تم تسجيل الخروج بنجاح'),
      backgroundColor: AppTheme.successColor,
      duration: Duration(seconds: 2),
    ),
  );
  if (redirectTo != null) context.go(redirectTo);
  return true;
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog();

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _isSigningOut = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _error = null;
    });
    try {
      await AuthService().signOut();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = 'تعذر تسجيل الخروج. تحقق من الاتصال وحاول مجدداً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final name = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final label = name.isNotEmpty ? name : email;
    final initial = label.isNotEmpty ? label.characters.first : '?';

    return PopScope(
      // Pas de fermeture pendant la déconnexion
      canPop: !_isSigningOut,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 32,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'تسجيل الخروج',
                textAlign: TextAlign.center,
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'هل تريد تسجيل الخروج من هذا الحساب؟',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingM),
                // Compte concerné
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.pageBackgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          initial.toUpperCase(),
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (name.isNotEmpty)
                              Text(
                                name,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                textDirection: TextDirection.ltr,
                                style: AppTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'سيبقى بريدك محفوظاً على هذا الجهاز لتسهيل الدخول القادم.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                AppNotice(
                  text: _error!,
                  color: AppTheme.errorColor,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSigningOut
                              ? null
                              : () => Navigator.of(context).pop(false),
                      style: AppButtonStyles.outlined(
                        AppTheme.textSecondaryColor,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSigningOut ? null : _signOut,
                      style: AppButtonStyles.filled(AppTheme.errorColor),
                      child:
                          _isSigningOut
                              ? const AppButtonLoader()
                              : const FittedBox(child: Text('تسجيل الخروج')),
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
