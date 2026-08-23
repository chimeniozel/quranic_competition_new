import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io' show Platform;
import '../../core/theme/app_theme.dart';

/// Service pour gérer les notifications locales dans l'application
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialise le service de notifications
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    // Initialiser les timezones pour les notifications programmées
    tz.initializeTimeZones();

    // Configuration Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

      // Demander les permissions sur Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }

      // Sur iOS, les permissions sont déjà demandées via DarwinInitializationSettings
      // avec requestAlertPermission, requestBadgePermission, requestSoundPermission
      // Pas besoin de demander explicitement ici
      if (Platform.isIOS) {
        print('📱 Permissions iOS notifications locales demandées via DarwinInitializationSettings');
      }

      return true;
    }

    return false;
  }

  /// Demande les permissions Android pour les notifications
  Future<void> _requestAndroidPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
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

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId ?? 'default_channel',
          channelName ?? 'الإشعارات',
          channelDescription: channelDescription ?? 'إشعارات التطبيق',
          importance: importance,
          priority: priority,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: AppTheme.primaryColor,
          styleInformation: const BigTextStyleInformation(''),
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
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
          'default_channel',
          'الإشعارات',
          channelDescription: 'إشعارات التطبيق الافتراضية',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
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
