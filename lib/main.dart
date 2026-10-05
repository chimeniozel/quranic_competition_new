import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/auth_initializer.dart';
import 'package:quranic_competition/core/config/supabase_config.dart';
import 'package:quranic_competition/core/services/notification_service.dart';
import 'package:quranic_competition/core/services/notification_navigation.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:quranic_competition/core/services/app_version_service.dart';
import 'package:quranic_competition/core/widgets/force_update_dialog.dart';
import 'package:quranic_competition/app/router.dart' as router;
import 'package:quranic_competition/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print(
    '📬 Notification FCM reçue en background (app fermée): ${message.notification?.title}',
  );
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

  _enableAndroidPhotoPicker();

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

    // iOS : ne PAS laisser le système afficher la notification au premier
    // plan. L'application affiche déjà une notification locale
    // (_handleFCMessage) : les deux ensemble produisaient un doublon.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
  } catch (e) {
    print('⚠️ Firebase non initialisé (pas de fichier de configuration) : $e');
    print(
      'ℹ️ Les notifications fonctionneront seulement quand l\'app est ouverte',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    // `anonKey` accepte aussi bien l'ancienne clé JWT que la nouvelle clé
    // publiable : c'est la même valeur transmise dans l'en-tête `apikey`.
    anonKey: SupabaseConfig.apiKey,
  );
  runApp(const MyApp());
}

/// Active le sélecteur de photos officiel d'Android (Android Photo Picker).
///
/// Il n'exige aucune permission de stockage et n'expose que le fichier choisi,
/// ce qui correspond à la politique Google Play sur les photos et vidéos.
/// Sans cet appel, image_picker retombe sur ACTION_GET_CONTENT.
void _enableAndroidPhotoPicker() {
  if (!Platform.isAndroid) return;

  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
    print('✅ Android Photo Picker activé');
  }
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
    // Attendre un court délai pour s'assurer que le contexte et MaterialApp sont prêts
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Vérifier si une mise à jour est requise
    try {
      final appVersionService = AppVersionService();
      final updateRequired = await appVersionService.isUpdateRequired();

      if (updateRequired && mounted) {
        final updateMessage = await appVersionService.getUpdateMessage();
        final updateUrl = await appVersionService.getUpdateUrl();

        // Afficher le dialogue de mise à jour forcée
        ForceUpdateDialog.show(context, updateMessage, updateUrl);
        return; // Ne pas continuer l'initialisation si une mise à jour est requise
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de la version: $e');
      // Continuer même en cas d'erreur pour ne pas bloquer l'application
    }

    // Initialiser le service de notifications push via Supabase
    try {
      final pushNotificationService = PushNotificationService();
      await pushNotificationService.initialize();
      print('✅ Service de notifications push initialisé');

      // Ouvrir l'écran correspondant au type de la notification tapée
      // (résultats, archive, fوائد, تجويد, فسحة العيد...)
      final notificationService = NotificationService();
      notificationService.onNotificationTapped = (String? payload) {
        if (!mounted) return;
        NotificationNavigation.openFromPayload(payload);
      };
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des notifications push: $e');
    }

    // Aucune demande d'accès aux photos au démarrage.
    //
    // Sur iOS, cet appel affichait la boîte « accès à vos photos » dès la
    // première ouverture, à tous les utilisateurs — y compris aux
    // participants qui ne choisiront jamais d'image. L'autorisation est
    // demandée au moment où elle sert réellement, dans les écrans qui
    // ouvrent le sélecteur (archive, fوائد, règles de tajwid...).
  }

  @override
  Widget build(BuildContext context) {
    return AuthInitializer(
      child: MaterialApp.router(
        title: 'مسابقة أهل القرآن الواتسابية',
        routerConfig: router.appRouter,
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Thème unique de l'application (lib/core/theme/app_theme.dart)
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          // إذا كان child null، عرض loading indicator بدلاً من صفحة سوداء
          if (child == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: Theme.of(context).platform == TargetPlatform.android,
            child: child,
          );
        },
      ),
    );
  }
}
