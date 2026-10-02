import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/painting.dart' show Color;

/// Service pour gérer les notifications locales dans l'application
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Icône monochrome de la barre d'état : silhouette blanche du porte-Coran
  /// du logo (une icône colorée apparaîtrait comme un carré blanc sur
  /// Android 5+).
  static const String _androidIcon = '@drawable/ic_notification';

  /// Logo complet en couleur, affiché à droite du contenu de la notification.
  static const AndroidBitmap<Object> _androidLargeIcon =
      DrawableResourceAndroidBitmap('ic_notification_large');

  /// Vert du logo, identique à `notification_color` (android/.../colors.xml)
  /// utilisé par les notifications FCM affichées par le système.
  static const Color _accentColor = Color(0xFF1F7C4B);

  /// Canal des notifications ordinaires.
  static const String defaultChannelId = 'default_channel';

  /// Canal des notifications importantes (erreurs/avertissements).
  ///
  /// Android fige l'importance d'un canal à sa création : sans un second
  /// canal, demander `Importance.high` sur le canal par défaut n'a aucun
  /// effet et l'alerte reste silencieuse.
  static const String importantChannelId = 'important_channel';

  /// Initialise le service de notifications
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    // Initialiser les timezones pour les notifications programmées
    tz.initializeTimeZones();

    // Configuration Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(_androidIcon);

    // Configuration iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Configuration d'initialisation
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialiser le plugin
    final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized == true) {
      _isInitialized = true;

      // Créer les canaux et demander les permissions sur Android 13+
      if (Platform.isAndroid) {
        await _createAndroidChannels();
        await _requestAndroidPermissions();
      }

      // Sur iOS, les permissions sont déjà demandées via DarwinInitializationSettings
      // avec requestAlertPermission, requestBadgePermission, requestSoundPermission
      // Pas besoin de demander explicitement ici
      if (Platform.isIOS) {
        print(
          '📱 Permissions iOS notifications locales demandées via DarwinInitializationSettings',
        );
      }

      return true;
    }

    return false;
  }

  /// Demande les permissions Android pour les notifications
  ///
  /// Aucune demande d'alarmes exactes : l'application ne programme rien à une
  /// heure précise, et SCHEDULE_EXACT_ALARM est une permission restreinte par
  /// Google Play.
  Future<void> _requestAndroidPermissions() async {
    final androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.requestNotificationsPermission();
  }

  /// Crée les canaux de notification en amont, afin que leur importance soit
  /// correcte dès la première notification (y compris celles envoyées par FCM
  /// quand l'application est fermée).
  Future<void> _createAndroidChannels() async {
    final androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation == null) return;

    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        defaultChannelId,
        'إشعارات التطبيق',
        description: 'إشعارات عامة من التطبيق',
        importance: Importance.defaultImportance,
      ),
    );

    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        importantChannelId,
        'إشعارات مهمة',
        description: 'تنبيهات مهمة تتطلب انتباهك',
        importance: Importance.high,
      ),
    );
  }

  /// Callback optionnel pour gérer la navigation depuis les notifications
  Function(String? payload)? onNotificationTapped;

  /// Gère le clic sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    // Traiter l'action de la notification ici
    // Par exemple, naviguer vers une page spécifique
    print('📬 Notification tapée: ${response.id} - ${response.payload}');

    // Appeler le callback si défini
    if (onNotificationTapped != null) {
      onNotificationTapped!(response.payload);
    }
  }

  /// Affiche une notification simple
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails ?? _getDefaultNotificationDetails(),
      payload: payload,
    );
  }

  /// Affiche une notification avec un style personnalisé
  Future<void> showStyledNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Le canal détermine réellement le comportement (son, bannière) : on
    // choisit celui qui correspond à l'importance demandée.
    final bool isImportant = importance.value >= Importance.high.value;
    final String resolvedChannelId =
        channelId ?? (isImportant ? importantChannelId : defaultChannelId);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          resolvedChannelId,
          channelName ?? (isImportant ? 'إشعارات مهمة' : 'إشعارات التطبيق'),
          channelDescription:
              channelDescription ??
              (isImportant
                  ? 'تنبيهات مهمة تتطلب انتباهك'
                  : 'إشعارات عامة من التطبيق'),
          importance: importance,
          priority: priority,
          showWhen: true,
          icon: _androidIcon,
          largeIcon: _androidLargeIcon,
          color: _accentColor,
          styleInformation: BigTextStyleInformation(body),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Affiche une notification programmée
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails ?? _getDefaultNotificationDetails(),
      payload: payload,
      // Mode inexact : évite la permission restreinte SCHEDULE_EXACT_ALARM,
      // au prix de quelques minutes d'imprécision.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Pas de matchDateTimeComponents : la notification est ponctuelle.
      // (avec dateAndTime, elle se répétait chaque semaine)
    );
  }

  /// Annule une notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Annule toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Obtient les détails de notification par défaut
  NotificationDetails _getDefaultNotificationDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          defaultChannelId,
          'إشعارات التطبيق',
          channelDescription: 'إشعارات عامة من التطبيق',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
          icon: _androidIcon,
          largeIcon: _androidLargeIcon,
          color: _accentColor,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Convertit une DateTime en TZDateTime (nécessaire pour les notifications programmées)
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Vérifie si les notifications sont activées
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
    } else if (Platform.isIOS) {
      // Sur iOS, les permissions sont demandées lors de l'initialisation
      // On retourne true si le service est initialisé (les permissions ont été demandées)
      return _isInitialized;
    }
    return false;
  }
}
