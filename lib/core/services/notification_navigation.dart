import 'dart:convert';

import 'package:quranic_competition/app/router.dart' as router;

/// Détermine vers quel écran ouvrir une notification, à partir de son payload.
///
/// Le payload est le JSON enregistré à l'envoi (voir `sendNotification`) et
/// contient toujours un champ `type`.
class NotificationNavigation {
  const NotificationNavigation._();

  /// Route correspondant au payload JSON, ou null si le type est inconnu.
  static String? routeForPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return routeForData(decoded);
    } catch (_) {
      // Payload non-JSON : rien à faire, on ouvre simplement l'application.
    }
    return null;
  }

  /// Route correspondant aux données d'une notification (payload décodé, ou
  /// champ `data` d'un message FCM).
  static String? routeForData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'version_created':
        return '/participant_home_page';

      case 'results_published':
        final versionId = data['version_id'] as String?;
        return versionId != null
            ? '/participant/results/$versionId'
            : '/participant_result_page';

      case 'archive_media_created':
        final versionId = data['version_id'] as String?;
        return versionId != null
            ? '/participant/archives/competition/$versionId'
            : '/participant/archives';

      case 'benefit_created':
        return '/participant/benefits';

      case 'tajweed_rule_created':
        return '/participant/tajweed';

      // Les écrans « فسحة العيد » exigent la session en paramètre : on renvoie
      // vers l'accueil, qui affiche la session active en haut de page.
      case 'eid_session_created':
      case 'eid_registration_opened':
      case 'eid_winners_selected':
        return '/participant_home_page';

      default:
        return null;
    }
  }

  /// Ouvre l'écran correspondant au payload de la notification.
  static void openFromPayload(String? payload) =>
      _open(routeForPayload(payload));

  static void _open(String? route) {
    if (route == null) return;
    router.appRouter.go(route);
  }
}
