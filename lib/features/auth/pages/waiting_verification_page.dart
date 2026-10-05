import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../widgets/auth_layout.dart';

/// Affichée aux comptes (jury, admin) qui attendent d'être vérifiés par
/// l'administration.
class WaitingVerificationPage extends StatefulWidget {
  const WaitingVerificationPage({super.key});

  @override
  State<WaitingVerificationPage> createState() =>
      _WaitingVerificationPageState();
}

class _WaitingVerificationPageState extends State<WaitingVerificationPage> {
  bool _isChecking = false;

  /// Recharge la session puis repasse par la redirection du routeur, qui
  /// envoie vers le bon espace si le compte est désormais vérifié.
  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (e) {
      debugPrint('Erreur lors du rafraîchissement de la session: $e');
    }
    if (!mounted) return;
    setState(() => _isChecking = false);
    context.go('/');
  }

  Future<void> _logout() => confirmAndSignOut(context);

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'انتظار التوثيق',
      heading: 'حسابك قيد المراجعة',
      subtitle: 'سيتم توثيق حسابك من قبل الإدارة قريباً',
      icon: Icons.hourglass_top_rounded,
      automaticallyImplyLeading: false,
      children: [
        const AppNotice(
          text:
              'بعد توثيق حسابك ستتمكن من الوصول إلى لوحتك. '
              'يمكنك التحقق مجدداً في أي وقت.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: AppTheme.spacingM),
        AuthSubmitButton(
          text: 'تحقق مجدداً',
          icon: Icons.refresh_rounded,
          isLoading: _isChecking,
          onPressed: _checkAgain,
        ),
        const SizedBox(height: AppTheme.spacingS),
        OutlinedButton.icon(
          onPressed: _logout,
          style: AppButtonStyles.outlined(AppTheme.errorColor),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}
