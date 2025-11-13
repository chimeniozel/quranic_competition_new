import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/app/router.dart' as router;

class AuthInitializer extends StatefulWidget {
  final Widget child;

  const AuthInitializer({super.key, required this.child});

  @override
  State<AuthInitializer> createState() => _AuthInitializerState();
}

class _AuthInitializerState extends State<AuthInitializer> {

  @override
  void initState() {
    super.initState();
    // تحميل الصلاحيات في الخلفية بعد عرض الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Écouter les changements d'authentification pour gérer les deep links
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('🔐 Auth state changed: $event');

      // Gérer la réinitialisation de mot de passe
      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        // Naviguer vers la page de réinitialisation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            router.appRouter.go('/reset-password');
          }
        });
      }
    });
  }

  Future<void> _initializeAuth() async {
    // تحميل الصلاحيات في الخلفية بعد عرض الصفحة
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // تحميل الصلاحيات بشكل غير متزامن في الخلفية
        AuthService().initializeCurrentUserPermissions().then((_) {
          // تحميل الصلاحيات مسبقاً في PermissionService
          PermissionService().currentPermissions.then((_) {
            debugPrint('✅ Permissions préchargées pour l\'utilisateur connecté');
          }).catchError((e) {
            debugPrint('⚠️ Erreur lors du préchargement des permissions: $e');
          });
        }).catchError((e) {
          debugPrint('❌ Erreur lors de l\'initialisation des permissions: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation de l\'auth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // عرض الصفحة فوراً دون انتظار
    return widget.child;
  }
}
