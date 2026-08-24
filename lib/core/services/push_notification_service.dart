import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'notification_navigation.dart';
import 'notification_read_store.dart';
import 'notification_service.dart';

/// Service pour envoyer et recevoir des notifications push via Supabase
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final NotificationReadStore _readStore = NotificationReadStore();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  RealtimeChannel? _notificationsChannel;
  bool _isListening = false;
  bool _isFCMInitialized = false;
  String? _deviceId;
  Timer? _iosAPNSRetryTimer;
  bool _isTokenRegistered = false;
  String? _lastRegisteredToken; // Token FCM déjà enregistré
  String?
  _lastRegisteredUserId; // user_id utilisé lors du dernier enregistrement
  /// Clés des notifications déjà affichées (id de la ligne, ou signature du
  /// contenu quand FCM n'envoie pas d'identifiant). Bornée pour ne pas
  /// grossir indéfiniment pendant la session.
  final List<String> _displayedKeys = <String>[];
  static const int _maxDisplayedKeys = 200;

  /// Délai maximal d'une requête liée aux notifications : au-delà, l'écran
  /// affiche une erreur au lieu de tourner indéfiniment.
  static const Duration _requestTimeout = Duration(seconds: 20);
  DateTime? _loginTimestamp; // Timestamp de la dernière connexion

  /// Retourne true si la notification n'a pas encore été affichée, et la
  /// marque comme affichée.
  bool _markAsDisplayed(String key) {
    if (_displayedKeys.contains(key)) return false;

    _displayedKeys.add(key);
    if (_displayedKeys.length > _maxDisplayedKeys) {
      _displayedKeys.removeRange(0, _displayedKeys.length - _maxDisplayedKeys);
    }
    return true;
  }

  bool _alreadyDisplayed(String key) => _displayedKeys.contains(key);

  /// Clé de déduplication : l'identifiant de la notification si disponible,
  /// sinon une signature du contenu. Indispensable car la même notification
  /// arrive à la fois par FCM et par Supabase Realtime.
  String _dedupKey({String? notificationId, String? title, String? body}) {
    if (notificationId != null && notificationId.isNotEmpty) {
      return notificationId;
    }
    return 'content:${title ?? ''}|${body ?? ''}';
  }

  /// Initialise le service et démarre l'écoute des notifications
  Future<void> initialize() async {
    // Initialiser le service de notifications locales
    await _notificationService.initialize();

    // Initialiser FCM si Firebase est disponible
    try {
      await _initializeFCM();
    } catch (e) {
      print('⚠️ FCM non initialisé: $e');
      print(
        'ℹ️ Les notifications fonctionneront seulement quand l\'app est ouverte',
      );
    }

    // Démarrer l'écoute des notifications si l'utilisateur est connecté
    await _startListening();

    // Écouter les changements d'authentification pour redémarrer l'écoute
    // Note: même pour les utilisateurs non connectés, on garde l'écoute active pour les notifications publiques
    // Les notifications antérieures à l'ouverture de session ne doivent pas
    // être ré-affichées : on pose le repère dès le démarrage, et non
    // seulement lors d'une connexion explicite (une session restaurée
    // n'émet pas signedIn).
    _loginTimestamp ??= DateTime.now();

    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        print(
          '🔐 Utilisateur connecté, redémarrage de l\'écoute des notifications',
        );
        // Enregistrer le timestamp de connexion pour ne pas recevoir d'anciennes notifications
        _loginTimestamp = DateTime.now();
        print('📅 Timestamp de connexion enregistré: $_loginTimestamp');
        _restartListening();
        // Réinitialiser les variables pour forcer une mise à jour du token avec le nouvel user_id
        _lastRegisteredToken = null;
        _lastRegisteredUserId = null;
        // Réenregistrer le token FCM avec le nouvel user_id
        if (_isFCMInitialized) {
          _registerFCMToken();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        print(
          '🔓 Utilisateur déconnecté, redémarrage pour les notifications publiques',
        );
        // Redémarrer l'écoute pour les notifications publiques même après déconnexion
        _restartListening();
        // Réinitialiser les variables pour forcer une mise à jour du token sans user_id
        _lastRegisteredToken = null;
        _lastRegisteredUserId = null;
        // Réenregistrer le token FCM sans user_id
        if (_isFCMInitialized) {
          _registerFCMToken();
        }
      }
    });

    // Polling désactivé - Les notifications seront reçues uniquement via Realtime et FCM
    // _startPolling();
  }

  /// Initialise Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    try {
      // Vérifier si Firebase est initialisé
      final firebaseApp = Firebase.app();
      print('✅ Firebase app trouvé: ${firebaseApp.name}');

      // Demander la permission pour les notifications.
      // Sur Android, POST_NOTIFICATIONS a déjà été demandée par
      // NotificationService : on se contente de lire l'état pour éviter une
      // seconde boîte de dialogue.
      final NotificationSettings settings =
          Platform.isAndroid
              ? await _firebaseMessaging.getNotificationSettings()
              : await _firebaseMessaging.requestPermission(
                alert: true,
                announcement: false,
                badge: true,
                carPlay: false,
                criticalAlert: false,
                provisional: false,
                sound: true,
              );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permission de notifications accordée');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('⚠️ Permission de notifications provisoire');
      } else {
        print('❌ Permission de notifications refusée');
        return;
      }

      // Obtenir l'ID de l'appareil
      await _getDeviceId();

      // Configurer les handlers pour les notifications FCM
      _setupFCMHandlers();

      // Marquer FCM comme initialisé AVANT d'enregistrer le token
      // pour que _registerFCMToken() puisse fonctionner
      _isFCMInitialized = true;

      // Sur iOS, le token APNS peut prendre du temps à être disponible
      // On va essayer d'obtenir le token FCM, et s'il échoue, on va le réessayer périodiquement

      // Obtenir et enregistrer le token FCM
      await _registerFCMToken();

      // Sur iOS, si le token n'a pas été obtenu, créer un timer pour réessayer
      if (Platform.isIOS) {
        _startIOSAPNSRetry();
      }

      // Écouter les changements de token FCM
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 Token FCM renouvelé: $newToken');
        _registerFCMToken(newToken: newToken);
      });

      print('✅ FCM initialisé avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation FCM: $e');
      // Si Firebase n'est pas configuré, on continue sans FCM
      _isFCMInitialized = false;
    }
  }

  /// Obtient un identifiant unique pour l'appareil
  Future<void> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else {
        _deviceId = 'unknown';
      }
      print('📱 Device ID: $_deviceId');
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'ID de l\'appareil: $e');
      _deviceId = 'unknown';
    }
  }

  /// Configure les handlers pour les notifications FCM
  void _setupFCMHandlers() {
    // Notification reçue quand l'app est en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        '📬 Notification FCM reçue (foreground): ${message.notification?.title}',
      );
      _handleFCMessage(message);
    });

    // Notification reçue quand l'app est en background et que l'utilisateur clique dessus
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        '📬 Notification FCM ouverte (background): ${message.notification?.title}',
      );
      // Ne pas réafficher la notification, juste gérer la navigation
      _handleFCMessageOpened(message);
    });

    // Vérifier si l'app a été ouverte depuis une notification (app fermée)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print(
          '📬 Notification FCM ouverte (app fermée): ${message.notification?.title}',
        );
        // Ne pas réafficher la notification, juste gérer la navigation
        _handleFCMessageOpened(message);
      }
    });
  }

  /// Enregistre le token FCM dans Supabase
  /// Ne met à jour que si le token ou le user_id a changé
  Future<void> _registerFCMToken({String? newToken}) async {
    print('🔍 _registerFCMToken appelé - newToken: $newToken');
    print('🔍 _isFCMInitialized: $_isFCMInitialized');

    if (!_isFCMInitialized && newToken == null) {
      print('⚠️ FCM non initialisé et aucun token fourni, abandon');
      return;
    }

    try {
      print('🔍 Tentative d\'obtention du token FCM...');

      // Sur iOS, essayer d'obtenir le token APNS d'abord, mais continuer quand même
      if (Platform.isIOS) {
        print('📱 iOS détecté, obtention du token APNS...');
        String? apnsToken = await _firebaseMessaging.getAPNSToken();

        if (apnsToken == null) {
          // Le token APNS peut prendre un peu de temps, attendre et réessayer
          print('⏳ Token APNS non disponible immédiatement, attente...');
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }

        if (apnsToken != null) {
          print('✅ Token APNS obtenu: $apnsToken');
        } else {
          print('⚠️ Token APNS non disponible après attente');
          print('ℹ️ Tentative d\'obtention du token FCM quand même...');
          print('ℹ️ Firebase peut gérer le token APNS en interne');
        }
      }

      // Essayer d'obtenir le token FCM même si le token APNS n'est pas disponible
      // Firebase Messaging peut gérer cela en interne
      print('🔍 Tentative d\'obtention du token FCM...');
      String? token;

      // Sur iOS, essayer plusieurs fois car le token APNS peut prendre du temps
      int maxRetries = Platform.isIOS ? 3 : 1;
      int retryCount = 0;

      while (retryCount < maxRetries && token == null) {
        try {
          token = newToken ?? await _firebaseMessaging.getToken();
          if (token != null) {
            print(
              '✅ Token FCM obtenu avec succès (tentative ${retryCount + 1}/$maxRetries)',
            );
            break;
          }
        } catch (e) {
          print(
            '❌ Erreur lors de l\'obtention du token FCM (tentative ${retryCount + 1}/$maxRetries): $e',
          );

          // Si on est sur iOS et que c'est une erreur APNS, attendre et réessayer
          if (Platform.isIOS &&
              (e.toString().contains('apns') ||
                  e.toString().contains('APNS') ||
                  e.toString().contains('token-not-set'))) {
            if (retryCount < maxRetries - 1) {
              print('⏳ Attente de 2 secondes avant de réessayer...');
              await Future.delayed(const Duration(seconds: 2));
              retryCount++;
              continue; // Réessayer
            } else {
              // Dernière tentative échouée, vérifier si un token existe déjà dans la base
              print(
                '⚠️ Impossible d\'obtenir le token FCM après $maxRetries tentatives',
              );
              print(
                'ℹ️ Vérification si un token existe déjà pour cet appareil...',
              );

              try {
                final deviceId = _deviceId ?? 'unknown';
                final existingTokens = await _supabase
                    .from('fcm_tokens')
                    .select()
                    .eq('device_id', deviceId)
                    .eq('platform', 'ios')
                    .eq('is_active', true)
                    .limit(1);

                if (existingTokens.isNotEmpty) {
                  final existingToken = existingTokens[0];
                  print(
                    '✅ Token FCM existant trouvé pour cet appareil: ${existingToken['fcm_token']?.toString().substring(0, 20)}...',
                  );
                  print(
                    'ℹ️ Le token existant sera utilisé jusqu\'à ce qu\'un nouveau token soit disponible',
                  );
                  _isTokenRegistered = true;
                  _lastRegisteredToken = existingToken['fcm_token'] as String?;
                  _lastRegisteredUserId = existingToken['user_id'] as String?;
                  return; // Pas besoin de continuer, le token existe déjà
                } else {
                  print(
                    'ℹ️ Aucun token existant trouvé. Le timer iOS continuera à réessayer.',
                  );
                  print(
                    'ℹ️ Le token FCM sera obtenu automatiquement quand le token APNS sera disponible',
                  );
                }
              } catch (dbError) {
                print(
                  '⚠️ Erreur lors de la vérification du token existant: $dbError',
                );
              }

              // Le timer iOS va réessayer périodiquement
              return;
            }
          } else {
            // Pour les autres erreurs ou Android, rethrow
            rethrow;
          }
        }
        retryCount++;
      }

      if (token == null) {
        print('⚠️ Token FCM non disponible après toutes les tentatives');
        return;
      }

      print('✅ Token FCM obtenu: $token');
      print('🔍 Longueur du token: ${token.length}');

      final userId = _supabase.auth.currentUser?.id;
      final deviceId = _deviceId ?? 'unknown';
      final platform = Platform.isAndroid ? 'android' : 'ios';

      // Vérifier si le token et le user_id sont identiques aux derniers enregistrés
      if (_lastRegisteredToken == token && _lastRegisteredUserId == userId) {
        print('ℹ️ Token FCM et user_id identiques, pas besoin de mise à jour');
        print('ℹ️ Token déjà enregistré: ${token.substring(0, 20)}...');
        print('ℹ️ user_id: $userId');

        // Vérifier quand même dans la base de données pour s'assurer que c'est toujours actif
        try {
          final existingToken =
              await _supabase
                  .from('fcm_tokens')
                  .select()
                  .eq('fcm_token', token)
                  .maybeSingle();

          if (existingToken != null && existingToken['is_active'] == true) {
            print('✅ Token vérifié dans la base de données, toujours actif');
            _isTokenRegistered = true;
            return; // Pas besoin de mise à jour
          } else {
            print('⚠️ Token trouvé mais inactif, mise à jour nécessaire');
          }
        } catch (e) {
          print('⚠️ Erreur lors de la vérification du token existant: $e');
          print('ℹ️ Continuation avec la mise à jour...');
        }
      }

      print('🔍 Données à enregistrer:');
      print('   - user_id: $userId');
      print('   - device_id: $deviceId');
      print('   - platform: $platform');
      print('   - fcm_token: $token');
      print('   - is_active: true');

      // Préparer les données pour l'enregistrement
      final dataToInsert = {
        'user_id': userId,
        'device_id': deviceId,
        'fcm_token': token,
        'platform': platform,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔍 Tentative d\'enregistrement dans fcm_tokens...');
      print('🔍 Data: $dataToInsert');

      // Enregistrer ou mettre à jour le token dans Supabase
      final result = await _supabase
          .from('fcm_tokens')
          .upsert(dataToInsert, onConflict: 'fcm_token');

      print('✅ Résultat de l\'upsert: $result');
      print('✅ Token FCM enregistré dans Supabase avec succès');

      // Sauvegarder le token et le user_id pour éviter les mises à jour inutiles
      _lastRegisteredToken = token;
      _lastRegisteredUserId = userId;
      _isTokenRegistered = true;

      // Arrêter le timer de retry iOS si actif
      if (Platform.isIOS && _iosAPNSRetryTimer != null) {
        _iosAPNSRetryTimer?.cancel();
        _iosAPNSRetryTimer = null;
        print('✅ Timer iOS arrêté, token enregistré avec succès');
      }

      // Vérifier que le token est bien enregistré
      try {
        final verification =
            await _supabase
                .from('fcm_tokens')
                .select()
                .eq('fcm_token', token)
                .maybeSingle();

        if (verification != null) {
          print('✅ Vérification: Token trouvé dans la table fcm_tokens');
          print('   - ID: ${verification['id']}');
          print('   - user_id: ${verification['user_id']}');
          print('   - device_id: ${verification['device_id']}');
          print('   - is_active: ${verification['is_active']}');
        } else {
          print(
            '⚠️ Vérification: Token NON trouvé dans la table après insertion',
          );
        }
      } catch (verifyError) {
        print('⚠️ Erreur lors de la vérification: $verifyError');
      }
    } catch (e, stackTrace) {
      print('❌ Erreur lors de l\'enregistrement du token FCM: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  /// Gère l'ouverture d'une notification FCM (navigation uniquement, pas d'affichage)
  void _handleFCMessageOpened(RemoteMessage message) {
    try {
      final data = message.data;
      final notificationId = data['notification_id'] as String?;

      // Marquer la notification comme affichée si elle ne l'est pas déjà
      _markAsDisplayed(
        _dedupKey(
          notificationId: notificationId,
          title: message.notification?.title,
          body: message.notification?.body,
        ),
      );

      // Le callback onNotificationTapped ne concerne que les notifications
      // locales : pour une notification FCM affichée par le système, c'est
      // ici qu'il faut ouvrir l'écran correspondant.
      print('📬 Notification FCM ouverte: ${message.notification?.title}');

      // Le type métier (results_published, benefit_created...) est dans le
      // payload JSON ; data['type'] ne porte que la gravité (info/error...).
      NotificationNavigation.openFromPayload(data['payload'] as String?);
    } catch (e) {
      print(
        '❌ Erreur lors du traitement de l\'ouverture de notification FCM: $e',
      );
    }
  }

  /// Gère un message FCM reçu (affichage de notification)
  void _handleFCMessage(RemoteMessage message) {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        // Extraire l'ID de la notification depuis les données
        final notificationId = data['notification_id'] as String?;
        final key = _dedupKey(
          notificationId: notificationId,
          title: notification.title,
          body: notification.body,
        );

        // Éviter les doublons avec Realtime. Quand FCM n'envoie pas
        // notification_id, la clé de repli sur le contenu joue le même rôle.
        if (!_markAsDisplayed(key)) {
          print(
            '⚠️ Notification FCM déjà affichée (via Realtime), ignorée: ${notification.title}',
          );
          return;
        }

        final type = data['type'] as String? ?? 'info';

        print('📬 Notification FCM affichée: ${notification.title}');

        _notificationService.showStyledNotification(
          id:
              (notificationId ?? DateTime.now().toString()).hashCode &
              0x7FFFFFFF,
          title: notification.title ?? 'إشعار جديد',
          body: notification.body ?? '',
          // Payload métier pour la navigation au clic (et non l'identifiant,
          // qui ne permettait de router vers rien).
          payload: (data['payload'] as String?) ?? jsonEncode(data),
          channelName: 'إشعارات التطبيق',
          channelDescription: 'إشعارات من التطبيق',
          importance:
              type == 'error' || type == 'warning'
                  ? Importance.high
                  : Importance.defaultImportance,
          priority:
              type == 'error' || type == 'warning'
                  ? Priority.high
                  : Priority.defaultPriority,
        );
      }
    } catch (e) {
      print('❌ Erreur lors du traitement du message FCM: $e');
    }
  }

  /// Redémarre l'écoute (arrête l'ancienne et démarre une nouvelle)
  Future<void> _restartListening() async {
    stopListening();
    await Future.delayed(const Duration(milliseconds: 500));
    await _startListening();
  }

  /// Démarre l'écoute des notifications en temps réel via Supabase Realtime
  /// Fonctionne même pour les utilisateurs non connectés (participants)
  Future<void> _startListening() async {
    if (_isListening) return;

    final userId = _supabase.auth.currentUser?.id;

    try {
      // Arrêter l'ancien canal s'il existe
      if (_notificationsChannel != null) {
        await _supabase.removeChannel(_notificationsChannel!);
      }

      // Créer un canal Realtime pour écouter les notifications
      // Utiliser un canal unique même pour les utilisateurs non connectés
      final channelName =
          userId != null ? 'notifications_$userId' : 'notifications_public';
      _notificationsChannel = _supabase.channel(channelName);

      // Écouter toutes les nouvelles notifications
      // Le filtrage se fera dans le callback pour vérifier si user_id est NULL ou égal à l'utilisateur actuel
      _notificationsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final notification = payload.newRecord;
              final notificationUserId = notification['user_id'] as String?;
              final notificationId = notification['id'] as String?;

              print('📬 Notification Realtime reçue: ${notification['title']}');

              // Vérifier si cette notification a déjà été affichée (éviter les doublons)
              if (_alreadyDisplayed(
                _dedupKey(
                  notificationId: notificationId,
                  title: notification['title'] as String?,
                  body: notification['body'] as String?,
                ),
              )) {
                print(
                  '⚠️ Notification déjà affichée, ignorée: ${notification['title']}',
                );
                return; // Ignorer si déjà affichée
              }

              // Vérifier si la notification est pour tous (user_id = NULL) ou pour cet utilisateur spécifique
              // Pour les utilisateurs non connectés, on ne reçoit que les notifications générales (user_id = NULL)
              bool shouldDisplay = false;
              final isPublicNotification = notificationUserId == null;

              if (isPublicNotification) {
                // Notification générale (user_id = NULL) - للجميع
                shouldDisplay = true;
              } else if (userId != null && notificationUserId == userId) {
                // Notification spécifique pour cet utilisateur connecté
                shouldDisplay = true;
              }

              // Vérifier si la notification a été créée après la dernière connexion
              // هذا التحقق يطبق على جميع الإشعارات (العامة والمخصصة)
              // لا تصل الإشعارات القديمة (تم إنشاؤها قبل تسجيل الدخول)
              if (shouldDisplay && _loginTimestamp != null) {
                final notificationCreatedAt =
                    notification['created_at'] as String?;
                if (notificationCreatedAt != null) {
                  try {
                    final createdAt = DateTime.parse(notificationCreatedAt);
                    if (createdAt.isBefore(_loginTimestamp!)) {
                      print(
                        '⚠️ Notification ancienne ignorée (créée avant la connexion): ${notification['title']}',
                      );
                      shouldDisplay = false;
                    }
                  } catch (e) {
                    print(
                      '⚠️ Erreur lors du parsing de la date de création: $e',
                    );
                    // En cas d'erreur, afficher quand même pour éviter de perdre des notifications
                  }
                }
              }

              // Afficher la notification seulement si elle est destinée à cet utilisateur
              if (shouldDisplay) {
                // Marquer comme affichée APRÈS avoir vérifié qu'elle doit être affichée
                // et seulement quand elle sera réellement affichée dans _handleNewNotification
                _handleNewNotification(notification);
              } else {
                print(
                  'ℹ️ Notification ignorée (pas pour cet utilisateur): ${notification['title']}',
                );
              }
            },
          )
          .subscribe();

      _isListening = true;
      if (userId != null) {
        print(
          '✅ Écoute des notifications démarrée pour l\'utilisateur: $userId',
        );
      } else {
        print(
          '✅ Écoute des notifications démarrée pour les notifications publiques',
        );
      }
    } catch (e) {
      print('❌ Erreur lors du démarrage de l\'écoute: $e');
      _isListening = false;
    }
  }

  /// Vérifie si une version existe encore dans la base de données
  Future<bool> _isVersionDeleted(String? versionId) async {
    if (versionId == null || versionId.isEmpty) return false;

    try {
      final response =
          await _supabase
              .from('competition_versions')
              .select('id')
              .eq('id', versionId)
              .maybeSingle();

      // Si la version n'existe pas, elle a été supprimée
      return response == null;
    } catch (e) {
      print('⚠️ Erreur lors de la vérification de la version: $e');
      // En cas d'erreur, on considère que la version existe pour éviter de masquer des notifications valides
      return false;
    }
  }

  /// Gère une nouvelle notification reçue
  Future<void> _handleNewNotification(
    Map<String, dynamic> notificationData,
  ) async {
    try {
      final title = notificationData['title'] as String? ?? 'إشعار جديد';
      final body = notificationData['body'] as String? ?? '';
      final type = notificationData['type'] as String? ?? 'info';
      final payload = notificationData['payload'] as String?;
      final notificationId = notificationData['id'] as String?;

      final dedupKey = _dedupKey(
        notificationId: notificationId,
        title: title,
        body: body,
      );

      // Vérifier si cette notification a déjà été affichée (double vérification pour sécurité)
      if (_alreadyDisplayed(dedupKey)) {
        print('⚠️ Notification déjà affichée, ignorée: $title');
        return;
      }

      final currentUserId = _supabase.auth.currentUser?.id;

      // Vérifier si la notification référence une version supprimée
      if (payload != null) {
        try {
          final payloadData = jsonDecode(payload) as Map<String, dynamic>?;

          // Ne pas notifier l'auteur de sa propre publication
          if (currentUserId != null &&
              payloadData != null &&
              payloadData['created_by'] == currentUserId) {
            print(
              'ℹ️ Notification ignorée (créée par cet utilisateur): $title',
            );
            if (notificationId != null) {
              try {
                await markAsRead(notificationId);
              } catch (_) {}
            }
            return;
          }

          if (payloadData != null && payloadData['type'] == 'version_created') {
            final versionId = payloadData['version_id'] as String?;
            if (versionId != null && await _isVersionDeleted(versionId)) {
              print('⚠️ Notification ignorée: version supprimée: $title');
              // Marquer la notification comme lue pour éviter de la réafficher
              if (notificationId != null) {
                try {
                  await markAsRead(notificationId);
                } catch (e) {
                  print(
                    '⚠️ Erreur lors du marquage de la notification comme lue: $e',
                  );
                }
              }
              return;
            }
          }
        } catch (e) {
          // Si le payload n'est pas un JSON valide, continuer normalement
          print('ℹ️ Payload non-JSON ou erreur de parsing: $e');
        }
      }

      print('📬 Nouvelle notification reçue: $title');

      // Marquer comme déjà affichée AVANT de l'afficher pour éviter les doublons
      // (par exemple, si Realtime et FCM reçoivent la même notification)
      _markAsDisplayed(dedupKey);

      // Afficher la notification locale
      await _showLocalNotification(
        title: title,
        body: body,
        type: type,
        payload: payload,
        notificationId: notificationId,
      );

      print('✅ Notification affichée avec succès: $title');
    } catch (e) {
      print('❌ Erreur lors du traitement de la notification: $e');
      // En cas d'erreur, retirer la clé pour permettre une nouvelle tentative
      _displayedKeys.remove(
        _dedupKey(
          notificationId: notificationData['id'] as String?,
          title: notificationData['title'] as String?,
          body: notificationData['body'] as String?,
        ),
      );
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? type,
    String? payload,
    String? notificationId,
  }) async {
    // Générer un ID unique pour la notification locale
    final localId =
        (notificationId ?? DateTime.now().toString()).hashCode & 0x7FFFFFFF;

    // Déterminer l'importance selon le type
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;

    if (type == 'error' || type == 'warning') {
      importance = Importance.high;
      priority = Priority.high;
    } else if (type == 'success') {
      importance = Importance.defaultImportance;
      priority = Priority.defaultPriority;
    }

    await _notificationService.showStyledNotification(
      id: localId,
      title: title,
      body: body,
      payload: payload ?? notificationId,
      channelName: 'إشعارات التطبيق',
      channelDescription: 'إشعارات من التطبيق',
      importance: importance,
      priority: priority,
    );
  }

  /// Envoie une notification à tous les utilisateurs (user_id = NULL)
  /// ou à un utilisateur spécifique
  Future<void> sendNotification({
    required String title,
    required String body,
    String type = 'info',
    String? payload, // Doit être déjà un JSON stringifié
    String? userId, // NULL pour notifier tous les utilisateurs
  }) async {
    try {
      // Si userId est spécifié, vérifier que l'utilisateur existe dans profiles
      if (userId != null && userId.isNotEmpty) {
        final userExists =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('id', userId)
                .maybeSingle();

        if (userExists == null) {
          print(
            '⚠️ L\'utilisateur avec l\'ID $userId n\'existe pas dans profiles. Notification non envoyée.',
          );
          print('⚠️ Titre de la notification: $title');
          return; // Ne pas envoyer l'notification si l'utilisateur n'existe pas
        }

        print('✅ Utilisateur vérifié: $userId existe dans profiles');
      }

      // Construire/augmenter le payload pour inclure le créateur afin de filtrer côté client
      final creatorId = _supabase.auth.currentUser?.id;
      String? payloadValue;
      if (payload != null) {
        try {
          final existing = jsonDecode(payload) as Map<String, dynamic>;
          if (creatorId != null) existing['created_by'] = creatorId;
          payloadValue = jsonEncode(existing);
        } catch (_) {
          // Payload n'est pas un JSON valide, l'encapsuler
          final wrapper = <String, dynamic>{'data': payload};
          if (creatorId != null) wrapper['created_by'] = creatorId;
          payloadValue = jsonEncode(wrapper);
        }
      } else {
        final base = <String, dynamic>{};
        if (creatorId != null) base['created_by'] = creatorId;
        payloadValue = base.isEmpty ? null : jsonEncode(base);
      }

      // Insérer la notification dans la base de données
      await _supabase.from('notifications').insert({
        'title': title,
        'body': body,
        'type': type,
        'payload': payloadValue,
        'user_id': userId,
        'is_read': false,
      });

      print('✅ Notification envoyée dans la base de données: $title');

      // L'envoi des push FCM est déclenché côté serveur : un Database
      // Webhook Supabase appelle la fonction `send_fcm_notification` à chaque
      // INSERT dans `notifications`. Inutile — et fragile — de l'appeler
      // depuis l'appareil de l'expéditeur.
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de la notification: $e');
      rethrow;
    }
  }

  /// Marque une notification comme lue.
  ///
  /// L'état est enregistré **sur l'appareil**. La base n'est mise à jour que
  /// pour une notification personnelle ([ownerUserId] non nul) : une
  /// notification publique est une ligne unique partagée, la marquer lue en
  /// base l'effacerait pour tous les utilisateurs.
  Future<void> markAsRead(String notificationId, {String? ownerUserId}) async {
    await _readStore.markRead(notificationId);

    if (ownerUserId == null || ownerUserId.isEmpty) return;

    try {
      await _supabase.rpc(
        'mark_notification_as_read',
        params: {'notification_id': notificationId},
      );
    } catch (e) {
      print('❌ Erreur lors du marquage de la notification comme lue: $e');
      // Si la fonction RPC n'existe pas, utiliser une mise à jour directe
      try {
        await _supabase
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('id', notificationId);
      } catch (e2) {
        print('❌ Erreur lors de la mise à jour directe: $e2');
      }
    }
  }

  /// Notifications non lues sur cet appareil.
  Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    final notifications = await getRecentNotifications();
    return notifications.where((n) => n['is_read'] != true).toList();
  }

  /// Récupère les notifications récentes (lues et non lues) pour l'écran
  /// « الإشعارات ». Même périmètre que [getUnreadNotifications] : notifications
  /// publiques + celles de l'utilisateur, sur 30 jours, 100 au maximum.
  ///
  /// Contrairement aux autres méthodes, les erreurs sont propagées : l'écran
  /// doit pouvoir distinguer « aucune notification » d'un échec de chargement.
  Future<List<Map<String, dynamic>>> getRecentNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Borne basse : 30 jours, mais jamais avant la première ouverture de
      // l'application sur cet appareil (réinstallation = liste vierge).
      final thirtyDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 30),
      );
      final installedAt = await _readStore.notificationsSince();
      final since =
          installedAt.isAfter(thirtyDaysAgo) ? installedAt : thirtyDaysAgo;

      final query =
          userId != null
              ? _supabase
                  .from('notifications')
                  .select()
                  .or('user_id.is.null,user_id.eq.$userId')
              : _supabase
                  .from('notifications')
                  .select()
                  .isFilter('user_id', null);

      // Un délai maximal évite que l'écran reste indéfiniment sur le
      // chargement quand le réseau ne répond pas.
      final response = await query
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(_requestTimeout);

      final notifications = List<Map<String, dynamic>>.from(response);
      final readIds = await _readStore.readIds();

      // Décoder les payloads une seule fois
      final payloads = <String, Map<String, dynamic>?>{};
      final versionIds = <String>{};
      for (final notification in notifications) {
        final id = notification['id'] as String?;
        if (id == null) continue;

        final payload = notification['payload'] as String?;
        Map<String, dynamic>? data;
        if (payload != null) {
          try {
            data = jsonDecode(payload) as Map<String, dynamic>?;
          } catch (_) {
            // Payload non-JSON : notification conservée telle quelle
          }
        }
        payloads[id] = data;

        if (data?['type'] == 'version_created') {
          final versionId = data?['version_id'] as String?;
          if (versionId != null) versionIds.add(versionId);
        }
      }

      // Versions encore existantes, en UNE requête (et non une par
      // notification, ce qui rendait l'écran interminable).
      final existingVersionIds = await _fetchExistingVersionIds(versionIds);

      final result = <Map<String, dynamic>>[];
      for (final notification in notifications) {
        final id = notification['id'] as String?;
        final data = id == null ? null : payloads[id];

        // Ne pas montrer à l'auteur ses propres publications
        if (userId != null && data?['created_by'] == userId) continue;

        // Ni les notifications renvoyant vers une version supprimée
        if (data?['type'] == 'version_created') {
          final versionId = data?['version_id'] as String?;
          if (versionId != null && !existingVersionIds.contains(versionId)) {
            continue;
          }
        }

        // L'état « lu » vient de l'appareil. Pour une notification
        // personnelle, la valeur enregistrée en base fait aussi foi (elle
        // n'appartient qu'à cet utilisateur).
        final isPersonal = notification['user_id'] != null;
        final isRead =
            (id != null && readIds.contains(id)) ||
            (isPersonal && notification['is_read'] == true);

        result.add({...notification, 'is_read': isRead});
      }

      return result;
    } catch (e) {
      print('❌ Erreur lors de la récupération des notifications récentes: $e');
      rethrow;
    }
  }

  /// Parmi [versionIds], celles qui existent encore en base.
  Future<Set<String>> _fetchExistingVersionIds(Set<String> versionIds) async {
    if (versionIds.isEmpty) return <String>{};

    try {
      final response = await _supabase
          .from('competition_versions')
          .select('id')
          .inFilter('id', versionIds.toList())
          .timeout(_requestTimeout);

      return List<Map<String, dynamic>>.from(
        response,
      ).map((row) => row['id'] as String).toSet();
    } catch (e) {
      print('⚠️ Vérification des versions impossible: $e');
      // En cas d'échec, ne rien masquer plutôt que de vider la liste.
      return versionIds;
    }
  }

  /// Nombre de notifications non lues (pour la pastille de la cloche).
  /// Un échec réseau ne doit pas casser la barre d'application : on renvoie 0.
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getUnreadNotifications();
      return notifications.length;
    } catch (e) {
      print('⚠️ Impossible de compter les notifications non lues: $e');
      return 0;
    }
  }

  /// Marque toutes les notifications visibles comme lues (sur cet appareil).
  Future<void> markAllAsRead() async {
    final notifications = await getUnreadNotifications();

    final ids = <String>[];
    for (final notification in notifications) {
      final id = notification['id'] as String?;
      if (id == null) continue;
      ids.add(id);

      // Les notifications personnelles sont aussi marquées en base
      final ownerUserId = notification['user_id'] as String?;
      if (ownerUserId != null) {
        await markAsRead(id, ownerUserId: ownerUserId);
      }
    }

    await _readStore.markAllRead(ids);
  }

  /// Démarre un timer pour réessayer périodiquement d'obtenir le token APNS sur iOS
  void _startIOSAPNSRetry() {
    if (_isTokenRegistered) {
      print('ℹ️ Token déjà enregistré, pas de retry nécessaire');
      return; // Token déjà enregistré, pas besoin de retry
    }

    if (_iosAPNSRetryTimer != null) {
      print('ℹ️ Timer iOS déjà actif');
      return; // Timer déjà actif
    }

    print('🔄 Démarrage du timer iOS pour obtenir le token APNS...');
    print(
      'ℹ️ Le timer va réessayer toutes les 10 secondes, maximum 30 tentatives (5 minutes)',
    );

    // Réessayer toutes les 10 secondes, maximum 30 tentatives (5 minutes)
    int retryCount = 0;
    const maxRetries = 30;

    _iosAPNSRetryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      print(
        '⏰ Timer iOS tick - retryCount: $retryCount, _isTokenRegistered: $_isTokenRegistered',
      );

      if (_isTokenRegistered) {
        timer.cancel();
        _iosAPNSRetryTimer = null;
        print('✅ Token enregistré, timer iOS arrêté');
        return;
      }

      retryCount++;
      if (retryCount > maxRetries) {
        timer.cancel();
        _iosAPNSRetryTimer = null;
        print(
          '⚠️ Maximum de tentatives ($maxRetries) atteint pour obtenir le token APNS',
        );
        print(
          '⚠️ Le token APNS n\'est toujours pas disponible après 5 minutes',
        );
        print(
          '⚠️ Vérifiez la configuration iOS : Push Notifications activées dans Xcode ?',
        );
        return;
      }

      print(
        '🔄 Tentative $retryCount/$maxRetries pour obtenir le token APNS...',
      );
      _registerFCMToken();
    });

    // Afficher un message immédiatement après le démarrage du timer
    print('✅ Timer iOS démarré, première tentative dans 10 secondes...');
  }

  /// Arrête l'écoute des notifications
  void stopListening() {
    if (_notificationsChannel != null) {
      _supabase.removeChannel(_notificationsChannel!);
      _notificationsChannel = null;
      _isListening = false;
      print('🛑 Écoute des notifications arrêtée');
    }

    // Arrêter le timer iOS si actif
    if (_iosAPNSRetryTimer != null) {
      _iosAPNSRetryTimer?.cancel();
      _iosAPNSRetryTimer = null;
    }
  }

  /// Dispose du service
  void dispose() {
    stopListening();
  }
}
