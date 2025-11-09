import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/app/router.dart' as router;

class AuthInitializer extends StatefulWidget {
  final Widget child;

  const AuthInitializer({super.key, required this.child});

  @override
  State<AuthInitializer> createState() => _AuthInitializerState();
}

class _AuthInitializerState extends State<AuthInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
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
    try {
      // Vérifier si l'utilisateur est connecté
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Initialiser les permissions de l'utilisateur connecté
        await AuthService().initializeCurrentUserPermissions();
        debugPrint('✅ Permissions initialisées pour l\'utilisateur connecté');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation de l\'auth: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('ar'),
      );
    }

    return widget.child;
  }
}
