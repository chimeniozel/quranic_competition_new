import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/auth_initializer.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/core/services/notification_service.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:quranic_competition/app/router.dart' as router;
import 'package:quranic_competition/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handler top-level pour les notifications FCM quand l'app est fermée
/// Cette fonction DOIT être top-level (pas dans une classe) pour fonctionner
/// 
/// IMPORTANT: Quand l'app est fermée, FCM affiche automatiquement la notification
/// si le champ `notification` est présent dans le message. Ce handler est appelé
/// APRÈS que le système ait déjà affiché la notification, donc on ne doit PAS
/// réafficher une notification locale ici pour éviter les doublons.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialiser Firebase dans le isolate background
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('📬 Notification FCM reçue en background (app fermée): ${message.notification?.title}');
  print('📬 Data: ${message.data}');

  // Note: Le système affiche automatiquement la notification grâce au champ `notification`
  // dans le message FCM. On n'a pas besoin d'afficher une notification locale ici.
  // On peut utiliser ce handler pour :
  // - Marquer la notification comme lue dans la base de données
  // - Traiter les données de la notification
  // - Préparer la navigation quand l'utilisateur ouvre l'app depuis la notification
  
  // Ici, on peut traiter la notification (par exemple, marquer comme lue)
  // mais on ne doit PAS afficher de notification locale car le système l'a déjà fait
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase (doit être fait avant Supabase)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé');

    // Enregistrer le handler pour les notifications en background
    // DOIT être fait après l'initialisation de Firebase
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Handler background pour notifications FCM enregistré');
  } catch (e) {
    print('⚠️ Firebase non initialisé (pas de fichier de configuration) : $e');
    print(
      'ℹ️ Les notifications fonctionneront seulement quand l\'app est ouverte',
    );
  }

  await Supabase.initialize(
    url: 'https://slwgmpqpevsodtctpmwz.supabase.co',
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsd2dtcHFwZXZzb2R0Y3RwbXd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0NTYzMjIsImV4cCI6MjA2NjAzMjMyMn0.UpWBLYVgu2-e5I25UTSUewrZiunMTo2xX3Ggb_y4TpI',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialiser les services après que le premier frame soit rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    // Attendre un court délai pour s'assurer que le contexte est prêt
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Initialiser le service de notifications push via Supabase
    try {
      final pushNotificationService = PushNotificationService();
      await pushNotificationService.initialize();
      print('✅ Service de notifications push initialisé');

      // Définir le callback pour gérer les clics sur les notifications locales
      final notificationService = NotificationService();
      notificationService.onNotificationTapped = (String? payload) {
        if (payload != null && payload.contains('version_created')) {
          // Naviguer vers la page d'accueil du participant
          if (mounted) {
            router.appRouter.go('/participant_home_page');
          }
        }
      };
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des notifications push: $e');
    }

    // Demander la permission de stockage
    if (mounted) {
      final filePermissionService = FilePermissionService();
      await filePermissionService.requestStoragePermission(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthInitializer(
      child: MaterialApp.router(
        title: 'مسابقة أهل القرآن',
        routerConfig: router.appRouter,
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: null, // Ne pas affecter les icônes
          cardTheme: CardTheme(color: Colors.white),
          textTheme: ThemeData.light().textTheme.apply(
            fontFamily: "Tajawal",
          ), // Texte en Tajawal
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
